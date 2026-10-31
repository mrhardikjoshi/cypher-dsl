# frozen_string_literal: true

module CypherDSL
  # Several statements combined with UNION or UNION ALL.
  class UnionQuery < Statement
    attr_reader :statements, :all

    # Appends to an existing union when the first statement already is one of the same kind.
    def self.create(statements, all:)
      statements = statements.flatten
      raise ArgumentError, 'A union needs at least two statements.' if statements.size < 2

      first = statements.first
      return new(statements, all:) unless first.is_a?(UnionQuery)
      raise ArgumentError, 'Cannot mix union and union all!' unless first.all == all

      new(first.statements + statements.drop(1), all:)
    end

    def initialize(statements, all:)
      super([])
      @statements = statements.freeze
      @all = all
    end

    def result_statement? = true
    def multi_part_query? = false
  end
end
