# frozen_string_literal: true

# Translated from CypherIT.java, nested class Conditions (including PathPatternConditions).
module CypherDSL
  RSpec.describe 'CypherIT / Conditions' do
    let(:user_node) { Cypher.node('User').named(:u) }
    let(:renderer) { Renderer.default }

    it 'conditions chaining and' do
      statement = Cypher.match(user_node)
                        .where(user_node.property(:name)
                                        .is_equal_to(Cypher.literal_of('Test'))
                                        .and(user_node.property(:age).is_equal_to(Cypher.literal_of(21))))
                        .returning(user_node)
                        .build

      expect(renderer.render(statement)).to eq("MATCH (u:`User`) WHERE (u.name = 'Test' AND u.age = 21) RETURN u")
    end

    it 'conditions chaining or' do
      statement = Cypher.match(user_node)
                        .where(user_node.property(:name)
                                        .is_equal_to(Cypher.literal_of('Test'))
                                        .or(user_node.property(:age).is_equal_to(Cypher.literal_of(21))))
                        .returning(user_node)
                        .build

      expect(renderer.render(statement)).to eq("MATCH (u:`User`) WHERE (u.name = 'Test' OR u.age = 21) RETURN u")
    end

    it 'includes all should work' do
      node = Cypher.any_node.named(:n)
      statement = Cypher.match(node)
                        .where(Cypher.includes_all(node.property(:l), Cypher.literal_of(%w[A B])))
                        .returning(node)
                        .build

      statement2 = Cypher.match(node)
                         .where(node.property(:l).includes_all(Cypher.literal_of(%w[A B])))
                         .returning(node)
                         .build

      expect(statement.cypher).to eq("MATCH (n) WHERE all(x IN ['A', 'B'] WHERE x IN n.l) RETURN n")
      expect(statement2.cypher).to eq(statement.cypher)
    end

    it 'includes any should work' do
      node = Cypher.any_node.named(:n)
      statement = Cypher.match(node)
                        .where(Cypher.includes_any(node.property(:l), Cypher.literal_of(%w[A B])))
                        .returning(node)
                        .build

      statement2 = Cypher.match(node)
                         .where(node.property(:l).includes_any(Cypher.literal_of(%w[A B])))
                         .returning(node)
                         .build

      expect(statement.cypher).to eq("MATCH (n) WHERE any(x IN ['A', 'B'] WHERE x IN n.l) RETURN n")
      expect(statement2.cypher).to eq(statement.cypher)
    end

    it 'nested conditions' do
      is_true = Cypher.is_true
      is_false = Cypher.is_false
      statement = Cypher.match(user_node).where(is_true.or(is_false).and(is_true)).returning(user_node).build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) WHERE ((true OR false) AND true) RETURN u')

      statement = Cypher.match(user_node)
                        .where(is_true.or(is_false).and(is_true))
                        .or(is_false)
                        .returning(user_node)
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) WHERE (((true OR false) AND true) OR false) RETURN u')

      statement = Cypher.match(user_node)
                        .where(is_true.or(is_false).and(is_true))
                        .or(is_false)
                        .and(is_false)
                        .returning(user_node)
                        .build

      expect(renderer.render(statement))
        .to eq('MATCH (u:`User`) WHERE ((((true OR false) AND true) OR false) AND false) RETURN u')

      statement = Cypher.match(user_node)
                        .where(is_true.or(is_false).and(is_true))
                        .or(is_false.and(is_true))
                        .returning(user_node)
                        .build

      expect(renderer.render(statement))
        .to eq('MATCH (u:`User`) WHERE (((true OR false) AND true) OR (false AND true)) RETURN u')

      statement = Cypher.match(user_node)
                        .where(is_true.or(is_false).and(is_true))
                        .or(is_false.and(is_true))
                        .and(is_true)
                        .returning(user_node)
                        .build

      expect(renderer.render(statement))
        .to eq('MATCH (u:`User`) WHERE ((((true OR false) AND true) OR (false AND true)) AND true) RETURN u')

      statement = Cypher.match(user_node)
                        .where(is_true.or(is_false).and(is_true))
                        .or(is_false.or(is_true))
                        .returning(user_node)
                        .build

      expect(renderer.render(statement))
        .to eq('MATCH (u:`User`) WHERE (((true OR false) AND true) OR false OR true) RETURN u')

      statement = Cypher.match(user_node)
                        .where(is_true.or(is_false).and(is_true).or(is_false.or(is_true)))
                        .returning(user_node)
                        .build

      expect(renderer.render(statement))
        .to eq('MATCH (u:`User`) WHERE (((true OR false) AND true) OR false OR true) RETURN u')

      statement = Cypher.match(user_node)
                        .where(is_true.or(is_true).or(is_true))
                        .or(is_false.or(is_false).or(is_false))
                        .or(is_true)
                        .or(is_true)
                        .or(is_true)
                        .returning(user_node)
                        .build

      expect(renderer.render(statement)).to eq(
        'MATCH (u:`User`) WHERE (true OR true OR true OR false OR false OR false OR true OR true OR true) RETURN u'
      )
    end

    it 'conditions chaining xor' do
      statement = Cypher.match(user_node)
                        .where(user_node.property(:name)
                                        .is_equal_to(Cypher.literal_of('Test'))
                                        .xor(user_node.property(:age).is_equal_to(Cypher.literal_of(21))))
                        .returning(user_node)
                        .build

      expect(renderer.render(statement)).to eq("MATCH (u:`User`) WHERE (u.name = 'Test' XOR u.age = 21) RETURN u")
    end

    it 'multiple empty conditions must collapse' do # GH-110
      no = Cypher.no_condition
      expected = 'MATCH (u:`User`) RETURN u'

      statement = Cypher.match(user_node).where(no.or(no)).and(no.and(no).or(no)).returning(user_node).build
      expect(renderer.render(statement)).to eq(expected)

      statement = Cypher.match(user_node).where(no.or(no)).returning(user_node).build
      expect(renderer.render(statement)).to eq(expected)

      statement = Cypher.match(user_node).where(no.and(no).or(no)).returning(user_node).build
      expect(renderer.render(statement)).to eq(expected)
    end

    it 'multiple empty conditions must collapse2' do # GH-110
      no = Cypher.no_condition
      t = -> { user_node.property(:a).is_equal_to(Cypher.literal_true) }
      expected = 'MATCH (u:`User`) WHERE u.a = true RETURN u'

      statement = Cypher.match(user_node)
                        .where(no.and(t.call).or(no))
                        .and(no.and(no).or(no))
                        .returning(user_node)
                        .build
      expect(renderer.render(statement)).to eq(expected)

      statement = Cypher.match(user_node).where(no.or(no).or(t.call)).returning(user_node).build
      expect(renderer.render(statement)).to eq(expected)

      statement = Cypher.match(user_node).where(no.and(t.call).or(no)).returning(user_node).build
      expect(renderer.render(statement)).to eq(expected)

      statement = Cypher.match(user_node).where(no.or(no)).and(t.call).returning(user_node).build
      expect(renderer.render(statement)).to eq(expected)
    end

    it 'multiple empty conditions must collapse3' do # GH-110
      no = Cypher.no_condition
      t = -> { user_node.property(:a).is_equal_to(Cypher.literal_true) }
      f = -> { user_node.property(:b).is_equal_to(Cypher.literal_false) }
      expected = 'MATCH (u:`User`) WHERE (u.a = true AND u.b = false) RETURN u'

      statement = Cypher.match(user_node)
                        .where(no.and(t.call).or(no))
                        .and(no.and(f.call).or(no))
                        .returning(user_node)
                        .build
      expect(renderer.render(statement)).to eq(expected)

      statement = Cypher.match(user_node).where(no.or(no).or(t.call).and(f.call)).returning(user_node).build
      expect(renderer.render(statement)).to eq(expected)

      statement = Cypher.match(user_node)
                        .where(no.and(t.call).or(no))
                        .and(f.call.or(no))
                        .returning(user_node)
                        .build
      expect(renderer.render(statement)).to eq(expected)
    end

    it 'chaining on where' do
      test = Cypher.literal_of('Test')
      foobar = Cypher.literal_of('foobar')
      name = -> { user_node.property(:name) }

      statement = Cypher.match(user_node)
                        .where(name.call.is_equal_to(test))
                        .returning(user_node)
                        .build

      expect(renderer.render(statement)).to eq("MATCH (u:`User`) WHERE u.name = 'Test' RETURN u")

      statement = Cypher.match(user_node)
                        .where(name.call.is_equal_to(test))
                        .and(name.call.is_equal_to(test))
                        .returning(user_node)
                        .build

      expect(renderer.render(statement)).to eq("MATCH (u:`User`) WHERE (u.name = 'Test' AND u.name = 'Test') RETURN u")

      statement = Cypher.match(user_node)
                        .where(name.call.is_equal_to(test))
                        .and(name.call.is_equal_to(test))
                        .and(name.call.is_equal_to(test))
                        .returning(user_node)
                        .build

      expect(renderer.render(statement))
        .to eq("MATCH (u:`User`) WHERE (u.name = 'Test' AND u.name = 'Test' AND u.name = 'Test') RETURN u")

      statement = Cypher.match(user_node)
                        .where(name.call.is_equal_to(test))
                        .or(name.call.is_equal_to(test))
                        .returning(user_node)
                        .build

      expect(renderer.render(statement)).to eq("MATCH (u:`User`) WHERE (u.name = 'Test' OR u.name = 'Test') RETURN u")

      statement = Cypher.match(user_node)
                        .where(name.call.is_equal_to(test))
                        .or(name.call.is_equal_to(test))
                        .or(name.call.is_equal_to(test))
                        .returning(user_node)
                        .build

      expect(renderer.render(statement))
        .to eq("MATCH (u:`User`) WHERE (u.name = 'Test' OR u.name = 'Test' OR u.name = 'Test') RETURN u")

      statement = Cypher.match(user_node)
                        .where(name.call.is_equal_to(test))
                        .and(name.call.is_equal_to(test))
                        .or(name.call.is_equal_to(foobar))
                        .and(name.call.is_equal_to(test))
                        .returning(user_node)
                        .build

      expect(renderer.render(statement)).to eq(
        "MATCH (u:`User`) WHERE (((u.name = 'Test' AND u.name = 'Test') OR u.name = 'foobar') AND u.name = 'Test') RETURN u"
      )

      statement = Cypher.match(user_node)
                        .where(name.call.is_equal_to(test))
                        .or(name.call.is_equal_to(foobar))
                        .and(name.call.is_equal_to(test))
                        .and(name.call.is_equal_to(test))
                        .returning(user_node)
                        .build

      expect(renderer.render(statement)).to eq(
        "MATCH (u:`User`) WHERE ((u.name = 'Test' OR u.name = 'foobar') AND u.name = 'Test' AND u.name = 'Test') RETURN u"
      )

      statement = Cypher.match(user_node)
                        .where(name.call.is_equal_to(test))
                        .or(name.call.is_equal_to(foobar))
                        .and(name.call.is_equal_to(test))
                        .or(name.call.is_equal_to(foobar))
                        .and(name.call.is_equal_to(test))
                        .returning(user_node)
                        .build

      expect(renderer.render(statement)).to eq(
        "MATCH (u:`User`) WHERE ((((u.name = 'Test' OR u.name = 'foobar') AND u.name = 'Test') OR u.name = 'foobar') AND u.name = 'Test') RETURN u"
      )

      statement = Cypher.match(user_node)
                        .where(name.call.is_not_null)
                        .and(name.call.is_equal_to(test))
                        .or(user_node.property(:age).is_equal_to(Cypher.literal_of(21)))
                        .returning(user_node)
                        .build

      expect(renderer.render(statement))
        .to eq("MATCH (u:`User`) WHERE ((u.name IS NOT NULL AND u.name = 'Test') OR u.age = 21) RETURN u")
    end

    it 'chaining on conditions' do
      test = Cypher.literal_of('Test')
      foobar = Cypher.literal_of('foobar')
      bazbar = Cypher.literal_of('bazbar')
      name = -> { user_node.property(:name) }

      statement = Cypher.match(user_node)
                        .where(name.call
                                   .is_equal_to(test)
                                   .or(name.call.is_equal_to(foobar))
                                   .or(name.call.is_equal_to(foobar)))
                        .returning(user_node)
                        .build

      expect(renderer.render(statement)).to eq(
        "MATCH (u:`User`) WHERE (u.name = 'Test' OR u.name = 'foobar' OR u.name = 'foobar') RETURN u"
      )

      statement = Cypher.match(user_node)
                        .where(name.call
                                   .is_equal_to(test)
                                   .and(name.call.is_equal_to(bazbar))
                                   .or(name.call.is_equal_to(foobar))
                                   .or(name.call.is_equal_to(foobar)))
                        .returning(user_node)
                        .build

      expect(renderer.render(statement)).to eq(
        "MATCH (u:`User`) WHERE ((u.name = 'Test' AND u.name = 'bazbar') OR u.name = 'foobar' OR u.name = 'foobar') RETURN u"
      )

      statement = Cypher.match(user_node)
                        .where(name.call.is_equal_to(test))
                        .and(name.call.is_equal_to(bazbar).and(name.call.is_equal_to(foobar)))
                        .returning(user_node)
                        .build

      expect(renderer.render(statement)).to eq(
        "MATCH (u:`User`) WHERE (u.name = 'Test' AND u.name = 'bazbar' AND u.name = 'foobar') RETURN u"
      )

      statement = Cypher.match(user_node)
                        .where(name.call
                                   .is_equal_to(test)
                                   .and(name.call.is_equal_to(bazbar))
                                   .or(name.call.is_equal_to(foobar))
                                   .or(name.call.is_equal_to(foobar))
                                   .and(name.call.is_equal_to(bazbar)))
                        .returning(user_node)
                        .build
      expect(renderer.render(statement)).to eq(
        "MATCH (u:`User`) WHERE (((u.name = 'Test' AND u.name = 'bazbar') OR u.name = 'foobar' OR u.name = 'foobar') AND u.name = 'bazbar') RETURN u"
      )
    end

    it 'chaining combined' do
      test = Cypher.literal_of('Test')
      foobar = Cypher.literal_of('foobar')
      bazbar = Cypher.literal_of('bazbar')
      name = -> { user_node.property(:name) }

      statement = Cypher.match(user_node)
                        .where(name.call
                                   .is_equal_to(test)
                                   .and(name.call.is_equal_to(bazbar))
                                   .or(name.call.is_equal_to(foobar))
                                   .or(name.call.is_equal_to(foobar)))
                        .and(name.call
                                 .is_equal_to(bazbar)
                                 .and(name.call.is_equal_to(foobar))
                                 .or(name.call.is_equal_to(test))
                                 .not)
                        .returning(user_node)
                        .build

      expect(renderer.render(statement)).to eq(
        "MATCH (u:`User`) WHERE (((u.name = 'Test' AND u.name = 'bazbar') OR u.name = 'foobar' OR u.name = 'foobar') AND NOT (((u.name = 'bazbar' AND u.name = 'foobar') OR u.name = 'Test'))) RETURN u"
      )
    end

    it 'negated conditions' do
      statement = Cypher.match(user_node)
                        .where(user_node.property(:name).is_not_null.not)
                        .returning(user_node)
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) WHERE u.name IS NULL RETURN u')
    end

    it 'no condition should not be rendered' do
      statement = Cypher.match(user_node).where(Cypher.no_condition).returning(user_node).build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) RETURN u')

      statement = Cypher.match(user_node)
                        .where(user_node.property(:name).is_equal_to(Cypher.literal_of('test')))
                        .and(Cypher.no_condition)
                        .or(Cypher.no_condition)
                        .returning(user_node)
                        .build

      expect(renderer.render(statement)).to eq("MATCH (u:`User`) WHERE u.name = 'test' RETURN u")
    end

    it 'grouping bug' do # GH-137
      node = Cypher.node('Person').named(:person)

      statement = Cypher.match(node)
                        .where(Cypher.literal_of('A').is_true.or(Cypher.literal_of('B').is_true))
                        .and(Cypher.literal_of('C').is_true)
                        .returning(node)
                        .build

      expect(renderer.render(statement))
        .to eq("MATCH (person:`Person`) WHERE (('A' = true OR 'B' = true) AND 'C' = true) RETURN person")

      statement = Cypher.match(node)
                        .where(Cypher.literal_of('A').is_true.or(Cypher.literal_of('B').is_true))
                        .and(Cypher.literal_of('C').is_true.or(Cypher.literal_of('D').is_true))
                        .returning(node)
                        .build

      expect(renderer.render(statement)).to eq(
        "MATCH (person:`Person`) WHERE (('A' = true OR 'B' = true) AND ('C' = true OR 'D' = true)) RETURN person"
      )
    end

    it 'in pattern comprehensions' do # GH-244
      a = Cypher.node('Person').with_properties('name', Cypher.literal_of('Keanu Reeves')).named(:a)
      b = Cypher.any_node(:b)

      statement = Cypher.match(a)
                        .returning(Cypher.list_based_on(a.relationship_between(b))
                                         .where(b.has_labels('Movie').and(b.property(:released).is_not_null))
                                         .returning(b.property(:released))
                                         .as(:years))
                        .build
      expect(renderer.render(statement)).to eq(
        "MATCH (a:`Person` {name: 'Keanu Reeves'}) RETURN [(a)--(b) WHERE (b:`Movie` AND b.released IS NOT NULL) | b.released] AS years"
      )

      statement = Cypher.match(a)
                        .returning(Cypher.list_based_on(a.relationship_between(b))
                                         .where(b.has_labels('Movie')
                                                 .and(b.property(:released).is_not_null)
                                                 .or(b.property(:title).is_equal_to(Cypher.literal_of('The Matrix')))
                                                 .or(b.property(:title).is_equal_to(Cypher.literal_of('The Matrix 2'))))
                                         .returning(b.property(:released))
                                         .as(:years))
                        .build
      expect(renderer.render(statement)).to eq(
        "MATCH (a:`Person` {name: 'Keanu Reeves'}) RETURN [(a)--(b) WHERE ((b:`Movie` AND b.released IS NOT NULL) OR b.title = 'The Matrix' OR b.title = 'The Matrix 2') | b.released] AS years"
      )

      statement = Cypher.match(a)
                        .returning(Cypher.list_based_on(a.relationship_between(b))
                                         .where(b.has_labels('Movie'))
                                         .and(b.property(:released).is_not_null)
                                         .or(b.property(:title).is_equal_to(Cypher.literal_of('The Matrix')))
                                         .or(b.property(:title).is_equal_to(Cypher.literal_of('The Matrix 2')))
                                         .returning(b.property(:released))
                                         .as(:years))
                        .build

      expect(renderer.render(statement)).to eq(
        "MATCH (a:`Person` {name: 'Keanu Reeves'}) RETURN [(a)--(b) WHERE ((b:`Movie` AND b.released IS NOT NULL) OR b.title = 'The Matrix' OR b.title = 'The Matrix 2') | b.released] AS years"
      )

      statement = Cypher.match(a)
                        .returning(Cypher.list_based_on(a.relationship_between(b))
                                         .where(b.has_labels('Movie'))
                                         .returning(b.property(:released))
                                         .as(:years))
                        .build
      expect(renderer.render(statement)).to eq(
        "MATCH (a:`Person` {name: 'Keanu Reeves'}) RETURN [(a)--(b) WHERE b:`Movie` | b.released] AS years"
      )
    end

    describe 'PathPatternConditions' do # GH-206, 3.6.5. Using path patterns in WHERE
      let(:timothy) { Cypher.node('Person').named(:timothy).with_properties('name', Cypher.literal_of('Timothy')) }
      let(:other) { Cypher.node('Person').named(:other) }
      let(:andy_or_peter) { Cypher.list_of(Cypher.literal_of('Andy'), Cypher.literal_of('Peter')) }

      it 'doc3651 and' do
        expected = "MATCH (timothy:`Person` {name: 'Timothy'}), (other:`Person`) WHERE (other.name IN ['Andy', 'Peter'] AND (timothy)<--(other)) RETURN other.name, other.age"
        statement = Cypher.match(timothy, other)
                          .where(other.property(:name).in(andy_or_peter))
                          .and(timothy.relationship_from(other))
                          .returning(other.property(:name), other.property(:age))
                          .build
        expect(renderer.render(statement)).to eq(expected)

        statement = Cypher.match(timothy, other)
                          .where(other.property(:name).in(andy_or_peter).and(timothy.relationship_from(other)))
                          .returning(other.property(:name), other.property(:age))
                          .build

        expect(renderer.render(statement)).to eq(expected)
      end

      it 'doc3651 or' do
        expected = "MATCH (timothy:`Person` {name: 'Timothy'}), (other:`Person`) WHERE (other.name IN ['Andy', 'Peter'] OR (timothy)<--(other)) RETURN other.name, other.age"
        statement = Cypher.match(timothy, other)
                          .where(other.property(:name).in(andy_or_peter))
                          .or(timothy.relationship_from(other))
                          .returning(other.property(:name), other.property(:age))
                          .build
        expect(renderer.render(statement)).to eq(expected)

        statement = Cypher.match(timothy, other)
                          .where(other.property(:name).in(andy_or_peter).or(timothy.relationship_from(other)))
                          .returning(other.property(:name), other.property(:age))
                          .build

        expect(renderer.render(statement)).to eq(expected)
      end

      it 'doc3651 x or' do
        expected = "MATCH (timothy:`Person` {name: 'Timothy'}), (other:`Person`) WHERE (other.name IN ['Andy', 'Peter'] XOR (timothy)<--(other)) RETURN other.name, other.age"
        statement = Cypher.match(timothy, other)
                          .where(other.property(:name).in(andy_or_peter).xor(timothy.relationship_from(other)))
                          .returning(other.property(:name), other.property(:age))
                          .build

        expect(renderer.render(statement)).to eq(expected)
      end

      it 'doc3652' do
        person = Cypher.node('Person').named(:person)
        peter = Cypher.node('Person').named(:peter).with_properties('name', Cypher.literal_of('Peter'))

        statement = Cypher.match(person, peter)
                          .where(Cypher.not(person.relationship_to(peter)))
                          .returning(person.property(:name), person.property(:age))
                          .build

        expect(renderer.render(statement)).to eq(
          "MATCH (person:`Person`), (peter:`Person` {name: 'Peter'}) WHERE NOT (person)-->(peter) RETURN person.name, person.age"
        )
      end

      it 'doc3653' do
        person = Cypher.node('Person').named(:n)

        statement = Cypher.match(person)
                          .where(person.relationship_between(
                                   Cypher.any_node.with_properties('name', Cypher.literal_of('Timothy')), 'KNOWS'
                                 ))
                          .returning(person.property(:name), person.property(:age))
                          .build

        expect(renderer.render(statement))
          .to eq("MATCH (n:`Person`) WHERE (n)-[:`KNOWS`]-( {name: 'Timothy'}) RETURN n.name, n.age")
      end

      it 'gh113' do
        foo = Cypher.node('Foo').named(:foo)
        bar = Cypher.node('Bar').named(:bar)
        foo_bar = foo.relationship_to(bar, 'FOOBAR').named(:rel)
        pc = Cypher.list_based_on(foo_bar)
                   .where(bar.relationship_to(Cypher.node('ZZZ'), 'HAS'))
                   .returning(foo_bar, bar)
        statement = Cypher.match(foo).returning(foo.required_symbolic_name, pc).build

        expect(renderer.render(statement)).to eq(
          'MATCH (foo:`Foo`) RETURN foo, [(foo)-[rel:`FOOBAR`]->(bar:`Bar`) WHERE (bar)-[:`HAS`]->(:`ZZZ`) | [rel, bar]]'
        )
      end

      it 'doc3654' do
        person = Cypher.node('Person').named(:n)

        path_pattern = person.relationship_to(Cypher.any_node).named(:r)
        statement = Cypher.match(path_pattern)
                          .where(person.property(:name).is_equal_to(Cypher.literal_of('Andy')))
                          .and(Cypher.type(path_pattern).matches('K.*'))
                          .returning(Cypher.type(path_pattern), path_pattern.property(:since))
                          .build

        expect(renderer.render(statement)).to eq(
          "MATCH (n:`Person`)-[r]->() WHERE (n.name = 'Andy' AND type(r) =~ 'K.*') RETURN type(r), r.since"
        )
      end

      it 'after with' do
        expected = "MATCH (timothy:`Person` {name: 'Timothy'}), (other:`Person`) WITH timothy, other WHERE (other.name IN ['Andy', 'Peter'] AND (timothy)<--(other)) RETURN other.name, other.age"
        statement = Cypher.match(timothy, other)
                          .with(timothy, other)
                          .where(other.property(:name).in(andy_or_peter))
                          .and(timothy.relationship_from(other))
                          .returning(other.property(:name), other.property(:age))
                          .build
        expect(renderer.render(statement)).to eq(expected)

        statement = Cypher.match(timothy, other)
                          .with(timothy, other)
                          .where(other.property(:name).in(andy_or_peter).and(timothy.relationship_from(other)))
                          .returning(other.property(:name), other.property(:age))
                          .build

        expect(renderer.render(statement)).to eq(expected)
      end
    end
  end
end
