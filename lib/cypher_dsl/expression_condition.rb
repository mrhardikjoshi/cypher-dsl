# frozen_string_literal: true

module CypherDSL
  # Any expression used where a condition is expected, e.g. a CASE expression in WHERE.
  class ExpressionCondition < Condition
    attr_reader :expression

    def initialize(expression)
      super()
      @expression = expression
      freeze
    end
  end
end
