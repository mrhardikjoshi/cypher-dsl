# frozen_string_literal: true

module CypherDSL
  # Conditions joined by AND / OR / XOR, or negated with NOT. Rendered in
  # parentheses; chaining the same operator flattens into one group and empty
  # conditions drop out.
  class CompoundCondition < Condition
    attr_reader :operator, :conditions

    def self.create(operator, left, right)
      conditions = [left, right].flat_map do |condition|
        case condition
        when NoCondition then []
        when CompoundCondition then condition.operator == operator ? condition.conditions : [condition]
        else [condition]
        end
      end
      case conditions.size
      when 0 then NoCondition::INSTANCE
      when 1 then conditions.first
      else new(operator, conditions)
      end
    end

    def initialize(operator, conditions)
      super()
      @operator = operator
      @conditions = conditions.freeze
      freeze
    end

    def negation? = operator == 'NOT'
  end
end
