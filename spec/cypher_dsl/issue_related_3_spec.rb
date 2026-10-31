# frozen_string_literal: true

# Translated from IssueRelatedIT.java, third slice (GH-189 … GH-388).
#
# Adapted: `subqueryWithRename` runs over this gem's three dialects; the Java test also covers
# NEO4J_5_26 / CYPHER_5 / CYPHER_25 prefixes, which are not implemented.
module CypherDSL
  RSpec.describe 'IssueRelatedIT (3)' do
    let(:pretty) { Renderer.get_renderer(Renderer::Configuration.pretty_printing) }

    it 'property for expression with collection of names' do # GH-189
      node = Cypher.node('Node').named(:n)
      cypher = Cypher.match(node).returning(Cypher.property(node.required_symbolic_name, ['name'])).build.cypher
      expect(cypher).to eq('MATCH (n:`Node`) RETURN n.name')
    end

    it 'exposes with based on expression collection on next' do # GH-189
      node = Cypher.node('Node').named(:n)
      cypher = Cypher.match(node)
                     .with([node.required_symbolic_name])
                     .with([node.required_symbolic_name])
                     .call('my.procedure')
                     .yield(:x)
                     .with([node.required_symbolic_name])
                     .returning(node)
                     .build
                     .cypher
      expect(cypher).to eq('MATCH (n:`Node`) WITH n WITH n CALL my.procedure() YIELD x WITH n RETURN n')
    end

    it 'exposes with distinct based on expression collection on next' do # GH-189
      node = Cypher.node('Node').named(:n)
      cypher = Cypher.match(node)
                     .with_distinct([node.required_symbolic_name])
                     .with_distinct([node.required_symbolic_name])
                     .call('my.procedure')
                     .yield(:x)
                     .with_distinct([node.required_symbolic_name])
                     .returning(node)
                     .build
                     .cypher
      expect(cypher).to eq('MATCH (n:`Node`) WITH DISTINCT n WITH DISTINCT n CALL my.procedure() YIELD x WITH DISTINCT n RETURN n')
    end

    shared_examples 'symbolic names in NOT conditions' do
      it 'renders the pattern without resolving the names' do
        expect(Renderer.get_renderer(Renderer::Configuration.new_config.build).render(q)).to eq(
          'MATCH (node:`Division`) WITH DISTINCT node WHERE NOT (node)-[:`IN`]->(:`Department`)-[:`INSIDE` {rel_property: true}]->(:`Department`)-[:`EMPLOYS`]->(:`Employee`) RETURN *'
        )
        expect(Renderer.get_renderer(Renderer::Configuration.new_config.always_escape_names(false).build).render(q)).to eq(
          'MATCH (node:Division) WITH DISTINCT node WHERE NOT (node)-[:IN]->(:Department)-[:INSIDE {rel_property: true}]->(:Department)-[:EMPLOYS]->(:Employee) RETURN *'
        )
        expect(pretty.render(q)).to eq(<<~CYPHER.chomp)
          MATCH (node:Division)
          WITH DISTINCT node
          WHERE NOT (node)-[:IN]->(:Department)-[:INSIDE {
            rel_property: true
          }]->(:Department)-[:EMPLOYS]->(:Employee)
          RETURN *
        CYPHER
      end
    end

    describe 'symbolic names in not conditions must not be resolved when condition is a relationship pattern v1' do # GH-197
      let(:q) do
        node = Cypher.node('Division').named(:node)
        Cypher.match(node)
              .with_distinct(node)
              .where(Cypher.not(Cypher.any_node(node.required_symbolic_name)
                                      .relationship_to(Cypher.node('Department'), 'IN')
                                      .relationship_to(Cypher.node('Department'), 'INSIDE')
                                      .properties('rel_property', Cypher.literal_true)
                                      .relationship_to(Cypher.node('Employee'), 'EMPLOYS')))
              .returning(Cypher.asterisk)
              .build
      end

      it_behaves_like 'symbolic names in NOT conditions'
    end

    describe 'symbolic names in not conditions must not be resolved when condition is a relationship pattern v2' do # GH-197
      let(:q) do
        node = Cypher.node('Division').named(:node)
        Cypher.match(node)
              .with_distinct(node)
              .where(Cypher.not(node.relationship_to(Cypher.node('Department'), 'IN')
                                    .relationship_to(Cypher.node('Department'), 'INSIDE')
                                    .properties('rel_property', Cypher.literal_true)
                                    .relationship_to(Cypher.node('Employee'), 'EMPLOYS')))
              .returning(Cypher.asterisk)
              .build
      end

      it_behaves_like 'symbolic names in NOT conditions'
    end

    it 'symbolic names must be cleared after union' do # GH-197
      actor = Cypher.node('Actor').named(:n)
      movie = Cypher.node('Movie').named(:n)
      stmt = Cypher.union_all(Cypher.match(actor).returning(actor.property(:name).as(:name)).build,
                              Cypher.match(movie).returning(movie.property(:title).as(:name)).build)
      expect(stmt.cypher).to eq('MATCH (n:`Actor`) RETURN n.name AS name UNION ALL MATCH (n:`Movie`) RETURN n.title AS name')
    end

    it 'pattern comprehension must be scoped' do # GH-203
      test_node = Cypher.node('Department').named(:d)
      user = Cypher.node('User').named(:u)
      query = Cypher.match(test_node)
                    .returning(test_node.project(Cypher.asterisk, 'firstname',
                                                 Cypher.list_based_on(test_node.relationship_to(user)).returning(user.property(:firstname)), 'lastname',
                                                 Cypher.list_based_on(test_node.relationship_to(user)).returning(user.property(:lastname))))
                    .build

      expect(query.cypher).to eq(
        'MATCH (d:`Department`) RETURN d{.*, firstname: [(d)-->(u:`User`) | u.firstname], lastname: [(d)-->(u:`User`) | u.lastname]}'
      )
    end

    it 'community site20220304' do # GH-319
      nodes = Cypher.name(:nodes)
      relations = Cypher.name(:relations)
      second_nodes = Cypher.name(:second_nodes)
      second_relations = Cypher.name(:second_relations)

      first_path = Cypher.path(:p).defined_by(Cypher.node('lookingType').relationship_from(Cypher.any_node, 'specifiedRelation'))
      second_path = Cypher.path(:second_p)
                          .defined_by(Cypher.any_node(:n)
                                            .relationship_to(Cypher.any_node.named(second_nodes), 'otherRelation')
                                            .named(second_relations))

      inner = Cypher.unwind(nodes)
                    .as(:n)
                    .with(:n)
                    .match(second_path)
                    .returning(second_nodes, second_relations)
                    .build

      complete_statement = Cypher.match(first_path)
                                 .with(Cypher.nodes(first_path).as(nodes), Cypher.relationships(first_path).as(relations))
                                 .call(inner, nodes)
                                 .returning(nodes, relations, Cypher.collect(second_nodes), Cypher.collect(second_relations))
                                 .build

      expect(pretty.render(complete_statement)).to eq(<<~CYPHER.chomp)
        MATCH p = (:lookingType)<-[:specifiedRelation]-()
        WITH nodes(p) AS nodes, relationships(p) AS relations
        CALL (nodes) {
          UNWIND nodes AS n
          WITH n
          MATCH second_p = (n)-[second_relations:otherRelation]->(second_nodes)
          RETURN second_nodes, second_relations
        }
        RETURN nodes, relations, collect(second_nodes), collect(second_relations)
      CYPHER
    end

    Renderer::Dialect::ALL.each do |dialect|
      it "subquery with rename(#{dialect})" do # GH-319
        nodes = Cypher.name(:nodes)
        relations = Cypher.name(:relations)

        first_path = Cypher.path(:p).defined_by(Cypher.node('Target').relationship_from(Cypher.any_node, 'REL'))

        complete_statement = Cypher.match(first_path)
                                   .with(Cypher.nodes(first_path).as(nodes), Cypher.relationships(first_path).as(relations))
                                   .call(Cypher.returning(Cypher.name(:x)).build, nodes.as(:x))
                                   .returning(Cypher.asterisk)
                                   .build

        renderer = Renderer.get_renderer(Renderer::Configuration.new_config.with_dialect(dialect).with_pretty_print(true).build)
        expected = <<~CYPHER.chomp
          MATCH p = (:Target)<-[:REL]-()
          WITH nodes(p) AS nodes, relationships(p) AS relations
          CALL {
            WITH nodes
            WITH nodes AS x
            RETURN x
          }
          RETURN *
        CYPHER
        unless Renderer::Dialect::LEGACY_SUBQUERY_SYNTAX.include?(dialect)
          expected = expected.sub('CALL {', 'CALL (nodes) {').sub("  WITH nodes\n", '')
        end
        expect(renderer.render(complete_statement)).to eq("#{Renderer::Dialect::PREFIXES[dialect]}#{expected}")
      end
    end

    it 'subquery without import' do # GH-319
      nodes = Cypher.name(:nodes)
      relations = Cypher.name(:relations)

      first_path = Cypher.path(:p).defined_by(Cypher.node('Target').relationship_from(Cypher.any_node, 'REL'))

      complete_statement = Cypher.match(first_path)
                                 .with(Cypher.nodes(first_path).as(nodes), Cypher.relationships(first_path).as(relations))
                                 .call(Cypher.returning(Cypher.literal_of(1)).build)
                                 .returning(Cypher.literal_true)
                                 .build

      expect(pretty.render(complete_statement)).to eq(<<~CYPHER.chomp)
        MATCH p = (:Target)<-[:REL]-()
        WITH nodes(p) AS nodes, relationships(p) AS relations
        CALL (*) {
          RETURN 1
        }
        RETURN true
      CYPHER

      legacy = Renderer.get_renderer(Renderer::Configuration.new_config.with_pretty_print(true).with_dialect(Renderer::Dialect::NEO4J_4).build)
      expect(legacy.render(complete_statement)).to eq(<<~CYPHER.chomp)
        MATCH p = (:Target)<-[:REL]-()
        WITH nodes(p) AS nodes, relationships(p) AS relations
        CALL {
          RETURN 1
        }
        RETURN true
      CYPHER
    end

    it 'allow procedure call without result' do # GH-349
      n = Cypher.any_node(:n)
      statement = Cypher.match(n)
                        .call('apoc.util.validate')
                        .with_args(Cypher.exists(n.property(:foo)).not, Cypher.literal_of('Error'), Cypher.list_of)
                        .without_results
                        .returning(n)
                        .build
      expect(statement.cypher).to eq("MATCH (n) CALL apoc.util.validate(n.foo IS NULL, 'Error', []) RETURN n")
    end

    it 'allow procedure call without result and arguments' do # GH-349
      n = Cypher.any_node(:n)
      statement = Cypher.match(n).call('apoc.util.validate').without_results.returning(n).build
      expect(statement.cypher).to eq('MATCH (n) CALL apoc.util.validate() RETURN n')
    end

    it 'wild validate' do # GH-349
      this0 = Cypher.node('Movie').named(:this0)

      validation_condition = Cypher.any(:r)
                                   .in(Cypher.list_of(Cypher.literal_of('admin')))
                                   .where(Cypher.any(:rr)
                                                .in(Cypher.parameter('$auth.roles'))
                                                .where(SymbolicName.of('r').eq(SymbolicName.of('rr'))))

      g = Cypher.node('Genre')
                .named(:this0_genres_connectOrCreate0)
                .with_properties(Cypher.map_of('name', Cypher.parameter(:this0_genres_connectOrCreate0_node_name)))

      inner_subquery = Cypher.call('apoc.util.validate')
                             .with_args(validation_condition.not, Cypher.literal_of('@neo4j/graphql/FORBIDDEN'), Cypher.list_of(Cypher.literal_of(0)))
                             .without_results
                             .merge(g)
                             .on_create
                             .set(g.property(:name).to(Cypher.parameter(:this0_genres_connectOrCreate0_on_create_name)))
                             .merge(this0.relationship_to(g, 'IN_GENRE').named(:this0_relationship_this0_genres_connectOrCreate0))
                             .returning(Cypher.count(Cypher.asterisk))
                             .build

      subquery = Cypher.create(this0)
                       .set(this0.property(:title).to(Cypher.parameter(:this0_title)))
                       .with(this0)
                       .call(inner_subquery, this0)
                       .returning(this0)
                       .build

      statement = Cypher.call(subquery)
                        .returning(Cypher.list_of(Cypher.create_projection(this0.required_symbolic_name, 'title')).as(:data))
                        .build

      renderer = Renderer.get_renderer(Renderer::Configuration.new_config.always_escape_names(false).build)
      expect(renderer.render(statement)).to eq(
        "CALL () {CREATE (this0:Movie) SET this0.title = $this0_title WITH this0 CALL (this0) {CALL apoc.util.validate(NOT (any(r IN ['admin'] WHERE any(rr IN $auth.roles WHERE r = rr))), '@neo4j/graphql/FORBIDDEN', [0]) MERGE (this0_genres_connectOrCreate0:Genre {name: $this0_genres_connectOrCreate0_node_name}) ON CREATE SET this0_genres_connectOrCreate0.name = $this0_genres_connectOrCreate0_on_create_name MERGE (this0)-[this0_relationship_this0_genres_connectOrCreate0:IN_GENRE]->(this0_genres_connectOrCreate0) RETURN count(*)} RETURN this0} RETURN [this0{.title}] AS data"
      )
    end

    it 'add labels' do # GH-1193
      user = Cypher.node('User').named(:n)
      statement = Cypher.match(user).set(Cypher.set_label(user, 'Cool', 'Person')).returning(user).build
      expect(statement.cypher).to eq('MATCH (n:`User`) SET n:`Cool`:`Person` RETURN n')
    end

    it 'test multi pattern element exist' do # GH-1186
      user = Cypher.node('user').named(:T1)
      dept = Cypher.node('dept').named(:T2)
      parent_dept = Cypher.node('dept').named(:T3)
      statement = Cypher.match(user)
                        .where(Cypher.exists([user.relationship_to(dept, 'dept_id'), dept.relationship_to(parent_dept, 'parent_id')]))
                        .returning(user)
                        .build
      expect(statement.cypher).to eq(
        'MATCH (T1:`user`) WHERE EXISTS { (T1)-[:`dept_id`]->(T2:`dept`), (T2)-[:`parent_id`]->(T3:`dept`) } RETURN T1'
      )
    end

    it 'node needs to be rendered twice with patterns in condition' do # GH-362
      n = Cypher.node('Node').named(:n)
      p = Cypher.any_node(:p)
      x = Cypher.name(:x)
      cond1 = Cypher.none(p.required_symbolic_name)
                    .in(x)
                    .where(p.relationship_to(Cypher.any_node, 'Y')
                            .as_condition
                            .or(p.relationship_to(Cypher.any_node, 'Z').as_condition))
      cond2 = Cypher.any(p.required_symbolic_name)
                    .in(x)
                    .where(p.property(:bar).eq(Cypher.literal_true))
      s = Cypher.match(n)
                .with(Cypher.collect(n).as(x))
                .where(cond1.and(cond2))
                .returning(Cypher.count(n))
                .build
      expect(s.cypher).to eq(
        'MATCH (n:`Node`) WITH collect(n) AS x WHERE (none(p IN x WHERE ((p)-[:`Y`]->() OR (p)-[:`Z`]->())) AND any(p IN x WHERE p.bar = true)) RETURN count(n)'
      )
    end

    it 'compound condition should be immutable as stated in the docs' do # GH-350
      n = Cypher.any_node(:n)
      a = Cypher.no_condition
      a = a.and(n.property(:b).eq(Cypher.literal_of(1)))
      temp = a
      a.and(n.property(:c).eq(Cypher.literal_of(2)))
      statement = Cypher.match(n).where(temp).returning(n).build
      expect(statement.cypher).to eq('MATCH (n) WHERE n.b = 1 RETURN n')
    end

    it 'renders correct date time call' do # GH-389
      datetime = Cypher.datetime(Cypher.map_of('year', 2022, 'month', 6, 'day', 19, 'hour', 15, 'minute', 47, 'second', 38,
                                               'nanosecond', 590_917_308, 'timezone', 'UTC'))
      expect(Cypher.returning(datetime).build.cypher).to eq(
        "RETURN datetime({year: 2022, month: 6, day: 19, hour: 15, minute: 47, second: 38, nanosecond: 590917308, timezone: 'UTC'})"
      )
    end

    describe 'set operations on a node with a map' do # GH-388
      let(:node) { Cypher.node('CordraObject').named(:existingNode).with_properties('_id', Cypher.literal_of('test/55de0539eb1e14f26a04')) }
      let(:new_map) do
        Cypher.map_of('_id', Cypher.literal_of('test/55de0539eb1e14f26a04'), '_type', Cypher.literal_of('Movie'),
                      'title', Cypher.literal_of('Top Gun'), 'released', Cypher.literal_of(1986))
      end
      let(:expected) do
        <<~CYPHER.chomp
          MERGE (existingNode:CordraObject {
            _id: 'test/55de0539eb1e14f26a04'
          })
          SET existingNode = {
            _id: 'test/55de0539eb1e14f26a04',
            _type: 'Movie',
            title: 'Top Gun',
            released: 1986
          }
          RETURN existingNode
        CYPHER
      end

      it 'renders set op on node with map' do
        statement = Cypher.merge(node).set(node, new_map).returning(node).build
        expect(pretty.render(statement)).to eq(expected)
      end

      it 'provides set operations' do
        statement = Cypher.merge(node).set(node.set(new_map)).returning(node).build
        expect(pretty.render(statement)).to eq(expected)
      end
    end
  end
end
