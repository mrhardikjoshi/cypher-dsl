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
      when FunctionInvocation then ExpressionCondition.new(value) # boolean functions such as isEmpty()
      else raise ArgumentError, "#{value.inspect} is not a condition"
      end
    end

    def and(other) = combine('AND', other)
    def or(other) = combine('OR', other)
    def xor(other) = combine('XOR', other)
    def not = CompoundCondition.new('NOT', [self])

    private

    # Chaining conditions flattens same-operator chains; chaining a relationship
    # pattern (the Java overload) wraps without flattening, as upstream does.
    def combine(operator, other)
      return CompoundCondition.new(operator, [self, Condition.coerce(other)]) if pattern?(other)

      CompoundCondition.create(operator, self, Condition.coerce(other))
    end

    def pattern?(value) = value.is_a?(Relationship) || value.is_a?(RelationshipChain)
  end
end
