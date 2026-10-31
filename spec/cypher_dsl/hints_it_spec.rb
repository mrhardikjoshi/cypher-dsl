# frozen_string_literal: true

# Translated from HintsIT.java.
#
# Adapted: Java distinguishes IllegalArgumentException from IllegalStateException; both are
# ArgumentError here. `joinRequiresNodeName` and `joinRequiresSymbolicName` pass empty arrays of
# different static types; Ruby has one `using_join_on()` call and one message.
module CypherDSL
  RSpec.describe 'HintsIT' do
    let(:cypher_renderer) { Renderer.default }

    let(:liskov) { Cypher.node('Scientist').named(:liskov).with_properties('name', Cypher.literal_of('Liskov')) }
    let(:wing) { Cypher.node('Scientist').named(:wing) }
    let(:conway) { Cypher.node('Scientist').named(:conway).with_properties('name', Cypher.literal_of('Conway')) }
    let(:cs) { Cypher.node('Science').named(:cs).with_properties('name', Cypher.literal_of('Computer Science')) }

    let(:scientists) do
      liskov.relationship_to(wing, 'KNOWS').relationship_to(cs, 'RESEARCHED').relationship_from(conway, 'RESEARCHED')
    end
    let(:scientists_pattern) do
      "MATCH (liskov:`Scientist` {name: 'Liskov'})-[:`KNOWS`]->(wing:`Scientist`)-[:`RESEARCHED`]->(cs:`Science` {name: 'Computer Science'})<-[:`RESEARCHED`]-(conway:`Scientist` {name: 'Conway'})"
    end

    describe 'IndexHints' do
      it 'using index should work' do
        statement = Cypher.match(scientists)
                          .using_index(liskov.property(:name))
                          .returning(liskov.property(:born).as(:column))
                          .build

        expect(cypher_renderer.render(statement)).to eq(
          "#{scientists_pattern} USING INDEX liskov:`Scientist`(name) RETURN liskov.born AS column"
        )
      end

      it 'using index seek should work' do
        statement = Cypher.match(scientists)
                          .using_index_seek(liskov.property(:name))
                          .returning(liskov.property(:born).as(:column))
                          .build

        expect(cypher_renderer.render(statement)).to eq(
          "#{scientists_pattern} USING INDEX SEEK liskov:`Scientist`(name) RETURN liskov.born AS column"
        )
      end

      it 'using composite indexes should work' do
        m = Cypher.node('Method').named(:m).with_properties('name', Cypher.literal_of('Foo'), 'type', Cypher.literal_of('Bar'))
        statement = Cypher.match(m)
                          .using_index(m.property(:name), m.property(:type))
                          .returning(m)
                          .build

        expect(cypher_renderer.render(statement)).to eq("MATCH (m:`Method` {name: 'Foo', type: 'Bar'}) USING INDEX m:`Method`(name, type) RETURN m")
      end

      it 'properties of different nodes cannot be used on the same hint' do
        m = Cypher.node('Method').named(:m).with_properties('name', Cypher.literal_of('Foo'), 'type', Cypher.literal_of('Bar'))

        expect { Cypher.match(m).using_index(m.property(:name), Cypher.node('Method').named(:x).property(:type)).returning(m).build }
          .to raise_error(ArgumentError, 'If you want to use more than one index on different nodes you must use multiple `USING INDEX` statements.')
      end

      it 'nested properties are not allowed' do
        m = Cypher.node('Method').named(:m).with_properties('name', Cypher.literal_of('Foo'), 'type', Cypher.literal_of('Bar'))

        expect { Cypher.match(m).using_index(m.property(:a, :name)).returning(m).build }
          .to raise_error(ArgumentError, 'One single property is required. Nested properties are not supported.')
      end

      it 'multiple labels are not allowed' do
        m = Cypher.node('Method', 'Foo').named(:m).with_properties('name', Cypher.literal_of('Foo'), 'type', Cypher.literal_of('Bar'))

        expect { Cypher.match(m).using_index(m.property(:name)).returning(m).build }
          .to raise_error(ArgumentError, 'Exactly one label is required to define the index.')
      end

      it 'properties must reference a node' do
        m = Cypher.node('Method').named(:m).with_properties('name', Cypher.literal_of('Foo'), 'type', Cypher.literal_of('Bar'))

        expect { Cypher.match(m).using_index(Cypher.property(:m, :name)).returning(m).build }
          .to raise_error(ArgumentError, 'Cannot use a property without a reference to a container inside an index hint.')
      end

      it 'indexes on relationships should work' do
        m = Cypher.node('Method').named(:m).with_properties('name', Cypher.literal_of('Foo'), 'type', Cypher.literal_of('Bar'))

        r = m.relationship_to(Cypher.node('Method'), 'CALLS').named(:r).with_properties('whatever', Cypher.literal_true)

        statement = Cypher.match(r).using_index(r.property(:whatever)).returning(m).build

        expect(cypher_renderer.render(statement)).to eq(
          "MATCH (m:`Method` {name: 'Foo', type: 'Bar'})-[r:`CALLS` {whatever: true}]->(:`Method`) USING INDEX r:`CALLS`(whatever) RETURN m"
        )
      end

      it 'multiple indizes should work' do
        statement = Cypher.match(scientists)
                          .using_index(liskov.property(:name))
                          .using_index(conway.property(:name))
                          .returning(liskov.property(:born).as(:column))
                          .build

        expect(cypher_renderer.render(statement)).to eq(
          "#{scientists_pattern} USING INDEX liskov:`Scientist`(name) USING INDEX conway:`Scientist`(name) RETURN liskov.born AS column"
        )
      end
    end

    describe 'ScanHints' do
      it 'using scan hints should work' do
        s = Cypher.node('Scientist').named(:s)
        statement = Cypher.match(s)
                          .using_scan(s)
                          .where(s.property(:born).lt(Cypher.literal_of(1939)))
                          .returning(s.property(:born).as(:column))
                          .build

        expect(cypher_renderer.render(statement)).to eq('MATCH (s:`Scientist`) USING SCAN s:`Scientist` WHERE s.born < 1939 RETURN s.born AS column')
      end

      it 'scans can not be used with multiple labels' do
        expect { Cypher.match(Cypher.node('Scientist').named(:s)).using_scan(Cypher.node('Scientist', 'Other').named(:s)).returning(SymbolicName.of(:s)).build }
          .to raise_error(ArgumentError, 'Exactly one label is required for a SCAN hint.')
      end

      it 'scans can not be used without labels' do
        expect { Cypher.match(Cypher.node('Scientist').named(:s)).using_scan(Cypher.any_node).returning(SymbolicName.of(:s)).build }
          .to raise_error(ArgumentError, 'Exactly one label is required for a SCAN hint.')
      end

      it 'scans need a node' do
        expect { Cypher.match(Cypher.node('Scientist').named(:s)).using_scan(nil).returning(SymbolicName.of(:s)).build }
          .to raise_error(ArgumentError, 'Cannot apply a SCAN hint without a node.')
      end
    end

    describe 'JoinHints' do
      it 'single join hint should work' do
        statement = Cypher.match(scientists)
                          .using_index(liskov.property(:name))
                          .using_index(conway.property(:name))
                          .using_join_on(wing)
                          .returning(liskov.property(:born).as(:column))
                          .build

        expect(cypher_renderer.render(statement)).to eq(
          "#{scientists_pattern} USING INDEX liskov:`Scientist`(name) USING INDEX conway:`Scientist`(name) USING JOIN ON wing RETURN liskov.born AS column"
        )
      end

      it 'multiple join hint should work' do
        statement = Cypher.match(liskov.relationship_to(Cypher.node('Scientist').named(:wing).with_properties('name', Cypher.literal_of('Wing')), 'KNOWS')
                                      .relationship_to(cs, 'RESEARCHED')
                                      .relationship_from(liskov, 'RESEARCHED'))
                          .using_index(liskov.property(:name))
                          .using_join_on(liskov, cs)
                          .returning(wing.property(:born).as(:column))
                          .build

        expect(cypher_renderer.render(statement)).to eq(
          "MATCH (liskov:`Scientist` {name: 'Liskov'})-[:`KNOWS`]->(wing:`Scientist` {name: 'Wing'})-[:`RESEARCHED`]->(cs:`Science` {name: 'Computer Science'})<-[:`RESEARCHED`]-(liskov) " \
          'USING INDEX liskov:`Scientist`(name) USING JOIN ON liskov, cs RETURN wing.born AS column'
        )
      end

      it 'join without other indexes should work' do
        statement = Cypher.match(scientists)
                          .using_join_on(wing)
                          .returning(liskov.property(:born).as(:column))
                          .build

        expect(cypher_renderer.render(statement)).to eq("#{scientists_pattern} USING JOIN ON wing RETURN liskov.born AS column")
      end

      it 'join requires node name' do
        expect { Cypher.match(scientists).using_join_on.returning(liskov.property(:born).as(:column)).build }
          .to raise_error(ArgumentError, 'At least one node is required to define a JOIN hint.')
      end

      it 'join requires symbolic name' do
        expect { Cypher.match(scientists).using_join_on([]).returning(liskov.property(:born).as(:column)).build }
          .to raise_error(ArgumentError, 'At least one node is required to define a JOIN hint.')
      end
    end
  end
end
