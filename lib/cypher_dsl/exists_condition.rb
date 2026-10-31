# frozen_string_literal: true

module CypherDSL
  # `EXISTS { pattern }` / `EXISTS { statement }`.
  class ExistsCondition < Condition
    attr_reader :body

    def initialize(body)
      super()
      @body = body
      freeze
    end
  end
end
