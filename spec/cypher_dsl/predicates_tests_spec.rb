# frozen_string_literal: true

# Translated from PredicatesTests.java.
#
# Adapted: the Java `Predicates.exists` overloads are `Cypher.exists`; instead of inspecting the
# wrapped function's name, the rendering with the Neo4j 4 dialect is checked.
module CypherDSL
  RSpec.describe 'PredicatesTests' do
    let(:renderer) { Renderer.get_renderer(Renderer::Configuration.new_config.with_dialect(Renderer::Dialect::NEO4J_4).build) }

    it 'preconditions should be asserted' do
      expect { Cypher.exists(nil) }.to raise_error(ArgumentError, /is required\.\z/)
    end

    it 'function invocations should be created(property)' do
      n = Cypher.any_node(:n)
      statement = Cypher.match(n).where(Cypher.exists(n.property(:x))).returning(n).build
      expect(renderer.render(statement)).to eq('MATCH (n) WHERE exists(n.x) RETURN n')
    end

    it 'function invocations should be created(relationship pattern)' do
      n = Cypher.any_node(:n)
      statement = Cypher.match(n).where(Cypher.exists(n.relationship_to(Cypher.any_node))).returning(n).build
      expect(renderer.render(statement)).to eq('MATCH (n) WHERE exists((n)-->()) RETURN n')
    end
  end
end
