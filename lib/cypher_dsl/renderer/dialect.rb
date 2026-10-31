# frozen_string_literal: true

module CypherDSL
  class Renderer
    # Target Cypher dialects. Neo4j 5 is the default; Neo4j 4 renders
    # `elementId(x)` as `toString(id(x))`, which did not exist there.
    module Dialect
      NEO4J_4 = :neo4j4
      NEO4J_5 = :neo4j5

      ALL = [NEO4J_4, NEO4J_5].freeze
    end
  end
end
