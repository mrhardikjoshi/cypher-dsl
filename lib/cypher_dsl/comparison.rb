# frozen_string_literal: true

module CypherDSL
  # A binary comparison (`a = b`, `a =~ b`, …) or a unary one (`a IS NULL`).
  class Comparison < Condition
    attr_reader :left, :operator, :right

    def initialize(left, operator, right)
      super()
      @left = left
      @operator = operator
      @right = right
      freeze
    end

    def unary? = right.nil?
  end
end
