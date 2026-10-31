# frozen_string_literal: true

module CypherDSL
  # The constant conditions `true` and `false`.
  class ConstantCondition < Condition
    attr_reader :value

    def initialize(value)
      super()
      @value = value
      freeze
    end

    TRUE = new(true)
    FALSE = new(false)
  end
end
