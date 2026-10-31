# frozen_string_literal: true

module CypherDSL
  # A function call such as `size((a)-->())` or `count(n)`.
  class FunctionInvocation
    include Expression

    attr_reader :function_name, :arguments, :distinct

    def initialize(function_name, arguments, distinct: false)
      @function_name = function_name
      @arguments = arguments.freeze
      @distinct = distinct
      freeze
    end
  end
end
