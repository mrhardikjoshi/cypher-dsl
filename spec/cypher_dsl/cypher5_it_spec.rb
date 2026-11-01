# frozen_string_literal: true

# Translated from Cypher5IT.java (tests around GH-1153).
#
# Adapted: `DecoratedQuery.explain(statement)` is `statement.explain`.
module CypherDSL
  RSpec.describe 'Cypher5IT' do
    let(:renderer) do
      Renderer.get_renderer(Renderer::Configuration.new_config
                                                   .always_escape_names(false)
                                                   .with_dialect(Renderer::Dialect::NEO4J_5_CYPHER_5)
                                                   .build)
    end
    let(:bike_node) { Cypher.node('Bike').named(:b) }

    it 'cypher5 prefix on simple statements' do
      n = Cypher.node('Movie').named(:n)
      stmt = Cypher.match(n).returning(n).build
      expect(renderer.render(stmt)).to eq('CYPHER 5 MATCH (n:Movie) RETURN n')
    end

    it 'union should not have double prefixes' do
      statement1 = Cypher.match(bike_node).where(bike_node.property(:a).is_equal_to(Cypher.literal_of('A'))).returning(bike_node).build
      statement2 = Cypher.match(bike_node).where(bike_node.property(:b).is_equal_to(Cypher.literal_of('B'))).returning(bike_node).build
      statement3 = Cypher.match(bike_node).where(bike_node.property(:c).is_equal_to(Cypher.literal_of('C'))).returning(bike_node).build

      statement = Cypher.union(statement1, statement2, statement3)
      expect(renderer.render(statement)).to eq(
        "CYPHER 5 MATCH (b:Bike) WHERE b.a = 'A' RETURN b UNION MATCH (b:Bike) WHERE b.b = 'B' RETURN b UNION MATCH (b:Bike) WHERE b.c = 'C' RETURN b"
      )
    end

    it 'use should work' do
      statement = Cypher.match(Cypher.any_node(:n)).returning(:n).build
      cypher = renderer.render(Cypher.use('neo4j', statement))
      expect(cypher).to eq('CYPHER 5 USE neo4j MATCH (n) RETURN n')
    end

    it 'explain should work' do
      statement = Cypher.match(Cypher.any_node(:n)).returning(:n).build
      cypher = renderer.render(statement.explain)
      expect(cypher).to eq('CYPHER 5 EXPLAIN MATCH (n) RETURN n')
    end
  end
end
