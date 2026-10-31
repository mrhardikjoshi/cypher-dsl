# frozen_string_literal: true

module CypherDSL
  # Conditions joined by AND / OR / XOR, or negated with NOT. Rendered in
  # parentheses; chaining the same operator flattens into one group.
  class CompoundCondition < Condition
    attr_reader :operator, :conditions

    def self.create(operator, left, right)
      conditions = [left, right].flat_map do |condition|
        condition.is_a?(CompoundCondition) && condition.operator == operator ? condition.conditions : [condition]
      end
      new(operator, conditions)
    end

    def initialize(operator, conditions)
      super()
      @operator = operator
      @conditions = conditions.freeze
      freeze
    end
  end
end
