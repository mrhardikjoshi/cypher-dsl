# frozen_string_literal: true

module CypherDSL
  # `COLLECT { [WITH imports] statement }`: the statement must end with a RETURN of one column.
  class CollectExpression
    include Expression

    MESSAGE = 'The final RETURN clause in a subquery used with COLLECT is mandatory and ' \
              'the RETURN clause must return exactly one column.'

    attr_reader :statement, :imports

    def initialize(statement, imports = [])
      raise ArgumentError, MESSAGE unless CollectExpression.single_column?(statement)

      @statement = statement
      @imports = imports.freeze
      freeze
    end

    def self.single_column?(statement)
      return statement.statements.all? { |inner| single_column?(inner) } if statement.is_a?(UnionQuery)

      last = statement.clauses.last
      last.is_a?(Clauses::Return) && last.items.size == 1
    end
  end
end
