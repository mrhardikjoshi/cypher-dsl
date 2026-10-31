# frozen_string_literal: true

module CypherDSL
  # A binary operation such as `n.x = true` or `a + b`.
  class Operation
    include Expression

    attr_reader :left, :operator, :right

    def initialize(left, operator, right)
      @left = left
      @operator = operator
      @right = right
      freeze
    end
  end
end
