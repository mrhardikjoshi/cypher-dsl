# frozen_string_literal: true

module CypherDSL
  # The empty condition: it renders nothing and disappears when combined with
  # another condition, which lets callers build conditions incrementally.
  class NoCondition < Condition
    INSTANCE = new.freeze

    def and(other) = Condition.coerce(other)
    def or(other) = Condition.coerce(other)
    def xor(other) = Condition.coerce(other)
    def not = self
  end
end
