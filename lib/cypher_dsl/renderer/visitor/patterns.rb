# frozen_string_literal: true

module CypherDSL
  class Renderer
    class Visitor
      # Rendering of nodes, relationships, chains, named paths and quantified path patterns.
      module Patterns
        private

        def render_pattern_element(element)
          case element
          when Node then render_node(element)
          when Relationship
            render_node(element.left) + render_relationship_details(element) + render_node(element.right)
          when RelationshipChain then render_chain(element)
          when NamedPath then render_named_path(element)
          when QuantifiedPathPattern then render_quantified_path_pattern(element)
          when RawExpression then render_raw(element) # `Cypher.raw('(n)-->(m)')` as a pattern
          else raise ArgumentError, "Cannot render pattern element #{element.inspect}"
          end
        end

        # `p = SHORTEST 1 pattern`, or `p = shortestPath(pattern)` on dialects before Neo4j 5.21.
        def render_named_path(path)
          name = render_expression(path.symbolic_name)
          pattern = render_pattern_element(path.pattern)
          selector = path.selector
          if selector&.legacy_function && @configuration.legacy_path_selectors?
            "#{name} = #{selector.legacy_function}(#{pattern})"
          else
            "#{name} = #{"#{selector.keyword} " if selector}#{pattern}"
          end
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

        # A named node renders in full once per scope and as `(name)` afterwards.
        # Inside a pattern expression (a pattern used as a condition) no new
        # variables may be introduced, so an unknown name is left out.
        def render_node(node)
          name = node.symbolic_name && resolve_name(node.symbolic_name, in_entity: true)
          return "(#{Escaper.escape_if_necessary(name)})" if name && @visited_names.include?(name)

          @visited_names << name if name && !@in_pattern_expression
          name = nil if @in_pattern_expression
          labels = node.labels.map { |label| render_label(label) }.join
          properties = node.properties && " #{render_expression(node.properties)}"
          where = node.where_condition && " WHERE #{render_expression(node.where_condition)}"
          "(#{name && Escaper.escape_if_necessary(name)}#{labels}#{properties}#{where})"
        end

        # A pattern used as a condition: known names render bare, unknown ones are dropped.
        def render_pattern_expression(pattern)
          @in_pattern_expression = true
          render_pattern_element(pattern)
        ensure
          @in_pattern_expression = false
        end

        # Like nodes, a named relationship renders in full once and as `[name]` afterwards.
        def render_relationship_details(relationship)
          details = relationship.details
          name = relationship.symbolic_name && resolve_name(relationship.symbolic_name, in_entity: true)
          inner = if name && @visited_names.include?(name)
                    "[#{Escaper.escape_if_necessary(name)}]"
                  else
                    @visited_names << name if name && !@in_pattern_expression
                    content = render_details_content(relationship)
                    # A name dropped from a pattern expression leaves its brackets behind: `-[]->`.
                    content.empty? && !(name && @in_pattern_expression) ? '' : "[#{content}]"
                  end
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
          named = relationship.symbolic_name && !@in_pattern_expression
          name = named ? Escaper.escape_if_necessary(resolve_name(relationship.symbolic_name, in_entity: true)) : nil
          [
            name,
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
      end
    end
  end
end
