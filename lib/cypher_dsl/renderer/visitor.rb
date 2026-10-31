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
        @defined_aliases = Set.new
        @generated_names = {}.compare_by_identity
      end

      def render(statement)
        return render_union(statement) if statement.is_a?(UnionQuery)

        rendered = statement.clauses.map { |clause| render_clause(clause) }.join(' ')
        statement.prefix ? "#{statement.prefix} #{rendered}" : rendered
      end

      # Each statement of a union is its own scope.
      def render_union(union)
        union.statements.map do |statement|
          @visited_names = Set.new
          @defined_aliases = Set.new
          render(statement)
        end.join(union.all ? ' UNION ALL ' : ' UNION ')
      end

      # Unresolved symbolic names get a generated, render-stable name.
      def resolve_name(symbolic_name)
        return symbolic_name.value if symbolic_name.resolved?

        @generated_names[symbolic_name] ||= "#{symbolic_name.hint}#{format('%03d', @generated_names.size + 1)}"
      end

      private

      # --- clauses ---------------------------------------------------------

      def render_clause(clause)
        case clause
        when Clauses::Match then render_match(clause)
        when Clauses::With then render_with(clause)
        when Clauses::Return then render_projection('RETURN', clause, nil)
        when Clauses::Create then "CREATE #{render_pattern_elements(clause.pattern_elements)}"
        when Clauses::Merge then render_merge(clause)
        when Clauses::Set then "SET #{render_operations(clause.operations)}"
        when Clauses::Remove then "REMOVE #{render_operations(clause.items)}"
        when Clauses::Delete then render_delete(clause)
        when Clauses::Unwind
          "UNWIND #{render_expression(clause.expression)} AS #{render_expression(clause.variable)}"
        when Clauses::Finish then 'FINISH'
        when Clauses::Foreach then render_foreach(clause)
        when Clauses::Call then render_call(clause)
        when Clauses::CallSubquery then render_call_subquery(clause)
        else raise ArgumentError, "Cannot render clause #{clause.inspect}"
        end
      end

      def render_call(clause)
        name = clause.name_parts.map { |part| Escaper.escape_if_necessary(part) }.join('.')
        arguments = clause.arguments.map { |argument| render_expression(argument) }.join(', ')
        parts = ["CALL #{name}(#{arguments})"]
        yields = clause.yield_items.map { |item| render_projection_item(item) }
        parts << "YIELD #{yields.join(', ')}" unless yields.empty?
        parts << "WHERE #{render_expression(clause.where)}" if clause.where && !clause.where.is_a?(NoCondition)
        parts.join(' ')
      end

      def render_call_subquery(clause)
        imports = clause.imports.map { |import| render_expression(import) }.join(', ')
        body = clause.body.is_a?(RawExpression) ? clause.body.content : render_subquery(clause.body)
        "CALL (#{imports}) {#{body}}"
      end

      # A subquery statement rendered in its own scope.
      def render_subquery(statement)
        outer_scope = @visited_names.dup
        rendered = render(statement)
        @visited_names = outer_scope
        rendered
      end

      # The body of a FOREACH is its own scope: names rendered inside it do not
      # count as visited outside.
      def render_foreach(clause)
        outer_scope = @visited_names.dup
        body = clause.clauses.map { |inner| render_clause(inner) }.join(' ')
        @visited_names = outer_scope
        "FOREACH (#{render_expression(clause.variable)} IN #{render_expression(clause.list)} | #{body})"
      end

      def render_match(clause)
        [('OPTIONAL ' if clause.optional), 'MATCH ', render_pattern_elements(clause.pattern_elements),
         render_where(clause.where)].join
      end

      def render_merge(clause)
        actions = clause.actions.map do |action|
          " ON #{action.type == :on_match ? 'MATCH' : 'CREATE'} SET #{render_operations(action.operations)}"
        end
        "MERGE #{render_pattern_elements(clause.pattern_elements)}#{actions.join}"
      end

      def render_operations(operations)
        operations.map { |operation| render_expression(operation) }.join(', ')
      end

      def render_delete(clause)
        expressions = clause.expressions.map { |expression| render_expression(expression) }
        "#{'DETACH ' if clause.detach}DELETE #{expressions.join(', ')}"
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
          when AliasedExpression then resolve_name(item.alias_name)
          when SymbolicName then resolve_name(item)
          when Node, Relationship then item.symbolic_name && resolve_name(item.symbolic_name)
          end
        end.to_set
      end

      def render_projection(keyword, clause, where)
        items = clause.items.map { |item| render_projection_item(item) }.join(', ')
        parts = ["#{keyword} #{'DISTINCT ' if clause.distinct}#{items}"]
        parts << "ORDER BY #{clause.order.items.map { |item| render_sort_item(item) }.join(', ')}" if clause.order
        parts << "SKIP #{render_expression(clause.skip)}" if clause.skip
        parts << "LIMIT #{render_expression(clause.limit)}" if clause.limit
        parts << "WHERE #{render_expression(where)}" if where && !where.is_a?(NoCondition)
        parts.join(' ')
      end

      # In RETURN/WITH an aliased expression is defined once (`expr AS alias`);
      # afterwards, and anywhere else, it is a reference and renders as the alias.
      def render_projection_item(item)
        return render_expression(item) unless item.is_a?(AliasedExpression)

        alias_name = resolve_name(item.alias_name)
        return Escaper.escape_if_necessary(alias_name) if @defined_aliases.include?(alias_name)

        rendered = "#{render_expression(item.delegate)} AS #{render_expression(item.alias_name)}"
        @defined_aliases << alias_name
        rendered
      end

      def render_aliased_reference(item)
        alias_name = resolve_name(item.alias_name)
        return Escaper.escape_if_necessary(alias_name) if @defined_aliases.include?(alias_name)

        render_expression(item.delegate)
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
        when NamedPath then render_named_path(element)
        when QuantifiedPathPattern then render_quantified_path_pattern(element)
        else raise ArgumentError, "Cannot render pattern element #{element.inspect}"
        end
      end

      def render_named_path(path)
        selector = path.selector && "#{path.selector.keyword} "
        "#{render_expression(path.symbolic_name)} = #{selector}#{render_pattern_element(path.pattern)}"
      end

      def render_quantified_path_pattern(quantified)
        inner = render_pattern_element(quantified.pattern)
        inner += " WHERE #{render_expression(quantified.where_condition)}" if quantified.where_condition
        "(#{inner})#{quantified.quantifier.to_cypher}"
      end

      def render_chain(chain)
        chain.relationships.each_with_index.map do |relationship, index|
          left = index.zero? ? render_node(relationship.left) : ''
          left + render_relationship_details(relationship) + render_node(relationship.right)
        end.join
      end

      def render_node(node)
        name = node.symbolic_name && resolve_name(node.symbolic_name)
        return "(#{name})" if name && @visited_names.include?(name)

        @visited_names << name if name
        labels = node.labels.map { |label| ":#{escape_schema_name(label)}" }.join
        properties = node.properties && " #{render_expression(node.properties)}"
        where = node.where_condition && " WHERE #{render_expression(node.where_condition)}"
        "(#{name}#{labels}#{properties}#{where})"
      end

      def render_relationship_details(relationship)
        details = relationship.details
        empty = details.empty? && relationship.symbolic_name.nil?
        inner = empty ? '' : "[#{render_details_content(relationship)}]"
        quantifier = details.quantifier&.to_cypher
        case relationship.direction
        when :ltr then "-#{inner}->#{quantifier}"
        when :rtl then "<-#{inner}-#{quantifier}"
        else "-#{inner}-#{quantifier}"
        end
      end

      def render_details_content(relationship)
        details = relationship.details
        types = details.types.map { |type| escape_schema_name(type) }.join('|')
        [
          relationship.symbolic_name && resolve_name(relationship.symbolic_name),
          (":#{types}" unless types.empty?),
          render_length(details),
          details.properties && " #{render_expression(details.properties)}",
          details.where && " WHERE #{render_expression(details.where)}"
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
        when SymbolicName then Escaper.escape_if_necessary(resolve_name(expression))
        when Node, Relationship then render_expression(expression.required_symbolic_name)
        when Property then render_property(expression)
        when Literal then render_literal(expression.value)
        when Parameter then "$#{expression.name}"
        when Asterisk then '*'
        when AliasedExpression then render_aliased_reference(expression)
        when NamedPath then render_expression(expression.symbolic_name)
        when RawExpression then expression.content
        when FunctionInvocation then render_function_invocation(expression)
        when SortItem then render_sort_item(expression)
        when CaseExpression then render_case(expression)
        when UnaryOperation then "#{expression.operator}#{render_expression(expression.expression)}"
        when ListOperator then render_list_operator(expression)
        else render_container_expression(expression)
        end
      end

      def render_case(case_expression)
        parts = ['CASE']
        parts << render_expression(case_expression.subject) if case_expression.subject
        case_expression.whens.each do |condition, value|
          parts << "WHEN #{render_expression(condition)} THEN #{render_expression(value)}"
        end
        parts << "ELSE #{render_expression(case_expression.default)}" if case_expression.default
        parts << 'END'
        parts.join(' ')
      end

      def render_list_operator(operator)
        list = render_expression(operator.list)
        return "#{list}[#{render_expression(operator.start_index)}]" unless operator.slice

        from = operator.start_index && render_expression(operator.start_index)
        to = operator.end_index && render_expression(operator.end_index)
        "#{list}[#{from}..#{to}]"
      end

      def render_container_expression(expression)
        case expression
        when MapExpression then render_map(expression)
        when ListExpression then "[#{expression.elements.map { |element| render_expression(element) }.join(', ')}]"
        when PatternComprehension then render_pattern_comprehension(expression)
        when ListComprehension then render_list_comprehension(expression)
        when MapProjection then render_map_projection(expression)
        when LabelOperation then render_labels(expression.node, expression.labels)
        else render_condition_or_operation(expression)
        end
      end

      def render_labels(node, labels)
        "#{render_expression(node)}#{labels.map { |label| ":#{escape_schema_name(label)}" }.join}"
      end

      def render_condition_or_operation(expression)
        case expression
        when Comparison then render_comparison(expression)
        when CompoundCondition then render_compound_condition(expression)
        when ConstantCondition then expression.value.to_s
        when ExpressionCondition then render_expression(expression.expression)
        when ExistsCondition then render_exists(expression)
        when RelationshipPatternCondition then render_pattern_element(expression.pattern)
        when ListPredicate then render_list_predicate(expression)
        when HasLabelCondition then render_labels(expression.node, expression.labels)
        when Operation then render_operation(expression)
        else raise ArgumentError, "Cannot render expression #{expression.inspect}"
        end
      end

      def render_operation(operation)
        left = render_expression(operation.left)
        right = render_expression(operation.right)
        return "#{left}^#{right}" if operation.operator == '^'

        rendered = "#{left} #{operation.operator} #{right}"
        operation.assignment? ? rendered : "(#{rendered})"
      end

      def render_exists(condition)
        body = condition.body
        rendered = body.is_a?(Statement) ? render_subquery(body) : render_pattern_element(body)
        "EXISTS { #{rendered} }"
      end

      def render_list_predicate(predicate)
        "#{predicate.predicate}(#{render_expression(predicate.variable)} IN #{render_expression(predicate.list)} " \
          "WHERE #{render_expression(predicate.condition)})"
      end

      def render_map_projection(projection)
        entries = projection.entries.map do |kind, *args|
          case kind
          when :all then '.*'
          when :lookup then ".#{Escaper.escape_if_necessary(args.first)}"
          when :property then ".#{Escaper.escape_if_necessary(args.first.names.first)}"
          when :pair then "#{Escaper.escape_if_necessary(args.first)}: #{render_expression(args.last)}"
          else render_expression(args.first)
          end
        end
        "#{render_expression(projection.subject)}{#{entries.join(', ')}}"
      end

      # A pattern comprehension is its own scope: names it introduces do not
      # count as visited outside of it.
      def render_pattern_comprehension(comprehension)
        outer_scope = @visited_names.dup
        parts = [render_pattern_element(comprehension.pattern)]
        parts << "WHERE #{render_expression(comprehension.where_condition)}" if comprehension.where_condition
        projection = comprehension.projection.map { |expression| render_expression(expression) }
        parts << "| #{projection.size == 1 ? projection.first : "[#{projection.join(', ')}]"}"
        @visited_names = outer_scope
        "[#{parts.join(' ')}]"
      end

      def render_list_comprehension(comprehension)
        parts = ["#{render_expression(comprehension.variable)} IN #{render_expression(comprehension.list)}"]
        parts << "WHERE #{render_expression(comprehension.where_condition)}" if comprehension.where_condition
        parts << "| #{render_expression(comprehension.projection)}" if comprehension.projection
        "[#{parts.join(' ')}]"
      end

      def render_property(property)
        lookups = property.names.map do |name|
          name.is_a?(Expression) ? "[#{render_expression(name)}]" : ".#{Escaper.escape_if_necessary(name)}"
        end
        "#{render_expression(property.container)}#{lookups.join}"
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
        entries = map.entries.map { |key, value| "#{Escaper.escape_if_necessary(key)}: #{render_expression(value)}" }
        "{#{entries.join(', ')}}"
      end

      def render_comparison(comparison)
        left = render_operand(comparison.left)
        return "#{left} #{comparison.operator}" if comparison.unary?

        "#{left} #{comparison.operator} #{render_operand(comparison.right)}"
      end

      # A comparison nested inside another comparison is parenthesised: `(1 > 2) = true`.
      def render_operand(expression)
        rendered = render_expression(expression)
        expression.is_a?(Comparison) ? "(#{rendered})" : rendered
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
        rendered = "#{invocation.function_name}(#{'DISTINCT ' if invocation.distinct}#{arguments.join(', ')})"
        # Neo4j 4 has no elementId(); the closest equivalent is the stringified internal id.
        if invocation.function_name == 'elementId' && @configuration.dialect == Dialect::NEO4J_4
          "toString(id(#{arguments.join(', ')}))"
        else
          rendered
        end
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
