# frozen_string_literal: true

# Translated from StatementCatalogBuildingVisitorTests.java.
#
# Adapted: the catalog of labels, properties, filters, relations and literals is not
# implemented; of those examples only the rendering assertions are kept
# (`simpleShowCase`, `labelFiltersShouldWork`, `literalRetrievalShouldWork`). The repeated
# `random_order_test` runs once.
module CypherDSL
  RSpec.describe 'StatementCatalogBuildingVisitorTests' do
    it 'simple show case' do
      p = Cypher.node('Person').named(:p)
      m = Cypher.node('Movie').named(:m)
      a = m.with_properties('title', Cypher.literal_of('The Matrix')).relationship_from(p, 'ACTED_IN').named(:a)
      statement = Cypher.match(a)
                        .where(p.property(:born).gte(Cypher.parameter(:born, 1979)))
                        .returning(p)
                        .build
      expect(statement.cypher).to eq(
        "MATCH (m:`Movie` {title: 'The Matrix'})<-[a:`ACTED_IN`]-(p:`Person`) WHERE p.born >= $born RETURN p"
      )
      expect(statement.catalog.parameters).to eq('born' => 1979)
    end

    it 'label filters should work' do
      n = Cypher.node('Person').with_properties('name', Cypher.literal_of('John Doe')).named(:n)
      m = Cypher.node('Person').named(:m)
      statement = Cypher.match(n.relationship_to(m, 'IS_FRIEND_WITH'))
                        .where(n.has_labels('Active'))
                        .and(m.has_labels('Kind', 'Positive').and(m.property(:name).eq(Cypher.literal_of('Jane'))))
                        .returning(Cypher.asterisk)
                        .build
      expect(statement.cypher).to eq(
        "MATCH (n:`Person` {name: 'John Doe'})-[:`IS_FRIEND_WITH`]->(m:`Person`) WHERE (n:`Active` AND m:`Kind`:`Positive` AND m.name = 'Jane') RETURN *"
      )
    end

    it 'literal retrieval should work' do # GH-738
      x = Cypher.name(:x)
      stmt = Cypher.using_periodic_commit
                   .load_csv('https://test.com/test.csv')
                   .as(:x)
                   .with(:x)
                   .merge(Cypher.any_node(:n).with_properties('x', x))
                   .on_create
                   .set(x.property(:y).to(Cypher.literal_null), x.property(:a).to(Cypher.literal_of('Hallo')))
                   .on_create
                   .set(x.property(:b).to(Cypher.sub_list(Cypher.list_of(Cypher.literal_true), 1, 2)))
                   .returning(Cypher.raw('x'))
                   .build
      expect(stmt.cypher).to eq(
        "USING PERIODIC COMMIT LOAD CSV FROM 'https://test.com/test.csv' AS x WITH x MERGE (n {x: x}) ON CREATE SET x.y = NULL, x.a = 'Hallo' ON CREATE SET x.b = [true][1..2] RETURN x"
      )
    end

    it 'random order test' do
      renderer_config = Renderer::Configuration.new_config.with_dialect(Renderer::Dialect::NEO4J_5).with_pretty_print(true).build
      renderer = Renderer.get_renderer(renderer_config)
      person = Cypher.node('Person').named(:n)
      movie = Cypher.node('Movie').named(:m)
      rel = person.relationship_to(movie).named(:r)
      inner_statement = Cypher.match(rel).returning(person, rel, movie).build
      graph_name = Cypher.name(:__graph__name__)
      statement = Cypher.unwind(Cypher.graph_names)
                        .as(graph_name)
                        .call(Cypher.use(Cypher.graph_by_name(graph_name), inner_statement))
                        .returning(inner_statement.catalog.identifiable_expressions)
                        .build
      expect(renderer.render(statement)).to eq(<<~CYPHER.chomp)
        UNWIND graph.names() AS __graph__name__
        CALL {
          USE graph.byName(__graph__name__)
          MATCH (n:Person)-[r]->(m:Movie)
          RETURN n, r, m
        }
        RETURN n, r, m
      CYPHER
    end

    it 'null parameters must be allowed' do # GH-785
      statement = Cypher.match(Cypher.any_node(:n))
                        .where(Cypher.property(:n, :whatever).is_equal_to(Cypher.parameter(:foo, nil)))
                        .returning(Cypher.asterisk)
                        .build
      expect(statement.cypher).to eq('MATCH (n) WHERE n.whatever = $foo RETURN *')
      expect(statement.catalog.parameters).to include('foo' => nil)
    end
  end
end
