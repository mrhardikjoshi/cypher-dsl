# frozen_string_literal: true

module CypherDSL
  # A relationship pattern used as a predicate, e.g. `WHERE (a)-->(b)`.
  class RelationshipPatternCondition < Condition
    attr_reader :pattern

    def initialize(pattern)
      super()
      @pattern = pattern
      freeze
    end
  end
end
