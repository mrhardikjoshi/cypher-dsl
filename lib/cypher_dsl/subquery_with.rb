# frozen_string_literal: true

module CypherDSL
  # `Cypher.subquery_with(imports…)`: imports for an EXISTS or COLLECT subquery,
  # rendered as a leading `WITH` inside the braces.
  class SubqueryWith
    def initialize(imports)
      @imports = imports.flatten.map { |import| Expression.coerce(import) }.freeze
      freeze
    end

    def collect(statement) = CollectExpression.new(statement, @imports)
    def exists(statement_or_pattern) = ExistsCondition.new(statement_or_pattern, @imports)
  end
end
