# frozen_string_literal: true

module CypherDSL
  # A pattern used where an expression is expected, as in `size((a)-->())`:
  # names already in scope render bare, names not yet seen are dropped.
  class PatternExpression
    include Expression

    attr_reader :pattern

    def initialize(pattern)
      @pattern = pattern
      freeze
    end
  end
end
