# frozen_string_literal: true

module CypherDSL
  # A function call such as `size((a)-->())` or `count(n)`.
  class FunctionInvocation
    include Expression

    # The functions that accept `DISTINCT`, lower-cased.
    AGGREGATES = %w[avg collect count max min percentilecont percentiledisc stdev stdevp sum].freeze

    attr_reader :function_name, :arguments, :distinct

    def initialize(function_name, arguments, distinct: false)
      if distinct && !AGGREGATES.include?(function_name.downcase)
        raise ArgumentError, 'The distinct operator can only be applied within aggregate functions.'
      end

      @function_name = function_name
      @arguments = arguments.freeze
      @distinct = distinct
      freeze
    end
  end
end
