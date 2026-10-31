# frozen_string_literal: true

module CypherDSL
  class Renderer
    # Walks a statement and produces Cypher text. One instance per render call:
    # it remembers which named nodes have already been rendered with their
    # content, so later occurrences render as `(name)` only.
    class Visitor
      def initialize(configuration)
        @configuration = configuration
        @visited_names = Set.new
      end

      def render(statement)
        rendered = statement.clauses.map { |clause| render_clause(clause) }.join(' ')
        statement.prefix ? "#{statement.prefix} #{rendered}" : rendered
      end

      private

      # --- clauses ---------------------------------------------------------

      def render_clause(clause)
        case clause
        when Clauses::Match then render_match(clause)
        when Clauses::With then render_with(clause)
        when Clauses::Return then render_projection('RETURN', clause, nil)
        when Clauses::Create then "CREATE #{render_pattern_elements(clause.pattern_elements)}"
        when Clauses::Merge then "MERGE #{render_pattern_elements(clause.pattern_elements)}"
        when Clauses::Set then "SET #{clause.operations.map { |operation| render_expression(operation) }.join(', ')}"
        when Clauses::Delete then render_delete(clause)
        when Clauses::Unwind
          "UNWIND #{render_expression(clause.expression)} AS #{render_expression(clause.variable)}"
        when Clauses::Finish then 'FINISH'
        else raise ArgumentError, "Cannot render clause #{clause.inspect}"
        end
      end

      def render_match(clause)
        [('OPTIONAL ' if clause.optional), 'MATCH ', render_pattern_elements(clause.pattern_elements),
         render_where(clause.where)].join
      end

      def render_delete(clause)
        "#{'DETACH ' if clause.detach}DELETE #{clause.expressions.map { |expression| render_expression(expression) }.join(', ')}"
      end

      # WITH ends a query part: only the names it projects stay in scope, so a
      # node that is not carried over renders with its labels again afterwards.
      def render_with(clause)
        rendered = render_projection('WITH', clause, clause.where)
        @visited_names = clause.items.include?(Asterisk::INSTANCE) ? @visited_names : exported_names(clause.items)
        rendered
      end

      def exported_names(items)
        items.filter_map do |item|
          case item
          when AliasedExpression then item.alias_name.value
          when SymbolicName then item.value
          when Node, Relationship then item.symbolic_name&.value
          end
        end.to_set
      end

      def render_projection(keyword, clause, where)
        items = clause.items.map { |item| render_expression(item) }.join(', ')
        parts = ["#{keyword} #{'DISTINCT ' if clause.distinct}#{items}"]
        parts << "ORDER BY #{clause.order.items.map { |item| render_sort_item(item) }.join(', ')}" if clause.order
        parts << "SKIP #{render_expression(clause.skip)}" if clause.skip
        parts << "LIMIT #{render_expression(clause.limit)}" if clause.limit
        parts << "WHERE #{render_expression(where)}" if where && !where.is_a?(NoCondition)
        parts.join(' ')
      end

      def render_pattern_elements(elements)
        elements.map { |element| render_pattern_element(element) }.join(', ')
      end

      def render_where(condition)
        return nil if condition.nil? || condition.is_a?(NoCondition)

        " WHERE #{render_expression(condition)}"
      end

      def render_sort_item(item)
        [render_expression(item.expression), item.direction&.to_s&.upcase].compact.join(' ')
      end

      # --- pattern elements -----------------------------------------------

      def render_pattern_element(element)
        case element
        when Node then render_node(element)
        when Relationship
          render_node(element.left) + render_relationship_details(element) + render_node(element.right)
        when RelationshipChain then render_chain(element)
        else raise ArgumentError, "Cannot render pattern element #{element.inspect}"
        end
      end

      def render_chain(chain)
        chain.relationships.each_with_index.map do |relationship, index|
          left = index.zero? ? render_node(relationship.left) : ''
          left + render_relationship_details(relationship) + render_node(relationship.right)
        end.join
      end

      def render_node(node)
        name = node.symbolic_name&.value
        return "(#{name})" if name && @visited_names.include?(name)

        @visited_names << name if name
        labels = node.labels.map { |label| ":#{escape_schema_name(label)}" }.join
        properties = node.properties && " #{render_expression(node.properties)}"
        "(#{name}#{labels}#{properties})"
      end

      def render_relationship_details(relationship)
        details = relationship.details
        inner = details.empty? ? '' : "[#{render_details_content(details)}]"
        case relationship.direction
        when :ltr then "-#{inner}->"
        when :rtl then "<-#{inner}-"
        else "-#{inner}-"
        end
      end

      def render_details_content(details)
        types = details.types.map { |type| escape_schema_name(type) }.join('|')
        [
          details.symbolic_name&.value,
          (":#{types}" unless types.empty?),
          render_length(details),
          details.properties && " #{render_expression(details.properties)}"
        ].join
      end

      def render_length(details)
        return nil unless details.length?
        return '*' if details.unbounded && details.min.nil? && details.max.nil?

        "*#{details.min}..#{details.max}"
      end

      # --- expressions -----------------------------------------------------

      def render_expression(expression)
        case expression
        when SymbolicName then Escaper.escape_if_necessary(expression.value)
        when Node, Relationship then render_expression(expression.required_symbolic_name)
        when Property then render_property(expression)
        when Literal then render_literal(expression.value)
        when MapExpression then render_map(expression)
        when ListExpression then "[#{expression.elements.map { |element| render_expression(element) }.join(', ')}]"
        when PatternComprehension then render_pattern_comprehension(expression)
        when Parameter then "$#{expression.name}"
        when Asterisk then '*'
        when AliasedExpression
          "#{render_expression(expression.delegate)} AS #{render_expression(expression.alias_name)}"
        when FunctionInvocation then render_function_invocation(expression)
        when SortItem then render_sort_item(expression)
        else render_condition_or_operation(expression)
        end
      end

      def render_condition_or_operation(expression)
        case expression
        when Comparison then render_comparison(expression)
        when CompoundCondition then render_compound_condition(expression)
        when ConstantCondition then expression.value.to_s
        when RelationshipPatternCondition then render_pattern_element(expression.pattern)
        when ListPredicate then render_list_predicate(expression)
        when HasLabelCondition
          "#{render_expression(expression.node)}#{expression.labels.map { |label| ":#{escape_schema_name(label)}" }.join}"
        when Operation
          "#{render_expression(expression.left)} #{expression.operator} #{render_expression(expression.right)}"
        else raise ArgumentError, "Cannot render expression #{expression.inspect}"
        end
      end

      def render_list_predicate(predicate)
        "#{predicate.predicate}(#{render_expression(predicate.variable)} IN #{render_expression(predicate.list)} " \
          "WHERE #{render_expression(predicate.condition)})"
      end

      def render_pattern_comprehension(comprehension)
        parts = [render_pattern_element(comprehension.pattern)]
        parts << "WHERE #{render_expression(comprehension.where_condition)}" if comprehension.where_condition
        projection = comprehension.projection.map { |expression| render_expression(expression) }
        parts << "| #{projection.size == 1 ? projection.first : "[#{projection.join(', ')}]"}"
        "[#{parts.join(' ')}]"
      end

      def render_property(property)
        names = property.names.map { |name| Escaper.escape_if_necessary(name) }
        "#{render_expression(property.container)}.#{names.join('.')}"
      end

      def render_literal(value)
        case value
        when String then "'#{value.gsub('\\') { '\\\\' }.gsub("'") { "\\'" }}'"
        when nil then 'NULL'
        when true, false, Numeric then value.to_s
        else raise ArgumentError, "Cannot render literal #{value.inspect}"
        end
      end

      def render_map(map)
        "{#{map.entries.map { |key, value| "#{Escaper.escape_if_necessary(key)}: #{render_expression(value)}" }.join(', ')}}"
      end

      def render_comparison(comparison)
        left = render_expression(comparison.left)
        return "#{left} #{comparison.operator}" if comparison.unary?

        "#{left} #{comparison.operator} #{render_expression(comparison.right)}"
      end

      def render_compound_condition(condition)
        if condition.negation?
          negated = condition.conditions.first
          rendered = render_expression(negated)
          return negated.is_a?(RelationshipPatternCondition) ? "NOT #{rendered}" : "NOT (#{rendered})"
        end

        "(#{condition.conditions.map { |inner| render_expression(inner) }.join(" #{condition.operator} ")})"
      end

      def render_function_invocation(invocation)
        arguments = invocation.arguments.map do |argument|
          pattern_element?(argument) ? render_pattern_element(argument) : render_expression(argument)
        end
        "#{invocation.function_name}(#{'DISTINCT ' if invocation.distinct}#{arguments.join(', ')})"
      end

      def pattern_element?(argument)
        case argument
        when RelationshipChain, Relationship then true
        when Node then !argument.named?
        else false
        end
      end

      def escape_schema_name(name)
        @configuration.always_escape_names ? Escaper.escape(name) : Escaper.escape_if_necessary(name)
      end
    end
  end
end
