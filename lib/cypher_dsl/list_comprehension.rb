# frozen_string_literal: true

module CypherDSL
  # `[variable IN list WHERE condition | expression]`. Built with
  # `Cypher.list_with(name).in(list)`, refined with `where`, completed with `returning`.
  class ListComprehension
    include Expression

    attr_reader :variable, :list, :where_condition, :projection

    def initialize(variable, list: nil, where_condition: nil, projection: nil)
      @variable = SymbolicName.of(variable)
      @list = list
      @where_condition = where_condition
      @projection = projection
      freeze
    end

    def in(list) = with(list: Expression.coerce(list))

    def where(condition) = with(where_condition: Condition.coerce(condition))

    # Without an argument the comprehension yields the variable itself.
    def returning(expression = nil) = with(projection: expression && Expression.coerce(expression))

    private

    def with(**changes)
      ListComprehension.new(variable, list:, where_condition:, projection:, **changes)
    end
  end
end
