# frozen_string_literal: true

# Translated from CypherIT.java, nested class CreateClause.
module CypherDSL
  RSpec.describe 'CypherIT / CreateClause' do
    let(:bike_node) { Cypher.node('Bike').named(:b) }
    let(:user_node) { Cypher.node('User').named(:u) }
    let(:renderer) { Renderer.default }

    it 'shouldRenderCreateWithoutReturn' do
      statement = Cypher.create(user_node).build

      expect(renderer.render(statement)).to eq('CREATE (u:`User`)')

      statement = Cypher.create(user_node.relationship_to(bike_node, 'OWNS').named(:o)).build

      expect(renderer.render(statement)).to eq('CREATE (u:`User`)-[o:`OWNS`]->(b:`Bike`)')
    end

    it 'shouldRenderCreateBasedOnPatternElementCollectionWithoutReturn' do # GH-189
      statement = Cypher.create([user_node]).build

      expect(renderer.render(statement)).to eq('CREATE (u:`User`)')

      statement = Cypher.create(user_node.relationship_to(bike_node, 'OWNS').named(:o)).build

      expect(renderer.render(statement)).to eq('CREATE (u:`User`)-[o:`OWNS`]->(b:`Bike`)')
    end

    it 'shouldRenderMultipleCreatesWithoutReturn' do
      statement = Cypher.create(user_node).create(bike_node).build

      expect(renderer.render(statement)).to eq('CREATE (u:`User`) CREATE (b:`Bike`)')

      statement = Cypher.create(user_node.relationship_to(bike_node, 'OWNS').named(:o))
                        .create(Cypher.node('Other'))
                        .build

      expect(renderer.render(statement)).to eq('CREATE (u:`User`)-[o:`OWNS`]->(b:`Bike`) CREATE (:`Other`)')
    end

    it 'shouldRenderMultipleCreatesBasedOnPatternElementCollectionWithoutReturn' do
      statement = Cypher.create(user_node).create([bike_node]).build

      expect(renderer.render(statement)).to eq('CREATE (u:`User`) CREATE (b:`Bike`)')

      statement = Cypher.create(user_node.relationship_to(bike_node, 'OWNS').named(:o))
                        .create([Cypher.node('Other')])
                        .build

      expect(renderer.render(statement)).to eq('CREATE (u:`User`)-[o:`OWNS`]->(b:`Bike`) CREATE (:`Other`)')
    end

    it 'shouldRenderCreateReturn' do
      statement = Cypher.create(user_node).returning(user_node).build

      expect(renderer.render(statement)).to eq('CREATE (u:`User`) RETURN u')

      r = user_node.relationship_to(bike_node, 'OWNS').named(:o)
      statement = Cypher.create(r).returning(user_node, r).build

      expect(renderer.render(statement)).to eq('CREATE (u:`User`)-[o:`OWNS`]->(b:`Bike`) RETURN u, o')

      statement = Cypher.create(user_node)
                        .returning(user_node)
                        .order_by(user_node.property(:name))
                        .skip(23)
                        .limit(42)
                        .build

      expect(renderer.render(statement)).to eq('CREATE (u:`User`) RETURN u ORDER BY u.name SKIP 23 LIMIT 42')
    end

    it 'shouldRenderMultipleCreatesReturn' do
      statement = Cypher.create(user_node).create(bike_node).returning(user_node).build

      expect(renderer.render(statement)).to eq('CREATE (u:`User`) CREATE (b:`Bike`) RETURN u')

      r = user_node.relationship_to(bike_node, 'OWNS').named(:o)
      statement = Cypher.create(user_node.relationship_to(bike_node, 'OWNS').named(:o))
                        .create(Cypher.node('Other'))
                        .returning(user_node, r)
                        .build

      expect(renderer.render(statement)).to eq('CREATE (u:`User`)-[o:`OWNS`]->(b:`Bike`) CREATE (:`Other`) RETURN u, o')
    end

    it 'shouldRenderCreateWithWith' do
      statement = Cypher.create(user_node).with(user_node).returning(user_node).build

      expect(renderer.render(statement)).to eq('CREATE (u:`User`) WITH u RETURN u')

      statement = Cypher.create(user_node)
                        .with(user_node)
                        .set(user_node.property(:x).to(Cypher.literal_of('y')))
                        .build

      expect(renderer.render(statement)).to eq("CREATE (u:`User`) WITH u SET u.x = 'y'")
    end

    it 'matchShouldExposeCreate' do
      statement = Cypher.match(user_node).create(user_node.relationship_to(bike_node, 'OWNS').named(:o)).build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) CREATE (u)-[o:`OWNS`]->(b:`Bike`)')
    end

    it 'withShouldExposeCreate' do
      statement = Cypher.match(user_node)
                        .with_distinct(user_node)
                        .create(user_node.relationship_to(bike_node, 'OWNS').named(:o))
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) WITH DISTINCT u CREATE (u)-[o:`OWNS`]->(b:`Bike`)')

      statement = Cypher.match(user_node)
                        .with_distinct(user_node.required_symbolic_name)
                        .create(user_node.relationship_to(bike_node, 'OWNS').named(:o))
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) WITH DISTINCT u CREATE (u)-[o:`OWNS`]->(b:`Bike`)')
    end

    it 'withWithStringVarsShouldWork' do
      statement = Cypher.match(user_node)
                        .with_distinct('u')
                        .create(user_node.relationship_to(bike_node, 'OWNS').named(:o))
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) WITH DISTINCT u CREATE (u)-[o:`OWNS`]->(b:`Bike`)')
    end
  end
end
