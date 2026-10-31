# frozen_string_literal: true

module CypherDSL
  # The start of `Cypher.call('procedure')`: either a standalone CALL clause or,
  # via `as_function`, a function invocation of the procedure.
  class StandaloneCall
    attr_reader :procedure_name

    def initialize(procedure_name)
      @procedure_name = procedure_name
      freeze
    end

    def as_function(*arguments) = FunctionInvocation.new(procedure_name, arguments.map { |a| Expression.coerce(a) })
  end
end
