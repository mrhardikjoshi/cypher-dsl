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

    # Negating a null check flips it instead of wrapping it in NOT.
    def not
      case operator
      when 'IS NULL' then Comparison.new(left, 'IS NOT NULL', nil)
      when 'IS NOT NULL' then Comparison.new(left, 'IS NULL', nil)
      else super
      end
    end
  end
end
