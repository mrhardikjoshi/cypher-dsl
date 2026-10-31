# frozen_string_literal: true

module CypherDSL
  # Index and slice access on lists: `list[0]`, `list[1..3]`, `list[..2]`.
  class ListOperator
    include Expression

    attr_reader :list, :start_index, :end_index, :slice

    def self.value_at(list, index) = new(list, Expression.coerce(index), nil, false)

    def self.sublist(list, start_index = nil, end_index = nil)
      new(list, start_index && Expression.coerce(start_index), end_index && Expression.coerce(end_index), true)
    end

    def initialize(list, start_index, end_index, slice)
      @list = list
      @start_index = start_index
      @end_index = end_index
      @slice = slice
      freeze
    end
  end
end
