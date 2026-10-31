# frozen_string_literal: true

# Translated from IssueRelatedIT.java, sixth slice (GH-1014 … Chaining).
#
# Adapted: the `GeneratedNames` enum sets of `reusingAliases` are spelled out as flag lists.
module CypherDSL
  RSpec.describe 'IssueRelatedIT (6)' do
    let(:pretty) { Renderer.get_renderer(Renderer::Configuration.pretty_printing) }

    it 'pattern expression must not introduce names' do # GH-1014
      user_id_param = Cypher.parameter(:userId)

      book = Cypher.node('Book').named(:b)
      user_activity = Cypher.node('UserSuggestionActivity').named(:ua).with_properties('userId', user_id_param)

      # ua has not been used before
      rel = book.relationship_between(user_activity)
      cypher = Cypher.match(book)
                     .where(Cypher.not(Cypher.exists(rel)))
                     .returning(Cypher.asterisk)
                     .build
                     .cypher

      expect(cypher).to eq('MATCH (b:`Book`) WHERE NOT (exists((b)--(:`UserSuggestionActivity` {userId: $userId}))) RETURN *')

      # b has not been used before
      cypher = Cypher.match(user_activity)
                     .where(Cypher.not(Cypher.exists(rel)))
                     .returning(Cypher.asterisk)
                     .build
                     .cypher

      expect(cypher).to eq('MATCH (ua:`UserSuggestionActivity` {userId: $userId}) WHERE NOT (exists((:`Book`)--(ua))) RETURN *')

      # Both have been used before, example does not make much sense, but still
      cypher = Cypher.match(book.relationship_from(user_activity, 'WROTE'))
                     .where(Cypher.not(Cypher.exists(rel)))
                     .returning(Cypher.asterisk)
                     .build
                     .cypher

      expect(cypher).to eq('MATCH (b:`Book`)<-[:`WROTE`]-(ua:`UserSuggestionActivity` {userId: $userId}) WHERE NOT (exists((b)--(ua))) RETURN *')

      # All expressions
      cypher = Cypher.match(book).returning(Cypher.size(rel)).build.cypher

      expect(cypher).to eq('MATCH (b:`Book`) RETURN size((b)--(:`UserSuggestionActivity` {userId: $userId}))')
    end

    it 'generated names with deeply nested subqueries' do
      m = Cypher.node('Movie').named(:this)
      a = Cypher.node('Actor').named(:this1)
      edge = Cypher.name(:edge)
      this1 = Cypher.name(:this1)
      edges = Cypher.name(:edges)
      stmt = Cypher.match(m)
                   .call(Cypher.match(m.relationship_from(a, 'ACTED_IN').named(:this0))
                               .with(Cypher.collect(Cypher.map_of('node', this1)).as(edges))
                               .with(edges, Cypher.size(edges).as(:totalCount))
                               .call(Cypher.unwind(edges)
                                           .as(edge)
                                           .with(edge.property(:node).as(this1))
                                           .call(Cypher.match(Cypher.any_node(this1)
                                                                    .relationship_to(Cypher.node('Movie').named(:this3), 'ACTED_IN')
                                                                    .named(:this2))
                                                       .returning(Cypher.asterisk)
                                                       .build, this1)
                                           .build, edges)
                               .build, m)
                   .returning(Cypher.asterisk)
                   .build

      legacy = Renderer::Configuration.new_config.with_pretty_print(true).with_generated_names(true).with_dialect(Renderer::Dialect::NEO4J_4).build
      expect(Renderer.get_renderer(legacy).render(stmt)).to eq(<<~CYPHER.chomp)
        MATCH (v0:Movie)
        CALL {
          WITH v0
          MATCH (v0)<-[v1:ACTED_IN]-(v2:Actor)
          WITH collect( {
            node: v2
          }) AS v3
          WITH v3, size(v3) AS v4
          CALL {
            WITH v3
            UNWIND v3 AS v5
            WITH v5.node AS v6
            CALL {
              WITH v6
              MATCH (v6)-[v0:ACTED_IN]->(v1:Movie)
              RETURN *
            }
          }
        }
        RETURN *
      CYPHER

      current = Renderer::Configuration.new_config.with_pretty_print(true).with_generated_names(true).build
      expect(Renderer.get_renderer(current).render(stmt)).to eq(<<~CYPHER.chomp)
        MATCH (v0:Movie)
        CALL (v0) {
          MATCH (v0)<-[v1:ACTED_IN]-(v2:Actor)
          WITH collect( {
            node: v2
          }) AS v3
          WITH v3, size(v3) AS v4
          CALL (v3) {
            UNWIND v3 AS v5
            WITH v5.node AS v6
            CALL (v6) {
              MATCH (v6)-[v0:ACTED_IN]->(v1:Movie)
              RETURN *
            }
          }
        }
        RETURN *
      CYPHER
    end

    {
      'MATCH (movie:`Movie`) RETURN movie{.a, .b} AS movie' => nil,
      'MATCH (v0:`Movie`) RETURN v0{.a, .b} AS v1' => %i[entity_names all_aliases internal_aliases_only parameter_names],
      'MATCH (v0:`Movie`) RETURN v0{.a, .b} AS v0' => %i[entity_names all_aliases internal_aliases_only parameter_names reuse_aliases]
    }.each do |expected, generated_names|
      it "reusing aliases: #{expected}" do # GH-1084
        config = Renderer::Configuration.new_config
        config = config.with_generated_names(generated_names) if generated_names
        renderer = Renderer.get_renderer(config.build)

        movie = Cypher.node('Movie').named(:movie)
        cypher = renderer.render(Cypher.match(movie).returning(movie.project('a', 'b').as(:movie)).build)
        expect(cypher).to eq(expected)
      end
    end

    it 'list comprehensions based on relationships must work' do # GH-1113
      another_node = Cypher.node('AnotherNode').named(:n)
      movie = Cypher.node('Movie').named(:m)

      refers_to = movie.relationship_from(another_node, 'HAS_RELATION')
      stmt = Cypher.match(movie)
                   .where(movie.property(:name).is_equal_to(Cypher.literal_of('star')))
                   .returning_distinct(Cypher.list_based_on(refers_to).returning(Cypher.name(:n)))
                   .build
      expect(stmt.cypher).to eq("MATCH (m:`Movie`) WHERE m.name = 'star' RETURN DISTINCT [(m)<-[:`HAS_RELATION`]-(n:`AnotherNode`) | n]")
    end

    it 'call raw cypher followed by where must work' do
      cypher = Cypher.call_raw_cypher('MATCH (n:Movie) RETURN n')
                     .with(Cypher.asterisk)
                     .where(Cypher.property(:n, :title).eq(Cypher.literal_of('The Matrix')))
                     .returning(Cypher.asterisk)
                     .build
                     .cypher
      expect(cypher).to eq("CALL () {MATCH (n:Movie) RETURN n} WITH * WHERE n.title = 'The Matrix' RETURN *")
    end

    it 'call cypher followed by where must work' do
      cypher = Cypher.call(Cypher.match(Cypher.node('Movie').named(:n)).returning(Cypher.name(:n)).build)
                     .with(Cypher.asterisk)
                     .where(Cypher.property(:n, :title).eq(Cypher.literal_of('The Matrix')))
                     .returning(Cypher.asterisk)
                     .build
                     .cypher
      expect(cypher).to eq("CALL () {MATCH (n:`Movie`) RETURN n} WITH * WHERE n.title = 'The Matrix' RETURN *")
    end

    it 'call raw cypher followed by where without with must throw good exception' do
      buildable_subquery = Cypher.call_raw_cypher('MATCH (n:Movie) RETURN n')
      true_condition = Cypher.is_true
      expect { buildable_subquery.where(true_condition) }
        .to raise_error(ArgumentError, 'A CALL{} clause requires to WITH before you can add further conditions')
    end

    it 'case parsing and rendering should work' do # GH-1235
      node = Cypher.node('Node').named(:n)
      query = Cypher.match(node)
                    .returning(Cypher.case_expression(node.property(:prop))
                                     .when(Cypher.literal_of('A'))
                                     .then(Cypher.literal_of(1))
                                     .else_default(Cypher.literal_of(2)))
                    .build

      expect(query.cypher).to eq("MATCH (n:`Node`) RETURN CASE n.prop WHEN 'A' THEN 1 ELSE 2 END")
    end

    it 'as condition should work with multiple matches too' do # GH-1313
      me = Cypher.node('User').named(:me).with_properties(Cypher.map_of('id', Cypher.parameter(:userId)))
      c = Cypher.node('Company').named(:c)
      my_company = Cypher.node('Company').named(:myCompany)
      is_admin = Cypher.match(me.relationship_to(Cypher.node('Role').with_properties(Cypher.map_of('name', Cypher.literal_of('Admin'))), 'HAS_ROLE'))
                       .as_condition
                       .as(:isAdmin)
      stmt = Cypher.match(me)
                   .with(me, is_admin)
                   .match(c)
                   .where(is_admin.as_condition
                                  .or(Cypher.match(me.relationship_to(my_company, 'WORKdS_FOR'))
                                            .match(my_company.relationship_to(c, 'PARENT_OF'))
                                            .as_condition))
                   .returning(c)
                   .build

      expect(pretty.render(stmt)).to eq(<<~CYPHER.chomp)
        MATCH (me:User {
          id: $userId
        })
        WITH me, EXISTS {
          MATCH (me)-[:HAS_ROLE]->(:Role {
            name: 'Admin'
          })
        } AS isAdmin
        MATCH (c:Company)
        WHERE (isAdmin
          OR EXISTS {
            MATCH (me)-[:WORKdS_FOR]->(myCompany:Company)
            MATCH (myCompany)-[:PARENT_OF]->(c)
          })
        RETURN c
      CYPHER
    end

    Renderer::Dialect::ALL.each do |dialect|
      it "labels expression must be left from all label handlers (#{dialect})" do # GH-1404
        stmt = Cypher.match(Cypher.node(Labels.exactly('Purchase_orders').or(Labels.exactly('Another')))
                                  .named(:po)
                                  .relationship_from(Cypher.node('Material').named(:m), 'IS_PURCHASED'))
                     .returning(Cypher.name(:m))
                     .build
        renderer = Renderer.get_renderer(Renderer::Configuration.new_config.with_dialect(dialect).build)
        expect(renderer.render(stmt)).to end_with('MATCH (po:`Purchase_orders`|`Another`)<-[:`IS_PURCHASED`]-(m:`Material`) RETURN m')
      end
    end

    describe 'Chaining' do
      it 'after yielding calls' do
        statement_part1 = Cypher.call('db.index.vector.queryNodes')
                                .with_args(Cypher.parameter(:indexName), Cypher.parameter(:numberOfNearestNeighbours), Cypher.parameter(:embeddingValue))
                                .yield(:node, :score)

        # statement 2
        node = Cypher.any_node.named(:node)
        related_node = Cypher.any_node.named(:relatedNode)
        relationship = node.relationship_to(related_node, 'CONNECTED_TO')
        statement_part2 = Cypher.match(relationship).returning(related_node.property(:value).as(:value))

        new_statement = statement_part1.and_then(statement_part2.build).build

        expect(new_statement.cypher.squeeze(' ')).to eq(<<~CYPHER.tr("\n", ' ').strip)
          CALL db.index.vector.queryNodes($indexName, $numberOfNearestNeighbours, $embeddingValue)
          YIELD node, score
          MATCH (node)-[:`CONNECTED_TO`]->(relatedNode) RETURN relatedNode.value AS value
        CYPHER
      end
    end
  end
end
