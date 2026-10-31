# frozen_string_literal: true

# Translated from CypherIT.java, nested class SingleQueryMultiPart.
module CypherDSL
  RSpec.describe 'CypherIT / SingleQueryMultiPart' do
    let(:bike_node) { Cypher.node('Bike').named(:b) }
    let(:user_node) { Cypher.node('User').named(:u) }
    let(:renderer) { Renderer.default }

    it 'simpleWith' do
      statement = Cypher.match(user_node.relationship_to(bike_node, 'OWNS'))
                        .where(user_node.property(:a).is_null)
                        .with(bike_node, user_node)
                        .returning(bike_node)
                        .build

      expect(renderer.render(statement))
        .to eq('MATCH (u:`User`)-[:`OWNS`]->(b:`Bike`) WHERE u.a IS NULL WITH b, u RETURN b')
    end

    it 'shouldRenderLeadingWith' do
      statement = Cypher.with(Cypher.parameter(:listOfPropertyMaps).as(:p))
                        .unwind(:p)
                        .as(:item)
                        .returning(:item)
                        .build

      expect(renderer.render(statement)).to eq('WITH $listOfPropertyMaps AS p UNWIND p AS item RETURN item')
    end

    it 'shouldRenderLeadingWithBasedOnExpression' do # GH-189
      statement = Cypher.with([Cypher.parameter(:listOfPropertyMaps).as(:p)])
                        .unwind(:p)
                        .as(:item)
                        .returning(:item)
                        .build

      expect(renderer.render(statement)).to eq('WITH $listOfPropertyMaps AS p UNWIND p AS item RETURN item')
    end

    it 'withWithSkip' do # GH-129
      m = Cypher.node('Movie').named(:m)
      statement = Cypher.match(m).with(m).skip(1).returning(Cypher.count(m)).build

      expect(renderer.render(statement)).to eq('MATCH (m:`Movie`) WITH m SKIP 1 RETURN count(m)')

      statement = Cypher.match(m).with(m).skip(Cypher.parameter(:skip)).returning(Cypher.count(m)).build

      expect(renderer.render(statement)).to eq('MATCH (m:`Movie`) WITH m SKIP $skip RETURN count(m)')
    end

    it 'withWithLimit' do # GH-129
      m = Cypher.node('Movie').named(:m)
      statement = Cypher.match(m).with(m).limit(23).returning(Cypher.count(m)).build

      expect(renderer.render(statement)).to eq('MATCH (m:`Movie`) WITH m LIMIT 23 RETURN count(m)')

      statement = Cypher.match(m).with(m).limit(Cypher.parameter(:limit)).returning(Cypher.count(m)).build

      expect(renderer.render(statement)).to eq('MATCH (m:`Movie`) WITH m LIMIT $limit RETURN count(m)')
    end

    it 'withWithSkipAndLimit' do # GH-129
      m = Cypher.node('Movie').named(:m)
      statement = Cypher.match(m).with(m).skip(1).limit(23).returning(Cypher.count(m)).build

      expect(renderer.render(statement)).to eq('MATCH (m:`Movie`) WITH m SKIP 1 LIMIT 23 RETURN count(m)')

      statement = Cypher.match(m)
                        .with(m)
                        .skip(Cypher.parameter(:skip))
                        .limit(Cypher.parameter(:limit))
                        .returning(Cypher.count(m))
                        .build

      expect(renderer.render(statement)).to eq('MATCH (m:`Movie`) WITH m SKIP $skip LIMIT $limit RETURN count(m)')
    end

    it 'withWithAndNullsForSkipAndLimit' do # GH-129
      m = Cypher.node('Movie').named(:m)
      statement = Cypher.match(m)
                        .with(m)
                        .skip(nil)
                        .limit(nil)
                        .returning(Cypher.count(m))
                        .build

      expected = 'MATCH (m:`Movie`) WITH m RETURN count(m)'
      expect(renderer.render(statement)).to eq(expected)
    end

    it 'simpleWithChained' do
      trip_node = Cypher.node('Trip').named(:t)
      statement = Cypher.match(user_node.relationship_to(bike_node, 'OWNS'))
                        .where(user_node.property(:a).is_null)
                        .with(bike_node, user_node)
                        .match(trip_node)
                        .where(trip_node.property(:name).is_equal_to(Cypher.literal_of('Festive500')))
                        .with(bike_node, user_node, trip_node)
                        .returning(bike_node, user_node, trip_node)
                        .build

      expect(renderer.render(statement)).to eq(
        "MATCH (u:`User`)-[:`OWNS`]->(b:`Bike`) WHERE u.a IS NULL WITH b, u MATCH (t:`Trip`) WHERE t.name = 'Festive500' WITH b, u, t RETURN b, u, t"
      )
    end

    it 'deletingSimpleWith' do
      statement = Cypher.match(user_node.relationship_to(bike_node, 'OWNS'))
                        .where(user_node.property(:a).is_null)
                        .delete(user_node)
                        .with(bike_node, user_node)
                        .returning(bike_node, user_node)
                        .build

      expect(renderer.render(statement))
        .to eq('MATCH (u:`User`)-[:`OWNS`]->(b:`Bike`) WHERE u.a IS NULL DELETE u WITH b, u RETURN b, u')
    end

    it 'deletingSimpleWithReverse' do
      statement = Cypher.match(user_node.relationship_to(bike_node, 'OWNS'))
                        .where(user_node.property(:a).is_null)
                        .with(bike_node, user_node)
                        .delete(user_node)
                        .returning(bike_node, user_node)
                        .build

      expect(renderer.render(statement))
        .to eq('MATCH (u:`User`)-[:`OWNS`]->(b:`Bike`) WHERE u.a IS NULL WITH b, u DELETE u RETURN b, u')
    end

    it 'mixedClausesWithWith' do
      trip_node = Cypher.node('Trip').named(:t)
      statement = Cypher.match(user_node.relationship_to(bike_node, 'OWNS'))
                        .match(trip_node)
                        .delete(trip_node)
                        .with(bike_node, trip_node)
                        .match(user_node)
                        .with(bike_node, user_node)
                        .returning(bike_node, user_node)
                        .build

      expect(renderer.render(statement)).to eq(
        'MATCH (u:`User`)-[:`OWNS`]->(b:`Bike`) MATCH (t:`Trip`) DELETE t WITH b, t MATCH (u:`User`) WITH b, u RETURN b, u'
      )
    end
  end
end
