# frozen_string_literal: true

# Translated from SubqueriesIT.java.
#
# Adapted: assertions on `getCatalog().getIdentifiableExpressions()` are left out; the
# statement catalog is not implemented.
module CypherDSL
  RSpec.describe 'SubqueriesIT' do
    let(:cypher_renderer) { Renderer.get_renderer(Renderer::Configuration.new_config.with_dialect(Renderer::Dialect::NEO4J_4).build) }

    def renderer_for(dialect, escape: true)
      Renderer.get_renderer(Renderer::Configuration.new_config.always_escape_names(escape).with_dialect(dialect).build)
    end

    it 'unitSubqueries' do # GH-533
      p = Cypher.node('Person').named(:p)
      outer = Cypher.match(p)
      inner = Cypher.with(p)
                    .unwind(Cypher.range(1, 5))
                    .as(:i)
                    .create(Cypher.node('Person').with_properties('name', p.property(:name)))
                    .build

      statement = outer.call(inner).returning(Cypher.count(Cypher.asterisk)).build
      expect(cypher_renderer.render(statement)).to eq(
        'MATCH (p:`Person`) CALL {WITH p UNWIND range(1, 5) AS i CREATE (:`Person` {name: p.name})} RETURN count(*)'
      )
    end

    describe 'Scope' do
      it 'nodePatternInCallMustBeFullAndNotKnown' do
        parsed = Cypher.match(Cypher.node('Person').named(:n))
                       .call(Cypher
                               .match(Cypher.node('Movie').named(:n).with_properties('title', Cypher.literal_of('The Matrix')))
                               .where(Cypher.any_node(:n).property(:released).gte(Cypher.literal_of(1980)))
                               .returning(Cypher.any_node(:n).as(:m))
                               .build)
                       .returning(Cypher.any_node(:n).property(:name))
                       .build
        cypher = Renderer.get_renderer(Renderer::Configuration.new_config.always_escape_names(false).build).render(parsed)
        expect(cypher).to eq(
          "MATCH (n:Person) CALL (*) {MATCH (n:Movie {title: 'The Matrix'}) WHERE n.released >= 1980 RETURN n AS m} RETURN n.name"
        )
      end
    end

    describe 'DialectSupport' do
      {
        Renderer::Dialect::NEO4J_5 => "UNWIND [0, 1, 2] AS x CALL {RETURN 'hello' AS innerReturn} RETURN innerReturn",
        Renderer::Dialect::NEO4J_5_23 => "UNWIND [0, 1, 2] AS x CALL (*) {RETURN 'hello' AS innerReturn} RETURN innerReturn"
      }.each do |dialect, expected|
        it "starterExample(#{dialect})" do
          stmt = Cypher.unwind(Cypher.list_of(Cypher.literal_of(0), Cypher.literal_of(1), Cypher.literal_of(2)))
                       .as(:x)
                       .call(Cypher.returning(Cypher.literal_of('hello').as(:innerReturn)).build)
                       .returning(:innerReturn)
                       .build

          expect(renderer_for(dialect).render(stmt)).to eq(expected)
        end
      end

      {
        Renderer::Dialect::NEO4J_5 => 'MATCH (p:Player), (t:Team) CALL {WITH p WITH p, rand() AS random SET p.rating = random RETURN p.name AS playerName, p.rating AS rating} RETURN playerName, rating, t AS team ORDER BY rating LIMIT 1',
        Renderer::Dialect::NEO4J_5_23 => 'MATCH (p:Player), (t:Team) CALL (p) {WITH p, rand() AS random SET p.rating = random RETURN p.name AS playerName, p.rating AS rating} RETURN playerName, rating, t AS team ORDER BY rating LIMIT 1'
      }.each do |dialect, expected|
        it "someImports(#{dialect})" do
          p = Cypher.node('Player').named(:p)
          t = Cypher.node('Team').named(:t)

          rating = Cypher.name(:rating)
          player_name = Cypher.name(:playerName)
          stmt = Cypher.match(p, t)
                       .call(Cypher.with(p, Cypher.rand.as(:random))
                                   .set(p.property(:rating).to(Cypher.name(:random)))
                                   .returning(p.property(:name).as(player_name), p.property(:rating).as(rating))
                                   .build, p)
                       .returning(player_name, rating, t.as(:team))
                       .order_by(rating)
                       .limit(1)
                       .build

          expect(renderer_for(dialect, escape: false).render(stmt)).to eq(expected)
        end
      end

      {
        Renderer::Dialect::NEO4J_5 => 'MATCH (p:Player), (t:Team) CALL {WITH * RETURN p AS player, t AS team} RETURN player, team',
        Renderer::Dialect::NEO4J_5_23 => 'MATCH (p:Player), (t:Team) CALL (*) {RETURN p AS player, t AS team} RETURN player, team'
      }.each do |dialect, expected|
        it "allImports(#{dialect})" do
          p = Cypher.node('Player').named(:p)
          t = Cypher.node('Team').named(:t)

          player = Cypher.name(:player)
          stmt = Cypher.match(p, t)
                       .call(Cypher.returning(p.as(:player), t.as(:team)).build, Cypher.asterisk)
                       .returning(player, Cypher.name(:team))
                       .build

          expect(renderer_for(dialect, escape: false).render(stmt)).to eq(expected)
        end
      end

      {
        Renderer::Dialect::NEO4J_5 => 'MATCH (t:Team) CALL {MATCH (p:Player) RETURN count(p) AS totalPlayers} RETURN count(t) AS totalTeams, totalPlayers',
        Renderer::Dialect::NEO4J_5_23 => 'MATCH (t:Team) CALL (*) {MATCH (p:Player) RETURN count(p) AS totalPlayers} RETURN count(t) AS totalTeams, totalPlayers'
      }.each do |dialect, expected|
        it "noImports(#{dialect})" do
          p = Cypher.node('Player').named(:p)
          t = Cypher.node('Team').named(:t)

          stmt = Cypher.match(t)
                       .call(Cypher.match(p).returning(Cypher.count(p).as(:totalPlayers)).build)
                       .returning(Cypher.count(t).as(:totalTeams), Cypher.name(:totalPlayers))
                       .build

          expect(renderer_for(dialect, escape: false).render(stmt)).to eq(expected)
        end
      end
    end

    describe 'ResultReturningSubqueries' do
      it 'importingVariablesShouldWork' do
        statement = Cypher.unwind(Cypher.literal_of(0), Cypher.literal_of(1), Cypher.literal_of(2))
                          .as(:x)
                          .call(Cypher.with(Cypher.name(:x))
                                      .returning(Cypher.name(:x).multiply(Cypher.literal_of(10)).as(:y))
                                      .build)
                          .returning(:x, :y)
                          .build

        expect(cypher_renderer.render(statement)).to eq('UNWIND [0, 1, 2] AS x CALL {WITH x RETURN (x * 10) AS y} RETURN x, y')
      end

      it 'postUnionProcessingShouldWork' do
        age_property = Cypher.property(:p, :age)
        name_property = Cypher.property(:p, :name)

        # This must be 2 different person nodes and statement, otherwise the union will reuse it.
        s1 = Cypher.match(Cypher.node('Person').named(:p)).returning(:p).order_by(age_property.ascending).limit(1).build
        s2 = Cypher.match(Cypher.node('Person').named(:p)).returning(:p).order_by(age_property.descending).limit(1).build

        statement = Cypher.call(Cypher.union(s1, s2))
                          .returning(name_property, age_property)
                          .order_by(name_property)
                          .build

        expect(cypher_renderer.render(statement)).to eq(
          'CALL {MATCH (p:`Person`) RETURN p ORDER BY p.age ASC LIMIT 1 UNION MATCH (p:`Person`) RETURN p ORDER BY p.age DESC LIMIT 1} RETURN p.name, p.age ORDER BY p.name'
        )
      end

      it 'aggregationAndSideEffectsShouldWork' do
        person = Cypher.node('Person').named(:p)
        clone = Cypher.node('Clone').named(:c)
        statement = Cypher.match(person)
                          .call(Cypher.unwind(Cypher.range(1, 5))
                                      .as(:i)
                                      .create(clone)
                                      .returning(Cypher.count(clone).as(:numberOfClones))
                                      .build)
                          .returning(person.property(:name), Cypher.name(:numberOfClones))
                          .build

        expect(cypher_renderer.render(statement)).to eq(
          'MATCH (p:`Person`) CALL {UNWIND range(1, 5) AS i CREATE (c:`Clone`) RETURN count(c) AS numberOfClones} RETURN p.name, numberOfClones'
        )
      end

      it 'aggregationOnImportedVariablesShouldWork' do
        person = Cypher.node('Person').named(:p)
        other = Cypher.node('Person').named(:other)
        statement = Cypher.match(person)
                          .call(Cypher.with(person)
                                      .match(other)
                                      .where(other.property(:age).lt(person.property(:age)))
                                      .returning(Cypher.count(other).as(:youngerPersonsCount))
                                      .build)
                          .returning(person.property(:name), Cypher.name(:youngerPersonsCount))
                          .build

        expect(cypher_renderer.render(statement)).to eq(
          'MATCH (p:`Person`) CALL {WITH p MATCH (other:`Person`) WHERE other.age < p.age RETURN count(other) AS youngerPersonsCount} RETURN p.name, youngerPersonsCount'
        )
      end

      it 'nestedAfterProcedureCall' do
        # With with
        statement = Cypher.call('dbms.components')
                          .yield(:name)
                          .with(:name)
                          .call(Cypher.with(:name)
                                      .match(Cypher.any_node.named(:n))
                                      .where(Cypher.property(:n, :name).is_equal_to(Cypher.name(:name)))
                                      .returning(:n)
                                      .build)
                          .returning(:n)
                          .build

        expect(cypher_renderer.render(statement))
          .to eq('CALL dbms.components() YIELD name WITH name CALL {WITH name MATCH (n) WHERE n.name = name RETURN n} RETURN n')

        # Without with
        statement = Cypher.call('dbms.components')
                          .yield(:name)
                          .call(Cypher.with(:name)
                                      .match(Cypher.any_node.named(:n))
                                      .where(Cypher.property(:n, :name).is_equal_to(Cypher.name(:name)))
                                      .returning(:n)
                                      .build)
                          .returning(:n)
                          .build

        expect(cypher_renderer.render(statement))
          .to eq('CALL dbms.components() YIELD name CALL {WITH name MATCH (n) WHERE n.name = name RETURN n} RETURN n')

        # After inQueryCall with with
        label = Cypher.name(:label)
        statement = Cypher.match(Cypher.any_node.named(:n))
                          .with(:n)
                          .call('db.labels')
                          .yield(label)
                          .with(label)
                          .call(Cypher.with(label)
                                      .match(Cypher.any_node.named(:n))
                                      .where(Cypher.property(:n, :name).is_equal_to(label))
                                      .returning(:n)
                                      .build)
                          .returning(:n)
                          .build
        expect(cypher_renderer.render(statement)).to eq(
          'MATCH (n) WITH n CALL db.labels() YIELD label WITH label CALL {WITH label MATCH (n) WHERE n.name = label RETURN n} RETURN n'
        )

        # After inQueryCall without with
        statement = Cypher.match(Cypher.any_node.named(:n))
                          .with(:n)
                          .call('db.labels')
                          .yield(label)
                          .call(Cypher.with(label)
                                      .match(Cypher.any_node.named(:n2))
                                      .where(Cypher.property(:n2, :name).is_equal_to(label))
                                      .returning(:n2)
                                      .build)
                          .returning(:n2)
                          .build
        expect(cypher_renderer.render(statement)).to eq(
          'MATCH (n) WITH n CALL db.labels() YIELD label CALL {WITH label MATCH (n2) WHERE n2.name = label RETURN n2} RETURN n2'
        )
      end

      it 'afterRegularWith' do
        statement = Cypher.match(Cypher.node('Person').named(:p))
                          .with(:p)
                          .call(Cypher.with(:p)
                                      .match(Cypher.any_node.named(:n))
                                      .where(Cypher.property(:n, :name).is_equal_to(Cypher.property(:p, :name)))
                                      .returning(:n)
                                      .build)
                          .returning(:n)
                          .build

        expect(cypher_renderer.render(statement))
          .to eq('MATCH (p:`Person`) WITH p CALL {WITH p MATCH (n) WHERE n.name = p.name RETURN n} RETURN n')
      end

      it 'afterRegularWithManualImport' do
        statement = Cypher.match(Cypher.node('Person').named(:p))
                          .with(:p)
                          .call(Cypher.match(Cypher.any_node.named(:n))
                                      .where(Cypher.property(:n, :name).is_equal_to(Cypher.property(:p, :name)))
                                      .returning(:n)
                                      .build, :p)
                          .returning(:n)
                          .build

        expect(cypher_renderer.render(statement))
          .to eq('MATCH (p:`Person`) WITH p CALL {WITH p MATCH (n) WHERE n.name = p.name RETURN n} RETURN n')
      end

      it 'callsCallingCalls' do
        statement = Cypher.match(Cypher.any_node.named(:n)).returning(:n).build

        5.times { statement = Cypher.call(statement).returning(:n).build }

        expect(cypher_renderer.render(statement)).to eq(
          'CALL {CALL {CALL {CALL {CALL {MATCH (n) RETURN n} RETURN n} RETURN n} RETURN n} RETURN n} RETURN n'
        )
      end
    end

    describe 'ExistentialSubqueries' do
      it 'fullStatementsAsExistentialSubQuery' do # GH-578
        p = Cypher.node('Person').named(:person)
        inner = Cypher.match(p.relationship_to(Cypher.node('Dog'), 'HAS_DOG')).returning(p.property(:name)).build
        outer = Cypher.match(p)
                      .where(Cypher.exists(inner))
                      .returning(p.property(:name).as(:name))
                      .build

        expect(outer.cypher).to eq(
          'MATCH (person:`Person`) WHERE EXISTS { MATCH (person)-[:`HAS_DOG`]->(:`Dog`) RETURN person.name } RETURN person.name AS name'
        )
      end

      it 'fullStatementsAsExistentialSubQueryWithImports' do # GH-578
        p = Cypher.node('Person').named(:person)
        d = Cypher.node('Dog').named(:d)
        dog_name = Cypher.name(:dogName)
        inner = Cypher.match(p.relationship_to(d, 'HAS_DOG'))
                      .where(d.property(:name).eq(dog_name))
                      .returning(p.property(:name))
                      .build
        outer = Cypher.match(p)
                      .where(Cypher.exists(inner, Cypher.literal_of('Ozzy').as(dog_name)))
                      .returning(p.property(:name).as(:name))
                      .build

        expect(outer.cypher).to eq(
          "MATCH (person:`Person`) WHERE EXISTS { WITH 'Ozzy' AS dogName MATCH (person)-[:`HAS_DOG`]->(d:`Dog`) WHERE d.name = dogName RETURN person.name } RETURN person.name AS name"
        )
      end

      it 'simple' do
        p = Cypher.node('Person').named(:p)
        friend = Cypher.node('Person').named(:friend)

        r = p.relationship_to(friend, 'IS_FRIENDS_WITH').named(:r)
        statement = Cypher.match(r)
                          .where(Cypher
                                   .match(p.relationship_to(Cypher.node('Company').with_properties('name', Cypher.literal_of('Neo4j')), 'WORKS_FOR'))
                                   .as_condition)
                          .returning(p, r, friend)
                          .build

        expect(cypher_renderer.render(statement)).to eq(
          "MATCH (p:`Person`)-[r:`IS_FRIENDS_WITH`]->(friend:`Person`) WHERE EXISTS { MATCH (p)-[:`WORKS_FOR`]->(:`Company` {name: 'Neo4j'}) } RETURN p, r, friend"
        )
      end

      it 'withBooleanOpsAndWhere' do
        p = Cypher.node('Person').named(:person)
        company = Cypher.any_node.named(:company)
        t = Cypher.node('Technology').named(:t)

        statement = Cypher.match(p.relationship_to(company, 'WORKS_FOR'))
                          .where(company.property(:name).starts_with(Cypher.literal_of('Company')))
                          .and(Cypher.match(p.relationship_to(t, 'LIKES'))
                                     .where(Cypher.size(t.relationship_from(Cypher.any_node, 'LIKES')).gte(Cypher.literal_of(3)))
                                     .as_condition)
                          .returning(p.property(:name).as(:person), company.property(:name).as(:company))
                          .build

        expect(cypher_renderer.render(statement)).to eq(
          "MATCH (person:`Person`)-[:`WORKS_FOR`]->(company) WHERE (company.name STARTS WITH 'Company' AND EXISTS { MATCH (person)-[:`LIKES`]->(t:`Technology`) WHERE size((t)<-[:`LIKES`]-()) >= 3 }) RETURN person.name AS person, company.name AS company"
        )

        statement = Cypher.match(p.relationship_to(company, 'WORKS_FOR'))
                          .where(Cypher.match(p.relationship_to(t, 'LIKES'))
                                       .where(Cypher.size(t.relationship_from(Cypher.any_node, 'LIKES')).gte(Cypher.literal_of(3)))
                                       .as_condition)
                          .and(company.property(:name).starts_with(Cypher.literal_of('Company')))
                          .returning(p.property(:name).as(:person), company.property(:name).as(:company))
                          .build

        expect(cypher_renderer.render(statement)).to eq(
          "MATCH (person:`Person`)-[:`WORKS_FOR`]->(company) WHERE (EXISTS { MATCH (person)-[:`LIKES`]->(t:`Technology`) WHERE size((t)<-[:`LIKES`]-()) >= 3 } AND company.name STARTS WITH 'Company') RETURN person.name AS person, company.name AS company"
        )

        statement = Cypher.match(p.relationship_to(company, 'WORKS_FOR'))
                          .where(Cypher.match(p.relationship_to(t, 'LIKES'))
                                       .where(Cypher.size(t.relationship_from(Cypher.any_node, 'LIKES')).gte(Cypher.literal_of(3)))
                                       .as_condition
                                       .and(company.property(:name).starts_with(Cypher.literal_of('Company'))))
                          .returning(p.property(:name).as(:person), company.property(:name).as(:company))
                          .build

        expect(cypher_renderer.render(statement)).to eq(
          "MATCH (person:`Person`)-[:`WORKS_FOR`]->(company) WHERE (EXISTS { MATCH (person)-[:`LIKES`]->(t:`Technology`) WHERE size((t)<-[:`LIKES`]-()) >= 3 } AND company.name STARTS WITH 'Company') RETURN person.name AS person, company.name AS company"
        )
      end
    end

    describe 'InTransactions' do
      it 'docs44_7' do
        line = Cypher.name(:line)
        statement = Cypher.load_csv('file:///friends.csv')
                          .as(:line)
                          .call_in_transactions(Cypher.with(:line)
                                                      .create(Cypher.node('Person')
                                                                    .with_properties('name', Cypher.value_at(line, 1), 'age',
                                                                                     Cypher.to_integer(Cypher.value_at(line, 2))))
                                                      .build)
                          .build
        expect(cypher_renderer.render(statement)).to eq(
          "LOAD CSV FROM 'file:///friends.csv' AS line CALL {WITH line CREATE (:`Person` {name: line[1], age: toInteger(line[2])})} IN TRANSACTIONS"
        )
      end

      it 'docs44_7_1a' do
        line = Cypher.name(:line)
        statement = Cypher.load_csv('file:///friends.csv')
                          .as(:line)
                          .call_in_transactions(Cypher.with(:line)
                                                      .create(Cypher.node('Person')
                                                                    .with_properties('name', Cypher.value_at(line, 1), 'age',
                                                                                     Cypher.to_integer(Cypher.value_at(line, 2))))
                                                      .build, 2)
                          .build
        expect(cypher_renderer.render(statement)).to eq(
          "LOAD CSV FROM 'file:///friends.csv' AS line CALL {WITH line CREATE (:`Person` {name: line[1], age: toInteger(line[2])})} IN TRANSACTIONS OF 2 ROWS"
        )
      end

      it 'docs44_7_1b' do
        statement = Cypher.match(Cypher.any_node(:n))
                          .call_in_transactions(Cypher.with(:n).detach_delete(:n).build, 2)
                          .build
        expect(cypher_renderer.render(statement)).to eq('MATCH (n) CALL {WITH n DETACH DELETE n} IN TRANSACTIONS OF 2 ROWS')
      end

      [-1, 23].each do |num_rows|
        it "afterRegularWith(#{num_rows})" do
          subquery = Cypher.create(Cypher.any_node(:p).relationship_to(Cypher.node('User').named(:u), 'IS'))
                           .returning(Cypher.name(:u))
                           .build

          with = Cypher.match(Cypher.node('Person').named(:p)).with(:p)
          statement = (num_rows.negative? ? with.call_in_transactions(subquery, :p) : with.call_in_transactions(subquery, num_rows, :p))
                      .returning(:u)
                      .build

          expected = 'MATCH (p:`Person`) WITH p CALL {WITH p CREATE (p)-[:`IS`]->(u:`User`) RETURN u} IN TRANSACTIONS'
          expected += " OF #{num_rows} ROWS" if num_rows.positive?
          expected += ' RETURN u'
          expect(cypher_renderer.render(statement)).to eq(expected)
        end

        it "afterRegularWithSymNameImport(#{num_rows})" do
          p = Cypher.name(:p)
          subquery = Cypher.create(Cypher.any_node(p).relationship_to(Cypher.node('User').named(:u), 'IS'))
                           .returning(Cypher.name(:u))
                           .build

          with = Cypher.match(Cypher.node('Person').named(p)).with(p)
          statement = (num_rows.negative? ? with.call_in_transactions(subquery, p) : with.call_in_transactions(subquery, num_rows, p))
                      .returning(:u)
                      .build

          expected = 'MATCH (p:`Person`) WITH p CALL {WITH p CREATE (p)-[:`IS`]->(u:`User`) RETURN u} IN TRANSACTIONS'
          expected += " OF #{num_rows} ROWS" if num_rows.positive?
          expected += ' RETURN u'
          expect(cypher_renderer.render(statement)).to eq(expected)
        end
      end

      it 'nestedAfterProcedureCall' do
        # With with
        statement = Cypher.call('dbms.components')
                          .yield(:name)
                          .with(:name)
                          .call_in_transactions(Cypher.with(:name)
                                                      .match(Cypher.any_node.named(:n))
                                                      .where(Cypher.property(:n, :name).is_equal_to(Cypher.name(:name)))
                                                      .returning(:n)
                                                      .build)
                          .returning(:n)
                          .build

        expect(cypher_renderer.render(statement)).to eq(
          'CALL dbms.components() YIELD name WITH name CALL {WITH name MATCH (n) WHERE n.name = name RETURN n} IN TRANSACTIONS RETURN n'
        )

        # Without with
        statement = Cypher.call('dbms.components')
                          .yield(:name)
                          .call_in_transactions(Cypher.with(:name)
                                                      .match(Cypher.any_node.named(:n))
                                                      .where(Cypher.property(:n, :name).is_equal_to(Cypher.name(:name)))
                                                      .returning(:n)
                                                      .build)
                          .returning(:n)
                          .build

        expect(cypher_renderer.render(statement)).to eq(
          'CALL dbms.components() YIELD name CALL {WITH name MATCH (n) WHERE n.name = name RETURN n} IN TRANSACTIONS RETURN n'
        )

        # After inQueryCall with with
        label = Cypher.name(:label)
        statement = Cypher.match(Cypher.any_node.named(:n))
                          .with(:n)
                          .call('db.labels')
                          .yield(label)
                          .with(label)
                          .call_in_transactions(Cypher.with(label)
                                                      .match(Cypher.any_node.named(:n))
                                                      .where(Cypher.property(:n, :name).is_equal_to(label))
                                                      .returning(:n)
                                                      .build)
                          .returning(:n)
                          .build
        expect(cypher_renderer.render(statement)).to eq(
          'MATCH (n) WITH n CALL db.labels() YIELD label WITH label CALL {WITH label MATCH (n) WHERE n.name = label RETURN n} IN TRANSACTIONS RETURN n'
        )

        # After inQueryCall without with
        statement = Cypher.match(Cypher.any_node.named(:n))
                          .with(:n)
                          .call('db.labels')
                          .yield(label)
                          .call_in_transactions(Cypher.with(label)
                                                      .match(Cypher.any_node.named(:n2))
                                                      .where(Cypher.property(:n2, :name).is_equal_to(label))
                                                      .returning(:n2)
                                                      .build)
                          .returning(:n2)
                          .build
        expect(cypher_renderer.render(statement)).to eq(
          'MATCH (n) WITH n CALL db.labels() YIELD label CALL {WITH label MATCH (n2) WHERE n2.name = label RETURN n2} IN TRANSACTIONS RETURN n2'
        )
      end
    end

    describe 'CollectSubqueries' do
      let(:person) { Cypher.node('Person').named(:person) }
      let(:person_name) { person.property(:name) }
      let(:dog) { Cypher.node('Dog').named(:dog) }
      let(:dog_name) { dog.property(:name) }
      let(:has_dog) { person.relationship_to(dog, 'HAS_DOG') }
      let(:cat) { Cypher.node('Cat').named(:cat) }

      it 'shouldCheckForReturnStatement' do
        non_return_statement = Cypher.create(Cypher.node('Foo')).build
        expect { Cypher.collect(non_return_statement) }.to raise_error(
          ArgumentError,
          'The final RETURN clause in a subquery used with COLLECT is mandatory and the RETURN clause must return exactly one column.'
        )
      end

      it 'simple' do
        inner = Cypher.match(person.relationship_to(dog, 'HAS_DOG')).returning(dog_name).build
        stmt = Cypher.match(person)
                     .where(Cypher.literal_of('Ozzy').in(Cypher.collect(inner)))
                     .returning(person.property(:name).as(:name))
                     .build
        expect(stmt.cypher).to eq(
          "MATCH (person:`Person`) WHERE 'Ozzy' IN COLLECT { MATCH (person)-[:`HAS_DOG`]->(dog:`Dog`) RETURN dog.name } RETURN person.name AS name"
        )
      end

      it 'withWhereClause' do
        r = has_dog.named(:r)
        inner = Cypher.match(r).where(r.property(:since).gt(Cypher.literal_of(2017))).returning(dog_name).build
        stmt = Cypher.match(person)
                     .returning(person.property(:name).as(:name), Cypher.collect(inner).as(:youngDogs))
                     .build
        expect(stmt.cypher).to eq(
          'MATCH (person:`Person`) RETURN person.name AS name, COLLECT { MATCH (person)-[r:`HAS_DOG`]->(dog:`Dog`) WHERE r.since > 2017 RETURN dog.name } AS youngDogs'
        )
      end

      it 'withAUnion' do
        has_cat = person.relationship_to(cat, 'HAS_CAT')
        inner = Cypher.union(Cypher.match(has_dog).returning(dog_name.as(:petName)).build,
                             Cypher.match(has_cat).returning(cat.property(:name).as(:petName)).build)

        stmt = Cypher.match(person)
                     .returning(person.property(:name).as(:name), Cypher.collect(inner).as(:petNames))
                     .build
        expect(stmt.cypher).to eq(
          'MATCH (person:`Person`) RETURN person.name AS name, COLLECT { MATCH (person)-[:`HAS_DOG`]->(dog:`Dog`) RETURN dog.name AS petName UNION MATCH (person)-[:`HAS_CAT`]->(cat:`Cat`) RETURN cat.name AS petName } AS petNames'
        )
      end

      it 'withWith' do
        r = has_dog.named(:r)
        year_of_the_dog = Cypher.literal_of(2018).as(:yearOfTheDog)
        inner = Cypher.match(r).where(r.property(:since).eq(year_of_the_dog)).returning(dog_name).build
        stmt = Cypher.match(person)
                     .returning(person.property(:name).as(:name),
                                Cypher.subquery_with(year_of_the_dog).collect(inner).as(:dogsOfTheYear))
                     .build
        expect(stmt.cypher).to eq(
          'MATCH (person:`Person`) RETURN person.name AS name, COLLECT { WITH 2018 AS yearOfTheDog MATCH (person)-[r:`HAS_DOG`]->(dog:`Dog`) WHERE r.since = yearOfTheDog RETURN dog.name } AS dogsOfTheYear'
        )
      end

      it 'inReturn' do
        toy = Cypher.node('Toy').named(:t)
        inner = Cypher.match(has_dog)
                      .match(dog.relationship_to(toy, 'HAS_TOY'))
                      .returning(toy.property(:name))
                      .build
        stmt = Cypher.match(person)
                     .returning(person.property(:name), Cypher.collect(inner).as(:toyNames))
                     .build
        expect(stmt.cypher).to eq(
          'MATCH (person:`Person`) RETURN person.name, COLLECT { MATCH (person)-[:`HAS_DOG`]->(dog:`Dog`) MATCH (dog)-[:`HAS_TOY`]->(t:`Toy`) RETURN t.name } AS toyNames'
        )
      end

      it 'collectInSet' do
        inner = Cypher.match(has_dog).returning(dog_name).build
        stmt = Cypher.match(person)
                     .where(person.property(:name).eq(Cypher.literal_of('Peter')))
                     .set(person.property(:dogNames).to(Cypher.collect(inner)))
                     .returning(person.property(:dogNames).as(:dogNames))
                     .build
        expect(stmt.cypher).to eq(
          "MATCH (person:`Person`) WHERE person.name = 'Peter' SET person.dogNames = COLLECT { MATCH (person)-[:`HAS_DOG`]->(dog:`Dog`) RETURN dog.name } RETURN person.dogNames AS dogNames"
        )
      end

      it 'inCase' do
        inner = Cypher.match(has_dog).returning(dog_name).build
        stmt = Cypher.match(person)
                     .returning(Cypher.case_expression
                                      .when(Cypher.collect(inner).eq(Cypher.list_of))
                                      .then(Cypher.literal_of('No Dogs ').concat(person_name))
                                      .else_default(person_name)
                                      .as(:result))
                     .build
        expect(stmt.cypher).to eq(
          "MATCH (person:`Person`) RETURN CASE WHEN COLLECT { MATCH (person)-[:`HAS_DOG`]->(dog:`Dog`) RETURN dog.name } = [] THEN ('No Dogs ' + person.name) ELSE person.name END AS result"
        )
      end

      it 'asGroupingKey' do
        inner = Cypher.match(has_dog).returning(dog_name).build
        stmt = Cypher.match(person)
                     .returning(Cypher.collect(inner).as(:dogNames), Cypher.avg(person.property(:age)).as(:averageAge))
                     .order_by(Cypher.name(:dogNames))
                     .build
        expect(stmt.cypher).to eq(
          'MATCH (person:`Person`) RETURN COLLECT { MATCH (person)-[:`HAS_DOG`]->(dog:`Dog`) RETURN dog.name } AS dogNames, avg(person.age) AS averageAge ORDER BY dogNames'
        )
      end
    end
  end
end
