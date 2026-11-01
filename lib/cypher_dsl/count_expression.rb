# frozen_string_literal: true

module CypherDSL
  # `COUNT { pattern [WHERE …] }` / `COUNT { [WITH imports] statement }`.
  class CountExpression
    include Expression

    attr_reader :body, :imports, :where_condition

    def initialize(body, imports = [], where_condition: nil)
      @body = body
      @imports = imports.freeze
      @where_condition = where_condition
      freeze
    end

    # `COUNT { pattern WHERE condition }`.
    def where(condition) = CountExpression.new(body, imports, where_condition: Condition.coerce(condition))
  end
end
