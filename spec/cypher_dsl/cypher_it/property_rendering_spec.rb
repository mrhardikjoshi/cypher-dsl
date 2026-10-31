# frozen_string_literal: true

# Translated from CypherIT.java, nested class PropertyRendering.
module CypherDSL
  RSpec.describe 'CypherIT / PropertyRendering' do
    let(:bike_node) { Cypher.node('Bike').named(:b) }
    let(:user_node) { Cypher.node('User').named(:u) }
    let(:renderer) { Renderer.default }

    it 'using existing java maps' do # GH-157
      new_properties = { 'prop1' => 23, 'theTruth' => 42, 'somethingElse' => 'foobar',
                         'aParam' => Cypher.parameter(:x).with_value('y') }
      node = Cypher.node('ANode').named(:n).with_properties(new_properties)

      expect(Cypher.match(node).returning(node).build.cypher)
        .to eq("MATCH (n:`ANode` {prop1: 23, theTruth: 42, somethingElse: 'foobar', aParam: $x}) RETURN n")
    end

    it 'manually nested' do # GH-114
      node = Cypher.node('Person').named(:p)

      location_property = node.property(:location)
      statement = Cypher.match(node)
                        .where(Cypher.property(location_property, :x).gt(Cypher.literal_of(6)))
                        .returning(node)
                        .build

      expect(renderer.render(statement)).to eq('MATCH (p:`Person`) WHERE p.location.x > 6 RETURN p')
    end

    it 'chained' do # GH-114
      node = Cypher.node('Person').named(:p)

      statement = Cypher.match(node)
                        .where(node.property(:location, :x).gt(Cypher.literal_of(6)))
                        .returning(node)
                        .build

      expect(renderer.render(statement)).to eq('MATCH (p:`Person`) WHERE p.location.x > 6 RETURN p')
    end

    it 'chained and fancy' do # GH-114
      node = Cypher.node('Person').named(:p)

      point = Cypher.point(Cypher.map_of('latitude', Cypher.literal_of(50.751), 'longitude', Cypher.literal_of(6.179)))
      statement = Cypher.create(node.with_properties(Cypher.map_of('home.location', point)))
                        .returning(node)
                        .build

      expect(renderer.render(statement))
        .to eq('CREATE (p:`Person` {`home.location`: point({latitude: 50.751, longitude: 6.179})}) RETURN p')

      statement = Cypher.match(node)
                        .where(node.property('home.location', :y).gt(Cypher.literal_of(50)))
                        .returning(node)
                        .build

      expect(renderer.render(statement)).to eq('MATCH (p:`Person`) WHERE p.`home.location`.y > 50 RETURN p')
    end

    it 'explicitly defined' do # GH-123
      node = Cypher.node('Person').named(:p)

      ly1 = Cypher.property(node.required_symbolic_name, 'home.location', :y)
      ly2 = Cypher.property(:p, 'home.location', :y)

      statement = Cypher.match(node).where(ly1.gt(Cypher.literal_of(50))).returning(ly2).build

      expect(renderer.render(statement))
        .to eq('MATCH (p:`Person`) WHERE p.`home.location`.y > 50 RETURN p.`home.location`.y')
    end

    it 'chained in projection' do
      node = Cypher.node('Person').named(:p)
      expect do
        Cypher.match(node)
              .returning(node.project('__internalNeo4jId__', Cypher.element_id(node), 'name')
                             .and(node.property('home.location', :y)))
              .build
      end.to raise_error(ArgumentError, 'Cannot project nested properties!')
    end

    it 'renders node properties' do
      [
        Cypher.node('Test', Cypher.map_of('a', Cypher.literal_of('b'))),
        Cypher.node('Test').with_properties(Cypher.map_of('a', Cypher.literal_of('b'))),
        Cypher.node('Test').with_properties('a', Cypher.literal_of('b'))
      ].each do |node_with_properties|
        statement = Cypher.match(node_with_properties).returning(Cypher.asterisk).build

        expect(renderer.render(statement)).to eq("MATCH (:`Test` {a: 'b'}) RETURN *")

        statement = Cypher.merge(node_with_properties).returning(Cypher.asterisk).build

        expect(renderer.render(statement)).to eq("MERGE (:`Test` {a: 'b'}) RETURN *")
      end
    end

    it 'nested properties' do
      node_with_properties = Cypher.node('Test').with_properties('outer', Cypher.map_of('a', Cypher.literal_of('b')))

      statement = Cypher.match(node_with_properties).returning(Cypher.asterisk).build

      expect(renderer.render(statement)).to eq("MATCH (:`Test` {outer: {a: 'b'}}) RETURN *")
    end

    it 'does not render properties in return' do
      node_with_properties = bike_node.with_properties('a', Cypher.literal_of('b'))

      statement = Cypher.match(node_with_properties, node_with_properties.relationship_from(user_node, 'OWNS'))
                        .returning(node_with_properties)
                        .build

      expect(renderer.render(statement)).to eq("MATCH (b:`Bike` {a: 'b'}), (b)<-[:`OWNS`]-(u:`User`) RETURN b")
    end

    it 'dynamic property lookups on nodes' do # GH-127
      m = Cypher.node('Movie').named(:m)

      statement = Cypher.match(m).returning(m.property(Cypher.literal_of('title'))).build
      expect(renderer.render(statement)).to eq("MATCH (m:`Movie`) RETURN m['title']")

      statement = Cypher.match(m).returning(m.property(Cypher.parameter(:prop))).build
      expect(renderer.render(statement)).to eq('MATCH (m:`Movie`) RETURN m[$prop]')
    end

    it 'dynamic property lookups on relationships' do # GH-127
      m = Cypher.node('Movie').named(:m)
      r = m.relationship_from(Cypher.any_node, 'ACTED_IN').named(:r)

      statement = Cypher.match(r).returning(r.property(Cypher.literal_of('roles'))).build
      expect(renderer.render(statement)).to eq("MATCH (m:`Movie`)<-[r:`ACTED_IN`]-() RETURN r['roles']")

      statement = Cypher.match(r).returning(r.property(Cypher.parameter(:prop))).build
      expect(renderer.render(statement)).to eq('MATCH (m:`Movie`)<-[r:`ACTED_IN`]-() RETURN r[$prop]')
    end

    it 'arbitrary dynamic lookups' do # GH-127
      m = Cypher.node('Movie').named(:m)

      statement = Cypher.match(m).returning(Cypher.property(:m, Cypher.literal_of('title'))).build
      expect(renderer.render(statement)).to eq("MATCH (m:`Movie`) RETURN m['title']")

      statement = Cypher.match(m)
                        .returning(Cypher.property(SymbolicName.of('m'), Cypher.literal_of('title')))
                        .build
      expect(renderer.render(statement)).to eq("MATCH (m:`Movie`) RETURN m['title']")

      statement = Cypher.with(Cypher.map_of('a', Cypher.literal_of('X'), 'b', Cypher.literal_of('Y')).as(:m))
                        .returning(Cypher.property(:m, Cypher.literal_of('a')), Cypher.property(:m, :a))
                        .build
      expect(renderer.render(statement)).to eq("WITH {a: 'X', b: 'Y'} AS m RETURN m['a'], m.a")
    end

    it 'indexed properties' do
      alias_name = SymbolicName.of('line')
      statement = Cypher.returning(Cypher.value_at(alias_name, 1)).build
      expect(statement.cypher).to eq('RETURN line[1]')
    end
  end
end
