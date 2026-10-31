# frozen_string_literal: true

module CypherDSL
  class Renderer
    # Target Cypher dialects, mirroring the Java enum.
    #
    # - NEO4J_4: `CALL { WITH imports … }` subqueries, `shortestPath()` functions,
    #   `exists(n.prop)`, `distance()`, `elementId(x)` rendered as `toString(id(x))`.
    # - NEO4J_5: as above with native `elementId`, `point.distance()` and `n.prop IS NOT NULL`.
    # - NEO4J_5_23: `CALL (imports) { … }` subqueries and `SHORTEST k` path selectors.
    # - NEO4J_5_26: adds dynamic labels (`n:$($labels)`) and the `CYPHER 5` prefix.
    # - NEO4J_5_DEFAULT_CYPHER (default): like NEO4J_5_26 without the prefix.
    # - NEO4J_5_CYPHER_5 / NEO4J_5_CYPHER_25: with an explicit `CYPHER 5` / `CYPHER 25` prefix.
    # - NEO4J_2025: like NEO4J_5_23.
    module Dialect
      # rubocop:disable Naming/VariableNumber
      NEO4J_4 = :neo4j4
      NEO4J_5 = :neo4j5
      NEO4J_5_23 = :neo4j5_23
      NEO4J_5_26 = :neo4j5_26
      NEO4J_5_DEFAULT_CYPHER = :neo4j5_default_cypher
      NEO4J_5_CYPHER_5 = :neo4j5_cypher_5
      NEO4J_5_CYPHER_25 = :neo4j5_cypher_25
      NEO4J_2025 = :neo4j2025
      # rubocop:enable Naming/VariableNumber

      ALL = [NEO4J_4, NEO4J_5, NEO4J_5_23, NEO4J_5_26, NEO4J_5_DEFAULT_CYPHER, NEO4J_5_CYPHER_5, NEO4J_5_CYPHER_25,
             NEO4J_2025].freeze
      LEGACY_SUBQUERY_SYNTAX = [NEO4J_4, NEO4J_5].freeze
      LEGACY_PATH_SELECTORS = [NEO4J_4, NEO4J_5].freeze
      DYNAMIC_LABELS = [NEO4J_5_26, NEO4J_5_DEFAULT_CYPHER, NEO4J_5_CYPHER_5, NEO4J_5_CYPHER_25].freeze
      PREFIXES = {
        NEO4J_5_26 => 'CYPHER 5 ', NEO4J_5_CYPHER_5 => 'CYPHER 5 ', NEO4J_5_CYPHER_25 => 'CYPHER 25 '
      }.freeze
    end
  end
end
