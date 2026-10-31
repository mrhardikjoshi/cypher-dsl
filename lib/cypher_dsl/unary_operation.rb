# frozen_string_literal: true

module CypherDSL
  # A prefix operation such as `-x` or `+x`.
  class UnaryOperation
    include Expression

    attr_reader :operator, :expression

    def initialize(operator, expression)
      @operator = operator
      @expression = expression
      freeze
    end
  end
end
