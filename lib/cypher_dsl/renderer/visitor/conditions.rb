# frozen_string_literal: true

module CypherDSL
  class Renderer
    class Visitor
      # Rendering of comparisons and compound conditions.
      module Conditions
        private

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

        # `exists(n.prop)` on Neo4j 4, `n.prop IS NOT NULL` afterwards.
        def render_property_exists(condition, negated: false)
          property = render_expression(condition.property)
          return "exists(#{property})" if @configuration.legacy_functions?

          "#{property} IS #{'NOT ' unless negated}NULL"
        end

        # Pretty printed, each further operand starts an indented line: `(a\n  AND b)`.
        def render_compound_condition(condition)
          if condition.negation?
            negated = condition.conditions.first
            if negated.is_a?(PropertyExistsCondition) && !@configuration.legacy_functions?
              return render_property_exists(negated, negated: true)
            end

            rendered = render_expression(negated)
            return negated.is_a?(RelationshipPatternCondition) ? "NOT #{rendered}" : "NOT (#{rendered})"
          end

          operands = nested { condition.conditions.map { |inner| render_compound_operand(inner) } }
          "(#{operands.join("#{break_line(@level + 1)}#{condition.operator} ")})"
        end

        # A raw operand is parenthesised unless it already is one group, so that
        # `Cypher.raw('a OR b').as_condition.and(c)` keeps its precedence. (Ruby addition; the
        # Java renderer trusts raw text.)
        def render_compound_operand(condition)
          rendered = render_expression(condition)
          raw_condition?(condition) && !parenthesised?(rendered) ? "(#{rendered})" : rendered
        end

        def raw_condition?(condition)
          condition.is_a?(ExpressionCondition) && condition.expression.is_a?(RawExpression)
        end

        # True when the text is one parenthesised group: `(a OR b)` but not `(a) OR (b)`.
        def parenthesised?(text)
          return false unless text.start_with?('(') && text.end_with?(')')

          depth = 0
          text.each_char.with_index do |char, index|
            depth += 1 if char == '('
            depth -= 1 if char == ')'
            return false if depth.zero? && index < text.size - 1
          end
          true
        end
      end
    end
  end
end
