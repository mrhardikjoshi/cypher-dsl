# frozen_string_literal: true

# Translated from CypherIT.java, nested class CreateClause.
module CypherDSL
  RSpec.describe 'CypherIT / CreateClause' do
    let(:bike_node) { Cypher.node('Bike').named(:b) }
    let(:user_node) { Cypher.node('User').named(:u) }
    let(:renderer) { Renderer.default }

    it 'renders create without return' do
      statement = Cypher.create(user_node).build

      expect(renderer.render(statement)).to eq('CREATE (u:`User`)')

      statement = Cypher.create(user_node.relationship_to(bike_node, 'OWNS').named(:o)).build

      expect(renderer.render(statement)).to eq('CREATE (u:`User`)-[o:`OWNS`]->(b:`Bike`)')
    end

    it 'renders create based on pattern element collection without return' do # GH-189
      statement = Cypher.create([user_node]).build

      expect(renderer.render(statement)).to eq('CREATE (u:`User`)')

      statement = Cypher.create(user_node.relationship_to(bike_node, 'OWNS').named(:o)).build

      expect(renderer.render(statement)).to eq('CREATE (u:`User`)-[o:`OWNS`]->(b:`Bike`)')
    end

    it 'renders multiple creates without return' do
      statement = Cypher.create(user_node).create(bike_node).build

      expect(renderer.render(statement)).to eq('CREATE (u:`User`) CREATE (b:`Bike`)')

      statement = Cypher.create(user_node.relationship_to(bike_node, 'OWNS').named(:o))
                        .create(Cypher.node('Other'))
                        .build

      expect(renderer.render(statement)).to eq('CREATE (u:`User`)-[o:`OWNS`]->(b:`Bike`) CREATE (:`Other`)')
    end

    it 'renders multiple creates based on pattern element collection without return' do
      statement = Cypher.create(user_node).create([bike_node]).build

      expect(renderer.render(statement)).to eq('CREATE (u:`User`) CREATE (b:`Bike`)')

      statement = Cypher.create(user_node.relationship_to(bike_node, 'OWNS').named(:o))
                        .create([Cypher.node('Other')])
                        .build

      expect(renderer.render(statement)).to eq('CREATE (u:`User`)-[o:`OWNS`]->(b:`Bike`) CREATE (:`Other`)')
    end

    it 'renders create return' do
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

    it 'renders multiple creates return' do
      statement = Cypher.create(user_node).create(bike_node).returning(user_node).build

      expect(renderer.render(statement)).to eq('CREATE (u:`User`) CREATE (b:`Bike`) RETURN u')

      r = user_node.relationship_to(bike_node, 'OWNS').named(:o)
      statement = Cypher.create(user_node.relationship_to(bike_node, 'OWNS').named(:o))
                        .create(Cypher.node('Other'))
                        .returning(user_node, r)
                        .build

      expect(renderer.render(statement)).to eq('CREATE (u:`User`)-[o:`OWNS`]->(b:`Bike`) CREATE (:`Other`) RETURN u, o')
    end

    it 'renders create with with' do
      statement = Cypher.create(user_node).with(user_node).returning(user_node).build

      expect(renderer.render(statement)).to eq('CREATE (u:`User`) WITH u RETURN u')

      statement = Cypher.create(user_node)
                        .with(user_node)
                        .set(user_node.property(:x).to(Cypher.literal_of('y')))
                        .build

      expect(renderer.render(statement)).to eq("CREATE (u:`User`) WITH u SET u.x = 'y'")
    end

    it 'match should expose create' do
      statement = Cypher.match(user_node).create(user_node.relationship_to(bike_node, 'OWNS').named(:o)).build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) CREATE (u)-[o:`OWNS`]->(b:`Bike`)')
    end

    it 'with should expose create' do
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

    it 'with with string vars should work' do
      statement = Cypher.match(user_node)
                        .with_distinct('u')
                        .create(user_node.relationship_to(bike_node, 'OWNS').named(:o))
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) WITH DISTINCT u CREATE (u)-[o:`OWNS`]->(b:`Bike`)')
    end
  end
end
