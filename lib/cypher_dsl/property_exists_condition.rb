# frozen_string_literal: true

module CypherDSL
  # `Cypher.exists(n.prop)`: `exists(n.prop)` on Neo4j 4, `n.prop IS NOT NULL`
  # from Neo4j 5 on (and `n.prop IS NULL` when negated).
  class PropertyExistsCondition < Condition
    attr_reader :property

    def initialize(property)
      super()
      @property = property
      freeze
    end
  end
end
