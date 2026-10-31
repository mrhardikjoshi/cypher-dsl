# frozen_string_literal: true

# Translated from IssueRelatedIT.java, fifth slice (GH-634 … GH-999).
#
# Adapted: `mapLiteralShouldRenderProper` asserts the Java `toString`; here the literal is rendered.
# `subQueryFromParserScope` needs generated names (`Configuration#with_generated_names`), which are
# not implemented yet, and is marked pending.
module CypherDSL
  RSpec.describe 'IssueRelatedIT (5)' do
    let(:pretty) { Renderer.get_renderer(Renderer::Configuration.pretty_printing) }

    def pretty_for(dialect)
      Renderer.get_renderer(Renderer::Configuration.new_config.with_dialect(dialect).with_pretty_print(true).build)
    end

    it 'with all proper should work' do # GH-634
      this0 = Cypher.node('User').named(:this)
      x = Cypher.name(:x)
      stmt = Cypher.match(this0)
                   .call(Cypher.with(this0.as(:x)).returning(Cypher.count(Cypher.asterisk).as(x)).build, Cypher.asterisk)
                   .returning(x, Cypher.count(Cypher.asterisk))
                   .build

      expect(stmt.cypher).to eq('MATCH (this:`User`) CALL (*) {WITH this AS x RETURN count(*) AS x} RETURN x, count(*)')
      expect(Renderer.get_renderer(Renderer::Configuration.new_config.with_dialect(Renderer::Dialect::NEO4J_4).build).render(stmt))
        .to eq('MATCH (this:`User`) CALL {WITH * WITH this AS x RETURN count(*) AS x} RETURN x, count(*)')
    end

    it 'with all and then some' do # GH-634
      stmt = Cypher.match(Cypher.any_node(:n))
                   .with(Cypher.asterisk, Cypher.count(Cypher.asterisk).as(:count))
                   .returning(Cypher.asterisk)
                   .build

      expect(stmt.cypher).to eq('MATCH (n) WITH *, count(*) AS count RETURN *')
    end

    it 'map literal should render proper' do # GH-642
      l = Cypher.literal_of({ a: 1, b: 'c', whatever: Cypher.literal_of(1) })
      expect(Cypher.returning(l).build.cypher).to eq("RETURN {a: 1, b: 'c', whatever: 1}")
    end

    it 'full text call should work' do # GH-694
      city = Cypher.any_node(:city)
      node = Cypher.name(:node)
      score = Cypher.name(:score)
      statement = Cypher.match(Cypher.path(:path).defined_by(Cypher.node('Person').named(:p).relationship_to(city, 'TRAVELED_TO')))
                        .where(Cypher.exists(Cypher.call('db.index.fulltext.queryNodes')
                                                   .with_args(Cypher.literal_of('City'), Cypher.literal_of('ham*'))
                                                   .yield(node, score)
                                                   .with(Cypher.asterisk)
                                                   .where(Cypher.id(Cypher.any_node(node)).eq(Cypher.id(city)))
                                                   .returning(node, score)
                                                   .build))
                        .returning(Cypher.name(:path))
                        .build
      expect(statement.cypher).to eq(<<~CYPHER.tr("\n", ' ').strip)
        MATCH path = (p:`Person`)-[:`TRAVELED_TO`]->(city)
        WHERE EXISTS {
        CALL db.index.fulltext.queryNodes('City', 'ham*')
        YIELD node, score
        WITH *
        WHERE id(node) = id(city)
        RETURN node, score
        }
        RETURN path
      CYPHER
    end

    it 'relationship chains must actively enter relationships during visit' do # GH-712
      tom = Cypher.node('Person').named(:person0).with_properties('name', Cypher.literal_of('Tom Hanks'))
      movie = Cypher.node('Movie').named(:movie0)
      co_actors = Cypher.node('Person').named(:person1)
      path0 = Cypher.path(:path0)
      path1 = Cypher.path(:path1)

      statement = Cypher.match(path0.defined_by(tom.relationship_to(movie, 'ACTED_IN').named(:acted_in0).relationship_from(co_actors, 'ACTED_IN')))
                        .match(path1.defined_by(tom.relationship_to(movie, 'ACTED_IN').named(:acted_in0).relationship_from(co_actors, 'ACTED_IN')))
                        .returning(:path0, :path1)
                        .build

      expect(pretty.render(statement)).to eq(<<~CYPHER.chomp)
        MATCH path0 = (person0:Person {
          name: 'Tom Hanks'
        })-[acted_in0:ACTED_IN]->(movie0:Movie)<-[:ACTED_IN]-(person1:Person)
        MATCH path1 = (person0)-[acted_in0]->(movie0)<-[:ACTED_IN]-(person1)
        RETURN path0, path1
      CYPHER
    end

    it 'non builder relationship method should work' do # GH-749
      n1 = Cypher.node('N1')
      n2 = Cypher.node('N2')

      expect(Cypher.match(n1.relationship_with(n2, Relationship::Direction::LTR, 'X').named(:x)).returning(Cypher.asterisk).build.cypher)
        .to eq('MATCH (:`N1`)-[x:`X`]->(:`N2`) RETURN *')
      expect(Cypher.match(n1.relationship_with(n2, Relationship::Direction::RTL, 'X').named(:x)).returning(Cypher.asterisk).build.cypher)
        .to eq('MATCH (:`N1`)<-[x:`X`]-(:`N2`) RETURN *')
      expect(Cypher.match(n1.relationship_with(n2, Relationship::Direction::UNI, 'X').named(:x)).returning(Cypher.asterisk).build.cypher)
        .to eq('MATCH (:`N1`)-[x:`X`]-(:`N2`) RETURN *')
    end

    it 'identifiables created in subqueries must be recognized as seen too' do # GH-826
      n1 = Cypher.node('Foo').named(:n1)
      n2 = Cypher.node('Bar').named(:n2)
      result_statement = Cypher.create(n1)
                               .with(n1)
                               .call(Cypher.with(n1)
                                           .merge(n2.with_properties('foo', Cypher.literal_of('x')))
                                           .create(n1.relationship_to(n2, 'NESTED'))
                                           .returning(Cypher.count(n2).as('foo_2'))
                                           .build)
                               .returning(Cypher.literal_true)
                               .build

      expect(result_statement.cypher).to eq(
        "CREATE (n1:`Foo`) WITH n1 CALL (n1) {MERGE (n2:`Bar` {foo: 'x'}) CREATE (n1)-[:`NESTED`]->(n2) RETURN count(n2) AS foo_2} RETURN true"
      )
    end

    it 'sequential existing subqueries should not have scoping issues' do # GH-832
      n1 = Cypher.node('Foo').named(:n1)
      n2 = Cypher.node('Bar').named(:n2)
      result_statement = Cypher.match(n1)
                               .where(Cypher.match(n1.relationship_to(n2))
                                            .where(n2.property(:bar).is_false)
                                            .as_condition
                                            .or(Cypher.match(n1.relationship_to(n2)).where(n2.property(:foo).is_true).as_condition))
                               .returning(Cypher.literal_true)
                               .build

      expect(result_statement.cypher).to eq(
        'MATCH (n1:`Foo`) WHERE (EXISTS { MATCH (n1)-->(n2:`Bar`) WHERE n2.bar = false } OR EXISTS { MATCH (n1)-->(n2:`Bar`) WHERE n2.foo = true }) RETURN true'
      )
    end

    it 'alias must be included in subqueries 1' do # GH-838
      n1 = Cypher.node('Foo').named(:n1)
      point = Cypher.name(:point)
      result_statement = Cypher.match(n1)
                               .returning(n1.project('points',
                                                     Cypher.collect(Cypher.unwind(n1.property(:points))
                                                                          .as(point)
                                                                          .returning(Cypher.list_of(point.property(:x), point.property(:y)))
                                                                          .build)))
                               .build

      expect(result_statement.cypher).to eq('MATCH (n1:`Foo`) RETURN n1{points: COLLECT { UNWIND n1.points AS point RETURN [point.x, point.y] }}')
    end

    it 'alias must be included in subqueries 2' do # GH-838
      n1 = Cypher.node('Foo').named(:n1)
      point = Cypher.name(:point)
      points = Cypher.name(:points)
      result_statement = Cypher.match(n1)
                               .returning(n1.project('points',
                                                     Cypher.collect(Cypher.with(n1.property(:points).as(points))
                                                                          .unwind(points)
                                                                          .as(point)
                                                                          .returning(Cypher.list_of(point.property(:x), point.property(:y)))
                                                                          .build)))
                               .build

      expect(result_statement.cypher).to eq(
        'MATCH (n1:`Foo`) RETURN n1{points: COLLECT { WITH n1.points AS points UNWIND points AS point RETURN [point.x, point.y] }}'
      )
    end

    it 'alias must be included in subqueries 3' do # GH-838
      n1 = Cypher.node('Foo').named(:n1)
      n2 = Cypher.node('Bar').named(:n2)
      point = Cypher.name(:point)
      result_statement = Cypher.match(n1)
                               .returning(n1.project('points', Cypher.collect(
                                                                 Cypher.unwind(n1.property(:points))
                                                                       .as(point)
                                                                       .match(n2)
                                                                       .where(n2.property(:loc).eq(point))
                                                                       .returning(n2.project(n2.property(:y).as(:x),
                                                                                             Cypher.collect(Cypher.match(Cypher.node('FooBar').named(:fb)).returning(Cypher.name(:fb).as(:foo)).build).as(:y)))
                                                                       .build
                                                               )))
                               .build

      expect(result_statement.cypher).to eq(
        'MATCH (n1:`Foo`) RETURN n1{points: COLLECT { UNWIND n1.points AS point MATCH (n2:`Bar`) WHERE n2.loc = point RETURN n2{x: n2.y, y: COLLECT { MATCH (fb:`FooBar`) RETURN fb AS foo }} }}'
      )
    end

    describe 'additional unit subqueries' do # GH-533
      let(:create_this1) { Cypher.name(:create_this1) }
      let(:create_var0) { Cypher.name(:create_var0) }
      let(:create_var2) { Cypher.name(:create_var2) }
      let(:create_this5) { Cypher.name(:create_this5) }
      let(:create_var3) { Cypher.name(:create_var3) }

      let(:inner) do
        Cypher.with(create_this1, create_var0)
              .unwind(create_var0.property(:actors).property(:create))
              .as(create_var2)
              .with(create_var2.property(:node).as(create_var3), create_var2.property(:edge).as(:create_var4), create_this1)
              .create(Cypher.node('Actor').named(create_this5))
              .set(create_this5.property(:name).to(create_var3.property(:name)))
              .merge(Cypher.any_node(create_this1).relationship_from(Cypher.any_node(create_this5), 'ACTED_IN').named(:create_this6))
              .build
      end

      def outer(inner_imports, outer_imports)
        Cypher.unwind(Cypher.parameter(:create_param0))
              .as(create_var0)
              .call(Cypher.with(create_var0)
                          .create(Cypher.node('Movie').named(create_this1))
                          .set(create_this1.property(:id).to(create_var0.property(:id)))
                          .with(create_this1, create_var0)
                          .call(inner, *inner_imports)
                          .returning(create_this1)
                          .build, *outer_imports)
              .returning(Cypher.collect(create_this1.project('id')).as(:data))
              .build
      end

      it 'implicit imports' do
        stmt = outer([], [])

        expect(pretty_for(Renderer::Dialect::NEO4J_4).render(stmt)).to eq(<<~CYPHER.chomp)
          UNWIND $create_param0 AS create_var0
          CALL {
            WITH create_var0
            CREATE (create_this1:Movie)
            SET create_this1.id = create_var0.id
            WITH create_this1, create_var0
            CALL {
              WITH create_this1, create_var0
              UNWIND create_var0.actors.create AS create_var2
              WITH create_var2.node AS create_var3, create_var2.edge AS create_var4, create_this1
              CREATE (create_this5:Actor)
              SET create_this5.name = create_var3.name
              MERGE (create_this1)<-[create_this6:ACTED_IN]-(create_this5)
            }
            RETURN create_this1
          }
          RETURN collect(create_this1 {
            .id
          }) AS data
        CYPHER

        expect(pretty.render(stmt)).to eq(<<~CYPHER.chomp)
          UNWIND $create_param0 AS create_var0
          CALL (create_var0) {
            CREATE (create_this1:Movie)
            SET create_this1.id = create_var0.id
            WITH create_this1, create_var0
            CALL (create_this1, create_var0) {
              UNWIND create_var0.actors.create AS create_var2
              WITH create_var2.node AS create_var3, create_var2.edge AS create_var4, create_this1
              CREATE (create_this5:Actor)
              SET create_this5.name = create_var3.name
              MERGE (create_this1)<-[create_this6:ACTED_IN]-(create_this5)
            }
            RETURN create_this1
          }
          RETURN collect(create_this1 {
            .id
          }) AS data
        CYPHER
      end

      it 'explicit imports' do
        stmt = outer([create_this1, create_var0], [create_var0])

        expect(pretty_for(Renderer::Dialect::NEO4J_4).render(stmt)).to eq(<<~CYPHER.chomp)
          UNWIND $create_param0 AS create_var0
          CALL {
            WITH create_var0
            WITH create_var0
            CREATE (create_this1:Movie)
            SET create_this1.id = create_var0.id
            WITH create_this1, create_var0
            CALL {
              WITH create_this1, create_var0
              WITH create_this1, create_var0
              UNWIND create_var0.actors.create AS create_var2
              WITH create_var2.node AS create_var3, create_var2.edge AS create_var4, create_this1
              CREATE (create_this5:Actor)
              SET create_this5.name = create_var3.name
              MERGE (create_this1)<-[create_this6:ACTED_IN]-(create_this5)
            }
            RETURN create_this1
          }
          RETURN collect(create_this1 {
            .id
          }) AS data
        CYPHER

        expect(pretty.render(stmt)).to eq(<<~CYPHER.chomp)
          UNWIND $create_param0 AS create_var0
          CALL (create_var0) {
            WITH create_var0
            CREATE (create_this1:Movie)
            SET create_this1.id = create_var0.id
            WITH create_this1, create_var0
            CALL (create_this1, create_var0) {
              WITH create_this1, create_var0
              UNWIND create_var0.actors.create AS create_var2
              WITH create_var2.node AS create_var3, create_var2.edge AS create_var4, create_this1
              CREATE (create_this5:Actor)
              SET create_this5.name = create_var3.name
              MERGE (create_this1)<-[create_this6:ACTED_IN]-(create_this5)
            }
            RETURN create_this1
          }
          RETURN collect(create_this1 {
            .id
          }) AS data
        CYPHER
      end
    end

    it 'variables of list predicates must not be scoped' do # GH-903
      expected = <<~CYPHER.tr("\n", ' ').strip
        MATCH (this:`Movie`)
        WHERE single(this0 IN [(this)-[this1:`IN_GENRE`]->(this0:`Genre`) WHERE this0.name = $param0 | 1] WHERE true)
        RETURN this{.actorCount} AS this
      CYPHER

      movie = Cypher.node('Movie').named(:this)
      genre = Cypher.node('Genre').named(:this0)
      rel = movie.relationship_to(genre, 'IN_GENRE').named(:this1)
      statement = Cypher.match(movie)
                        .where(Cypher.single(:this0)
                                     .in(Cypher.list_based_on(rel)
                                               .where(genre.property(:name).eq(Cypher.parameter(:param0)))
                                               .returning(Cypher.literal_of(1)))
                                     .where(Cypher.is_true))
                        .returning(movie.project('actorCount').as(:this))
                        .build
      expect(statement.cypher).to eq(expected)
    end

    [Renderer::Dialect::NEO4J_4, Renderer::Dialect::NEO4J_5_DEFAULT_CYPHER].each do |dialect|
      it "sub query from parser scope (#{dialect})" do # GH-999
        pending 'generated names (Configuration#with_generated_names) are not implemented yet'
        cfg = Renderer::Configuration.new_config.with_pretty_print(true).with_generated_names(true).with_dialect(dialect).build
        renderer = Renderer.get_renderer(cfg)

        named = Cypher.node('Movie').named(:m)
        stmt = Cypher.call(Cypher.create(named).returning(:m).build)
                     .call(Cypher.returning(named.project(Cypher.property(named.required_symbolic_name, 'title')).as(:movies)).build, named)
                     .returning(:movies)
                     .build
        normalized = renderer.render(stmt)

        expected = if dialect == Renderer::Dialect::NEO4J_4
                     <<~CYPHER.chomp
                       CALL {
                         CREATE (v0:Movie)
                         RETURN v0
                       }
                       CALL {
                         WITH v0
                         RETURN v0 {
                           .title
                         } AS v1
                       }
                       RETURN v1
                     CYPHER
                   else
                     <<~CYPHER.chomp
                       CALL () {
                         CREATE (v0:Movie)
                         RETURN v0
                       }
                       CALL (v0) {
                         RETURN v0 {
                           .title
                         } AS v1
                       }
                       RETURN v1
                     CYPHER
                   end
        expect(normalized).to eq(expected)
      end
    end
  end
end
