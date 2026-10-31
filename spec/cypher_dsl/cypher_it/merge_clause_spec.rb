# frozen_string_literal: true

# Translated from CypherIT.java, nested class MergeClause.
module CypherDSL
  RSpec.describe 'CypherIT / MergeClause' do
    let(:bike_node) { Cypher.node('Bike').named(:b) }
    let(:user_node) { Cypher.node('User').named(:u) }
    let(:renderer) { Renderer.default }

    it 'renders merge without return' do
      statement = Cypher.merge(user_node).build

      expect(renderer.render(statement)).to eq('MERGE (u:`User`)')

      statement = Cypher.merge(user_node.relationship_to(bike_node, 'OWNS').named(:o)).build

      expect(renderer.render(statement)).to eq('MERGE (u:`User`)-[o:`OWNS`]->(b:`Bike`)')
    end

    it 'renders merge based on pattern expression collection without return' do # GH-189
      statement = Cypher.merge([user_node]).build

      expect(renderer.render(statement)).to eq('MERGE (u:`User`)')

      statement = Cypher.merge(user_node.relationship_to(bike_node, 'OWNS').named(:o)).build

      expect(renderer.render(statement)).to eq('MERGE (u:`User`)-[o:`OWNS`]->(b:`Bike`)')
    end

    it 'renders multiple merges without return' do
      statement = Cypher.merge(user_node).merge(bike_node).build

      expect(renderer.render(statement)).to eq('MERGE (u:`User`) MERGE (b:`Bike`)')

      statement = Cypher.merge(user_node.relationship_to(bike_node, 'OWNS').named(:o))
                        .merge(Cypher.node('Other'))
                        .build

      expect(renderer.render(statement)).to eq('MERGE (u:`User`)-[o:`OWNS`]->(b:`Bike`) MERGE (:`Other`)')
    end

    it 'renders merge return' do
      statement = Cypher.merge(user_node).returning(user_node).build

      expect(renderer.render(statement)).to eq('MERGE (u:`User`) RETURN u')

      r = user_node.relationship_to(bike_node, 'OWNS').named(:o)
      statement = Cypher.merge(r).returning(user_node, r).build

      expect(renderer.render(statement)).to eq('MERGE (u:`User`)-[o:`OWNS`]->(b:`Bike`) RETURN u, o')

      statement = Cypher.merge(user_node)
                        .returning(user_node)
                        .order_by(user_node.property(:name))
                        .skip(23)
                        .limit(42)
                        .build

      expect(renderer.render(statement)).to eq('MERGE (u:`User`) RETURN u ORDER BY u.name SKIP 23 LIMIT 42')
    end

    it 'renders multiple merges return' do
      statement = Cypher.merge(user_node).merge(bike_node).returning(user_node).build

      expect(renderer.render(statement)).to eq('MERGE (u:`User`) MERGE (b:`Bike`) RETURN u')

      r = user_node.relationship_to(bike_node, 'OWNS').named(:o)
      statement = Cypher.merge(user_node.relationship_to(bike_node, 'OWNS').named(:o))
                        .merge(Cypher.node('Other'))
                        .returning(user_node, r)
                        .build

      expect(renderer.render(statement)).to eq('MERGE (u:`User`)-[o:`OWNS`]->(b:`Bike`) MERGE (:`Other`) RETURN u, o')
    end

    it 'renders merge with with' do
      statement = Cypher.merge(user_node).with(user_node).returning(user_node).build

      expect(renderer.render(statement)).to eq('MERGE (u:`User`) WITH u RETURN u')

      statement = Cypher.merge(user_node)
                        .with(user_node)
                        .set(user_node.property(:x).to(Cypher.literal_of('y')))
                        .build

      expect(renderer.render(statement)).to eq("MERGE (u:`User`) WITH u SET u.x = 'y'")
    end

    it 'match should expose merge' do
      statement = Cypher.match(user_node).merge(user_node.relationship_to(bike_node, 'OWNS').named(:o)).build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) MERGE (u)-[o:`OWNS`]->(b:`Bike`)')
    end

    it 'with should expose merge' do
      statement = Cypher.match(user_node)
                        .with_distinct(user_node)
                        .merge(user_node.relationship_to(bike_node, 'OWNS').named(:o))
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) WITH DISTINCT u MERGE (u)-[o:`OWNS`]->(b:`Bike`)')
    end

    it 'mixed create and merge' do
      trip_node = Cypher.node('Trip').named(:t)

      statement = Cypher.create(user_node)
                        .merge(user_node.relationship_to(bike_node, 'OWNS').named(:o))
                        .with_distinct(bike_node)
                        .merge(trip_node.relationship_from(bike_node, 'USED_ON'))
                        .returning(Cypher.asterisk)
                        .build

      expect(renderer.render(statement)).to eq(
        'CREATE (u:`User`) MERGE (u)-[o:`OWNS`]->(b:`Bike`) WITH DISTINCT b MERGE (t:`Trip`)<-[:`USED_ON`]-(b) RETURN *'
      )
    end

    it 'single create action' do # GH-104
      hallo_welt_string = Cypher.literal_of('Hallo, Welt')
      [
        Cypher.merge(user_node).on_create.set(user_node.property(:p).to(hallo_welt_string)).build,
        Cypher.merge(user_node).on_create.set(user_node.property(:p), hallo_welt_string).build
      ].each do |statement|
        expect(renderer.render(statement)).to eq("MERGE (u:`User`) ON CREATE SET u.p = 'Hallo, Welt'")
      end
    end

    it 'single match action' do # GH-104
      hallo_welt_string = Cypher.literal_of('Hallo, Welt')
      [
        Cypher.merge(user_node).on_match.set(user_node.property(:p).to(hallo_welt_string)).build,
        Cypher.merge(user_node).on_match.set(user_node.property(:p), hallo_welt_string).build
      ].each do |statement|
        expect(renderer.render(statement)).to eq("MERGE (u:`User`) ON MATCH SET u.p = 'Hallo, Welt'")
      end
    end

    it 'stuff than single match action' do
      statement = Cypher.create(bike_node)
                        .set(bike_node.property(:nice).to(Cypher.literal_true))
                        .merge(user_node)
                        .on_match
                        .set(user_node.property(:happy).to(Cypher.literal_true))
                        .create(user_node.relationship_to(bike_node, 'OWNS'))
                        .build
      expect(renderer.render(statement)).to eq(
        'CREATE (b:`Bike`) SET b.nice = true MERGE (u:`User`) ON MATCH SET u.happy = true CREATE (u)-[:`OWNS`]->(b)'
      )
    end

    it 'single action multiple properties' do
      [
        Cypher.merge(user_node)
              .on_match
              .set(user_node.property(:p1).to(Cypher.literal_of('v1')),
                   user_node.property(:p2).to(Cypher.literal_of('v2')))
              .build,
        Cypher.merge(user_node)
              .on_create
              .set(user_node.property(:p1).to(Cypher.literal_of('v1')),
                   user_node.property(:p2).to(Cypher.literal_of('v2')))
              .build
      ].each do |statement|
        expect(renderer.render(statement)).to match(/\AMERGE \(u:`User`\) ON (CREATE|MATCH) SET u\.p1 = 'v1', u\.p2 = 'v2'\z/)
      end
    end

    it 'multiple action multiple properties' do
      statement = Cypher.merge(user_node)
                        .on_match
                        .set(user_node.property(:p1).to(Cypher.literal_of('v1')),
                             user_node.property(:p2).to(Cypher.literal_of('v2')))
                        .on_create
                        .set(user_node.property(:p3).to(Cypher.literal_of('v3')),
                             user_node.property(:p4).to(Cypher.literal_of('v4')))
                        .build
      expect(renderer.render(statement)).to eq(
        "MERGE (u:`User`) ON MATCH SET u.p1 = 'v1', u.p2 = 'v2' ON CREATE SET u.p3 = 'v3', u.p4 = 'v4'"
      )
    end

    it 'single create than match action' do # GH-104
      statement = Cypher.merge(user_node)
                        .on_create
                        .set(user_node.property(:p).to(Cypher.literal_of('Hello, World')))
                        .on_match
                        .set(user_node.property(:p).to(Cypher.literal_of('Hallo, Welt')))
                        .build
      expect(renderer.render(statement))
        .to eq("MERGE (u:`User`) ON CREATE SET u.p = 'Hello, World' ON MATCH SET u.p = 'Hallo, Welt'")
    end

    it 'single match than create action' do # GH-104
      statement = Cypher.merge(user_node)
                        .on_match
                        .set(user_node.property(:p).to(Cypher.literal_of('Hallo, Welt')))
                        .on_create
                        .set(user_node.property(:p).to(Cypher.literal_of('Hello, World')))
                        .build
      expect(renderer.render(statement))
        .to eq("MERGE (u:`User`) ON MATCH SET u.p = 'Hallo, Welt' ON CREATE SET u.p = 'Hello, World'")
    end

    it 'multiple matches and creates' do # GH-104
      statement = Cypher.merge(user_node)
                        .on_match
                        .set(user_node.property(:p1).to(Cypher.literal_of('v1')))
                        .on_create
                        .set(user_node.property(:p2).to(Cypher.literal_of('v2')))
                        .on_create
                        .set(user_node.property(:p3).to(Cypher.literal_of('v3')))
                        .on_match
                        .set(user_node.property(:p4).to(Cypher.literal_of('v4')))
                        .build
      expect(renderer.render(statement)).to eq(
        "MERGE (u:`User`) ON MATCH SET u.p1 = 'v1' ON CREATE SET u.p2 = 'v2' ON CREATE SET u.p3 = 'v3' ON MATCH SET u.p4 = 'v4'"
      )
    end

    it 'action than set' do # GH-104
      statement = Cypher.merge(user_node)
                        .on_match
                        .set(user_node.property(:p1).to(Cypher.literal_of('v1')))
                        .set(user_node.property(:p2).to(Cypher.literal_of('v2')))
                        .returning(user_node)
                        .build
      expect(renderer.render(statement)).to eq("MERGE (u:`User`) ON MATCH SET u.p1 = 'v1' SET u.p2 = 'v2' RETURN u")
    end

    it 'action than continue' do # GH-104
      statement = Cypher.merge(user_node)
                        .on_match
                        .set(user_node.property(:p1).to(Cypher.literal_of('v1')))
                        .with(user_node)
                        .returning(user_node)
                        .build
      expect(renderer.render(statement)).to eq("MERGE (u:`User`) ON MATCH SET u.p1 = 'v1' WITH u RETURN u")
    end

    it 'merge should expose remove labels' do # GH-750
      n = Cypher.node('LABEL1').named(:n)
      statement = Cypher.merge(n).remove(n, 'OLD_LABEL').set(n, 'NEW_LABEL').build
      expect(renderer.render(statement)).to eq('MERGE (n:`LABEL1`) REMOVE n:`OLD_LABEL` SET n:`NEW_LABEL`')
    end

    it 'merge should expose remove properties' do # GH-750
      n = Cypher.node('LABEL1').named(:n)
      statement = Cypher.merge(n).remove(n.property(:x)).build
      expect(renderer.render(statement)).to eq('MERGE (n:`LABEL1`) REMOVE n.x')
    end

    it 'merge should expose set labels' do # GH-750
      n = Cypher.node('LABEL1').named(:n)
      statement = Cypher.merge(n).set(n, 'NEW_LABEL').build
      expect(renderer.render(statement)).to eq('MERGE (n:`LABEL1`) SET n:`NEW_LABEL`')
    end

    it 'merge should expose set properties' do # GH-750
      n = Cypher.node('LABEL1').named(:n)
      statement = Cypher.merge(n).set(n.property(:x), Cypher.literal_of('y')).build
      expect(renderer.render(statement)).to eq("MERGE (n:`LABEL1`) SET n.x = 'y'")
    end

    it 'merge should expose set labels after action' do # GH-750
      n = Cypher.node('LABEL1').named(:n)
      statement = Cypher.merge(n).on_match.set(n, 'NEW_LABEL').build
      expect(renderer.render(statement)).to eq('MERGE (n:`LABEL1`) ON MATCH SET n:`NEW_LABEL`')
    end

    it 'merge should expose set multiple labels after action' do # GH-750
      n = Cypher.node('LABEL1').named(:n)
      statement = Cypher.merge(n).on_match.set(n, %w[A B]).build
      expect(renderer.render(statement)).to eq('MERGE (n:`LABEL1`) ON MATCH SET n:`A`:`B`')
    end

    it 'merge should expose set properties after action' do # GH-750
      n = Cypher.node('LABEL1').named(:n)
      statement = Cypher.merge(n).on_match.set(n.property(:x), Cypher.literal_of('y')).build
      expect(renderer.render(statement)).to eq("MERGE (n:`LABEL1`) ON MATCH SET n.x = 'y'")
    end
  end
end
