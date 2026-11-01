# frozen_string_literal: true

module CypherDSL
  # A binary comparison (`a = b`, `a =~ b`, …) or a unary one (`a IS NULL`).
  class Comparison < Condition
    UNARY_OPERATORS = ['IS NULL', 'IS NOT NULL'].freeze

    attr_reader :left, :operator, :right

    def initialize(left, operator, right)
      super()
      raise ArgumentError, 'Left expression must not be null.' if left.nil?
      raise ArgumentError, 'Operator must not be empty.' if operator.nil? || operator.to_s.strip.empty?
      raise ArgumentError, 'Right expression must not be null.' if right.nil? && !UNARY_OPERATORS.include?(operator)

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
