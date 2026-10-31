# frozen_string_literal: true

module CypherDSL
  # `COUNT { pattern }` / `COUNT { statement }`.
  class CountExpression
    include Expression

    attr_reader :body, :imports

    def initialize(body, imports = [])
      @body = body
      @imports = imports.freeze
      freeze
    end
  end
end
