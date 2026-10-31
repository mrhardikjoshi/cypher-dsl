# frozen_string_literal: true

module CypherDSL
  # One item of an ORDER BY: an expression with an optional direction.
  class SortItem
    attr_reader :expression, :direction

    def initialize(expression, direction)
      @expression = expression
      @direction = direction
      freeze
    end

    def ascending = SortItem.new(expression, :asc)
    def descending = SortItem.new(expression, :desc)
  end
end
