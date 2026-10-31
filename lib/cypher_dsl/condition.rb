# frozen_string_literal: true

module CypherDSL
  # Base class of boolean expressions; supports chaining with `and`, `or` and `not`.
  class Condition
    include Expression

    def and(other) = CompoundCondition.create('AND', self, other)
    def or(other) = CompoundCondition.create('OR', self, other)
    def xor(other) = CompoundCondition.create('XOR', self, other)
    def not = CompoundCondition.new('NOT', [self])
  end
end
