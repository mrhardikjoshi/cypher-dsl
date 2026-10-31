# frozen_string_literal: true

module CypherDSL
  # `EXISTS { pattern }` / `EXISTS { [WITH imports] statement }`.
  class ExistsCondition < Condition
    attr_reader :body, :imports

    def initialize(body, imports = [])
      super()
      @body = body
      @imports = imports.freeze
      freeze
    end
  end
end
