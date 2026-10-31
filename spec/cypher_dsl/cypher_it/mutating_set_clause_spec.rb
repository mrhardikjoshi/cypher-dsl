# frozen_string_literal: true

# Translated from CypherIT.java, nested class MutatingSetClause.
module CypherDSL
  RSpec.describe 'CypherIT / MutatingSetClause' do
    let(:bike_node) { Cypher.node('Bike').named(:b) }
    let(:user_node) { Cypher.node('User').named(:u) }
    let(:renderer) { Renderer.default }

    it 'simpleWithParam' do
      statement = Cypher.match(user_node)
                        .mutate(user_node, Cypher.parameter(:newMapsOfHell))
                        .returning(user_node)
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) SET u += $newMapsOfHell RETURN u')
    end

    it 'afterMerge' do
      statement = Cypher.merge(user_node)
                        .on_match
                        .mutate(user_node, Cypher.parameter(:newMapsOfHell))
                        .on_create
                        .mutate(user_node, Cypher.map_of('a', Cypher.literal_of('B')))
                        .returning(user_node)
                        .build

      expect(renderer.render(statement))
        .to eq("MERGE (u:`User`) ON MATCH SET u += $newMapsOfHell ON CREATE SET u += {a: 'B'} RETURN u")
    end

    it 'simpleWithMap' do
      statement = Cypher.match(user_node)
                        .mutate(user_node, Cypher.map_of('a', Cypher.literal_of('B')))
                        .returning(user_node)
                        .build

      expect(renderer.render(statement)).to eq("MATCH (u:`User`) SET u += {a: 'B'} RETURN u")
    end

    it 'chainedWithParam' do
      statement = Cypher.match(user_node.relationship_to(bike_node, 'OWNS').named(:r))
                        .mutate(user_node, Cypher.map_of('a', Cypher.literal_of('B')))
                        .mutate(bike_node, Cypher.parameter(:newMapsOfHell))
                        .returning(user_node)
                        .build

      expect(renderer.render(statement)).to eq(
        "MATCH (u:`User`)-[r:`OWNS`]->(b:`Bike`) SET u += {a: 'B'} SET b += $newMapsOfHell RETURN u"
      )
    end

    it 'chainedWithMap' do
      statement = Cypher.match(user_node.relationship_to(bike_node, 'OWNS').named(:r))
                        .mutate(user_node, Cypher.map_of('a', Cypher.literal_of('B')))
                        .mutate(bike_node, Cypher.map_of('c', Cypher.literal_of('D')))
                        .returning(user_node)
                        .build

      expect(renderer.render(statement))
        .to eq("MATCH (u:`User`)-[r:`OWNS`]->(b:`Bike`) SET u += {a: 'B'} SET b += {c: 'D'} RETURN u")
    end

    it 'multipleLevelsOfChaining' do
      statement = Cypher.match(user_node.relationship_to(bike_node, 'OWNS').named(:r))
                        .mutate(user_node, Cypher.map_of('a', Cypher.literal_of('B')))
                        .mutate(bike_node, Cypher.map_of('c', Cypher.literal_of('D')))
                        .mutate(Cypher.name(:r), Cypher.map_of('e', Cypher.literal_of('F')))
                        .returning(user_node)
                        .build

      expect(renderer.render(statement)).to eq(
        "MATCH (u:`User`)-[r:`OWNS`]->(b:`Bike`) SET u += {a: 'B'} SET b += {c: 'D'} SET r += {e: 'F'} RETURN u"
      )
    end

    it 'foldingMultipleMutatesIntoOne' do
      owns_relationship = user_node.relationship_to(bike_node, 'OWNS').named(:r)
      statement = Cypher.match(owns_relationship)
                        .set(user_node.mutate(Cypher.map_of('a', Cypher.literal_of('B'))),
                             bike_node.mutate(Cypher.map_of('c', Cypher.literal_of('D'))),
                             owns_relationship.mutate(Cypher.map_of('e', Cypher.literal_of('F'))))
                        .returning(user_node)
                        .build

      expect(renderer.render(statement)).to eq(
        "MATCH (u:`User`)-[r:`OWNS`]->(b:`Bike`) SET u += {a: 'B'}, b += {c: 'D'}, r += {e: 'F'} RETURN u"
      )
    end

    it 'afterMergeFolding' do
      owns_relationship = user_node.relationship_to(bike_node, 'OWNS').named(:r)
      statement = Cypher.merge(owns_relationship)
                        .on_match
                        .set(user_node.mutate(Cypher.map_of('a', Cypher.literal_of('B'))),
                             bike_node.mutate(Cypher.map_of('c', Cypher.literal_of('D'))),
                             owns_relationship.mutate(Cypher.map_of('e', Cypher.literal_of('F'))))
                        .on_create
                        .mutate(user_node, Cypher.map_of('a', Cypher.literal_of('B')))
                        .returning(user_node)
                        .build

      expect(renderer.render(statement)).to eq(
        "MERGE (u:`User`)-[r:`OWNS`]->(b:`Bike`) ON MATCH SET u += {a: 'B'}, b += {c: 'D'}, r += {e: 'F'} ON CREATE SET u += {a: 'B'} RETURN u"
      )
    end

    it 'mergeMutate' do
      statement = Cypher.merge(user_node)
                        .mutate(user_node, Cypher.map_of('e', Cypher.literal_of('F')))
                        .returning(user_node)
                        .build

      expect(renderer.render(statement)).to eq("MERGE (u:`User`) SET u += {e: 'F'} RETURN u")
    end

    it 'createMutate' do
      statement = Cypher.create(user_node)
                        .mutate(user_node, Cypher.map_of('e', Cypher.literal_of('F')))
                        .returning(user_node)
                        .build

      expect(renderer.render(statement)).to eq("CREATE (u:`User`) SET u += {e: 'F'} RETURN u")
    end

    it 'mergeMutateWithMapProjection' do
      map = Cypher.name(:map)

      statement = Cypher
                  .with(Cypher.map_of('p', Cypher.literal_of('Hello, Welt'), 'i', Cypher.literal_of(1)).as(map))
                  .merge(user_node)
                  .mutate(user_node, map.project(Cypher.asterisk))
                  .build

      expect(renderer.render(statement)).to eq("WITH {p: 'Hello, Welt', i: 1} AS map MERGE (u:`User`) SET u += map{.*}")
    end

    it 'mergeMutateWithSymbolicName' do
      map = Cypher.name(:map)

      statement = Cypher
                  .with(Cypher.map_of('p', Cypher.literal_of('Hello, Welt'), 'i', Cypher.literal_of(1)).as(map))
                  .merge(user_node)
                  .mutate(user_node, map)
                  .build

      expect(renderer.render(statement)).to eq("WITH {p: 'Hello, Welt', i: 1} AS map MERGE (u:`User`) SET u += map")
    end

    it 'mergeMutateWithFunctionCall' do
      statement = Cypher.merge(user_node).mutate(user_node, Cypher.call('returns.map').as_function).build

      expect(renderer.render(statement)).to eq('MERGE (u:`User`) SET u += returns.map()')
    end
  end
end
