# frozen_string_literal: true

module CypherDSL
  # `CASE [subject] WHEN condition THEN value … [ELSE default] END`.
  # Built with `Cypher.case_expression`, `.when(…).then(…)` pairs and `else_default`.
  class CaseExpression
    include Expression

    attr_reader :subject, :whens, :default

    def initialize(subject: nil, whens: [], default: nil)
      @subject = subject
      @whens = whens.freeze
      @default = default
      freeze
    end

    def when(condition) = OngoingWhen.new(self, Expression.coerce(condition))

    def else_default(default_value) = with(default: Expression.coerce(default_value))

    def with(**changes) = CaseExpression.new(subject:, whens:, default:, **changes)

    # A `WHEN` waiting for its `THEN`.
    class OngoingWhen
      def initialize(case_expression, condition)
        @case_expression = case_expression
        @condition = condition
        freeze
      end

      def then(value)
        @case_expression.with(whens: @case_expression.whens + [[@condition, Expression.coerce(value)]])
      end
    end
  end
end
