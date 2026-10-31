# frozen_string_literal: true

module CypherDSL
  # Base class of boolean expressions; supports chaining with `and`, `or`, `xor` and `not`.
  # Relationship patterns are accepted wherever a condition is expected.
  class Condition
    include Expression

    def self.coerce(value)
      case value
      when Condition then value
      when Relationship, RelationshipChain then RelationshipPatternCondition.new(value)
      else raise ArgumentError, "#{value.inspect} is not a condition"
      end
    end

    def and(other) = CompoundCondition.create('AND', self, Condition.coerce(other))
    def or(other) = CompoundCondition.create('OR', self, Condition.coerce(other))
    def xor(other) = CompoundCondition.create('XOR', self, Condition.coerce(other))
    def not = CompoundCondition.new('NOT', [self])
  end
end
