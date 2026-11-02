# frozen_string_literal: true

# Regression coverage for WITH aliases used in relationship predicates.
module CypherDSL
  RSpec.describe 'WITH alias scope' do
    let(:node) { Cypher.any_node(:n) }
    let(:alias_node) { Cypher.any_node(:m) }
    let(:condition) { alias_node.relationship_to(Cypher.any_node) }
    let(:statement) do
      Cypher.match(node).with(node.as(:m)).where(condition).returning(:m).build
    end

    it 'keeps projected node aliases in relationship predicates' do
      expect(statement.cypher).to eq('MATCH (n) WITH n AS m WHERE (m)-->() RETURN m')
    end

    it 'keeps aliases projected with distinct' do
      query = Cypher.match(node).with_distinct(node.as(:m)).where(condition).returning(:m).build

      expect(query.cypher).to eq('MATCH (n) WITH DISTINCT n AS m WHERE (m)-->() RETURN m')
    end

    it 'keeps incoming names available to where and drops them afterwards' do
      source = Cypher.node('Person').named(:n)
      target = Cypher.node('Person').named(:other)
      query = Cypher.match(source, target).with(source.as(:m))
                    .where(alias_node.relationship_to(target))
                    .match(target).returning(:m, :other).build

      expected = 'MATCH (n:`Person`), (other:`Person`) WITH n AS m WHERE (m)-->(other) MATCH (other:`Person`) RETURN m, other'
      expect(query.cypher).to eq(expected)
    end

    it 'carries aliases projected alongside an asterisk into subsequent clauses' do
      query = Cypher.match(node).with(Cypher.asterisk, node.as(:m))
                    .with(Cypher.asterisk).where(condition).returning(:n, :m).build

      expect(query.cypher).to eq('MATCH (n) WITH *, n AS m WITH * WHERE (m)-->() RETURN n, m')
    end

    it 'keeps projected relationship aliases in relationship predicates' do
      relationship = node.relationship_to(Cypher.any_node, 'KNOWS').named(:r)
      predicate = node.relationship_to(Cypher.any_node).named(:s)
      query = Cypher.match(relationship).with(node, relationship.as(:s))
                    .where(predicate).returning(:s).build

      expected = 'MATCH (n)-[r:`KNOWS`]->() WITH n, r AS s WHERE (n)-[s]->() RETURN s'
      expect(query.cypher).to eq(expected)
    end

    it 'resolves generated aliases before rendering where' do
      config = Renderer::Configuration.new_config.with_generated_names(true).build

      expect(Renderer.get_renderer(config).render(statement)).to eq('MATCH (v0) WITH v0 AS v1 WHERE (v1)-->() RETURN v1')
    end

    it 'escapes projected aliases in relationship predicates' do
      name = 'node alias'
      predicate = Cypher.any_node(name).relationship_to(Cypher.any_node)
      query = Cypher.match(node).with(node.as(name)).where(predicate).returning(Cypher.name(name)).build

      expect(query.cypher).to eq('MATCH (n) WITH n AS `node alias` WHERE (`node alias`)-->() RETURN `node alias`')
    end

    it 'preserves the where line when pretty printing' do
      config = Renderer::Configuration.new(pretty_print: true)
      expected = "MATCH (n)\nWITH n AS m\nWHERE (m)-->()\nRETURN m"

      expect(Renderer.get_renderer(config).render(statement)).to eq(expected)
    end
  end
end
