# frozen_string_literal: true

module CypherDSL
  # A label expression as in `(n:A|B)`, `(n:A&!B)` or `(n:(A|B)&C)`; built from
  # {Labels.exactly} and combined with {#or}, {#and} and {#negate}.
  class LabelExpression
    TYPES = %i[leaf conjunction disjunction negation].freeze

    attr_reader :type, :value, :operands

    def self.exactly(name) = new(:leaf, name.to_s, [])

    def initialize(type, value, operands)
      raise ArgumentError, "Unknown label expression type #{type.inspect}" unless TYPES.include?(type)

      @type = type
      @value = value
      @operands = operands.freeze
      freeze
    end

    def or(other) = LabelExpression.new(:disjunction, nil, [self, coerce(other)])
    def and(other) = LabelExpression.new(:conjunction, nil, [self, coerce(other)])
    def negate = LabelExpression.new(:negation, nil, [self])
    alias not negate

    def leaf? = type == :leaf

    private

    def coerce(other) = other.is_a?(LabelExpression) ? other : LabelExpression.exactly(other)
  end

  # Factory for label expressions: `Labels.exactly('A').or('B')`.
  module Labels
    module_function

    def exactly(name) = LabelExpression.exactly(name)
  end
end
