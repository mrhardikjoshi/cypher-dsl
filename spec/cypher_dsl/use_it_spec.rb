# frozen_string_literal: true

# Translated from UseIT.java.
#
# Adapted: the Java overloads `use(StringLiteral, …)` / `use(Parameter, …)` / `use(Expression, …)`
# are the single `Cypher.use(expression, statement)`; `DecoratedQuery` errors are ArgumentErrors.
module CypherDSL
  RSpec.describe 'UseIT' do
    let(:renderer) { Renderer.get_renderer(Renderer::Configuration.new_config.with_dialect(Renderer::Dialect::NEO4J_5).build) }
    let(:ongoing_inner_statement_definition) do
      Cypher.call(Cypher.match(Cypher.node('Movie').named(:movie)).returning(:movie).build).returning(:movie)
    end

    # `simpleUseShouldWork` (plain strings) and `graphByNameShouldWork` (expressions) share one table.
    {
      'myDatabase' => 'USE myDatabase MATCH (n) RETURN n',
      'myComposite.myConstituent' => 'USE myComposite.myConstituent MATCH (n) RETURN n',
      Cypher.literal_of('myComposite.myConstituent') => "USE graph.byName('myComposite.myConstituent') MATCH (n) RETURN n",
      Cypher.parameter(:graphName) => 'USE graph.byName($graphName) MATCH (n) RETURN n'
    }.each do |target, expected|
      it "simple use / graph by name should work(#{target})" do
        statement = Cypher.match(Cypher.any_node(:n)).returning(:n).build
        expect(Cypher.use(target, statement).cypher).to eq(expected)
      end
    end

    it 'usage in subquery should work' do
      expected = <<~CYPHER.lines.map(&:strip).join(' ').gsub('CALL (*) { ', 'CALL (*) {').gsub(' }', '}')
        UNWIND ['cineasts.latest', 'cineasts.upcoming'] AS graphName
        CALL (*) {
        USE graph.byName(graphName)
          MATCH (movie:`Movie`)
          RETURN movie
        }
        RETURN movie.title AS title
      CYPHER

      inner_statement = Cypher.match(Cypher.node('Movie').named(:movie)).returning(:movie).build
      cypher = Cypher.unwind(Cypher.literal_of(['cineasts.latest', 'cineasts.upcoming']))
                     .as(:graphName)
                     .call(Cypher.use(Cypher.name(:graphName), inner_statement))
                     .returning(Cypher.name(:movie).property(:title).as(:title))
                     .build
                     .cypher
      expect(cypher).to eq(expected)
    end

    it 'use before call' do
      inner_statement = ongoing_inner_statement_definition.build
      cypher = Cypher.use('cineasts.latest', inner_statement).cypher
      expect(cypher).to eq('USE cineasts.latest CALL () {MATCH (movie:`Movie`) RETURN movie} RETURN movie')
    end

    it 'nested use should throw' do
      inner_statement = Cypher.use('x', ongoing_inner_statement_definition.build)
      expect { Cypher.use('y', inner_statement) }.to raise_error(ArgumentError, 'Nested USE clauses are not supported')
    end

    it 'use before call with call in tx' do
      title = Cypher.name(:title)
      movie = Cypher.node('Movie', Cypher.map_of('title', title)).named(:m)
      inner_statement = Cypher.unwind(Cypher.parameter(:newMovies))
                              .as(title)
                              .call(Cypher.with(title).merge(movie).returning(movie.element_id.as(:id)).build)
                              .returning(:id)
                              .build
      cypher = renderer.render(Cypher.use('cineasts.latest', inner_statement))
      expect(cypher).to eq(
        'USE cineasts.latest UNWIND $newMovies AS title CALL {WITH title MERGE (m:`Movie` {title: title}) RETURN elementId(m) AS id} RETURN id'
      )
    end

    it 'add explain' do
      inner_statement = ongoing_inner_statement_definition.build
      cypher = Cypher.use('cineasts.latest', inner_statement).explain.cypher
      expect(cypher).to eq('EXPLAIN USE cineasts.latest CALL () {MATCH (movie:`Movie`) RETURN movie} RETURN movie')
    end

    it 'inner profile should throw' do
      inner_statement = ongoing_inner_statement_definition.profile
      expect { Cypher.use('x', inner_statement) }
        .to raise_error(ArgumentError, "PROFILE'd statements are not supported inside USE clauses")
    end

    it 'inner explain should throw' do
      inner_statement = ongoing_inner_statement_definition.explain
      expect { Cypher.use('x', inner_statement) }
        .to raise_error(ArgumentError, "EXPLAIN'ed statements are not supported inside USE clauses")
    end
  end
end
