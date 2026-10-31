# frozen_string_literal: true

module CypherDSL
  # The list predicates `all(x IN list WHERE condition)`, `any(…)`, `none(…)`, `single(…)`.
  class ListPredicate < Condition
    attr_reader :predicate, :variable, :list, :condition

    def initialize(predicate, variable, list, condition)
      super()
      @predicate = predicate
      @variable = SymbolicName.of(variable)
      @list = list
      @condition = condition
      freeze
    end
  end
end
