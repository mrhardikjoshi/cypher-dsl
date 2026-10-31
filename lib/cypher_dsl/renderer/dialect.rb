# frozen_string_literal: true

module CypherDSL
  class Renderer
    # Target Cypher dialects.
    #
    # - NEO4J_4: `CALL { WITH imports … }` subqueries, `elementId(x)` rendered as `toString(id(x))`.
    # - NEO4J_5: `CALL { WITH imports … }` subqueries, native `elementId`.
    # - NEO4J_5_23 (default, Neo4j 5.23+): `CALL (imports) { … }` subqueries.
    module Dialect
      NEO4J_4 = :neo4j4
      NEO4J_5 = :neo4j5
      NEO4J_5_23 = :neo4j5_23 # rubocop:disable Naming/VariableNumber
      NEO4J_5_DEFAULT_CYPHER = NEO4J_5_23

      ALL = [NEO4J_4, NEO4J_5, NEO4J_5_23].freeze
      LEGACY_SUBQUERY_SYNTAX = [NEO4J_4, NEO4J_5].freeze
    end
  end
end
