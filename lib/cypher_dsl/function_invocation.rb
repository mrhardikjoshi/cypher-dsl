# frozen_string_literal: true

module CypherDSL
  # A function call such as `size((a)-->())` or `count(n)`.
  class FunctionInvocation
    include Expression

    attr_reader :function_name, :arguments

    def initialize(function_name, arguments)
      @function_name = function_name
      @arguments = arguments.freeze
      freeze
    end
  end
end
