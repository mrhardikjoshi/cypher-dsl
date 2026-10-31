# frozen_string_literal: true

# Translated from CypherIT.java, nested class MapProjections (OnNodes, OnRelationShips).
#
# Adapted: the message of the `invalid` test embeds Java class names upstream; here it is
# matched on its invariant part.
module CypherDSL
  RSpec.describe 'CypherIT / MapProjections' do
    let(:renderer) { Renderer.default }
    let(:neo5j_config) { Renderer::Configuration.new_config.with_dialect(Renderer::Dialect::NEO4J_5).build }

    it 'asterisk' do
      n = Cypher.any_node(:n)

      statement = Cypher.match(n).returning(n.project(Cypher.asterisk)).build
      expect(renderer.render(statement)).to eq('MATCH (n) RETURN n{.*}')
    end

    it 'invalid' do
      n = Cypher.any_node(:n)

      expect { n.project(Cypher.element_id(n)) }
        .to raise_error(ArgumentError, /cannot be used with an implicit name as map entry\.\z/)
      expect { n.project('a', Cypher.map_of('a', Cypher.literal_of('b')), Cypher.element_id(n)) }
        .to raise_error(ArgumentError, /cannot be used with an implicit name as map entry\.\z/)
    end

    describe 'OnNodes' do
      it 'simple' do
        n = Cypher.any_node(:n)

        statement = Cypher.match(n)
                          .returning(n.project('__internalNeo4jId__', Cypher.element_id(n), 'name'))
                          .build
        renderer = Renderer.get_renderer(neo5j_config)
        expect(renderer.render(statement)).to eq('MATCH (n) RETURN n{__internalNeo4jId__: elementId(n), .name}')

        statement = Cypher.match(n)
                          .returning(n.project('name', '__internalNeo4jId__', Cypher.element_id(n)))
                          .build
        expect(renderer.render(statement)).to eq('MATCH (n) RETURN n{.name, __internalNeo4jId__: elementId(n)}')
      end

      it 'doc21221' do
        expected = "MATCH (actor:`Person` {name: 'Tom Hanks'})-[:`ACTED_IN`]->(movie:`Movie`) RETURN actor{.name, .realName, movies: collect(movie{.title, .released})}"

        actor = Cypher.node('Person').named(:actor)
        movie = Cypher.node('Movie').named(:movie)

        statement = Cypher
                    .match(actor.with_properties('name', Cypher.literal_of('Tom Hanks')).relationship_to(movie, 'ACTED_IN'))
                    .returning(actor.project('name', 'realName', 'movies', Cypher.collect(movie.project('title', 'released'))))
                    .build
        expect(renderer.render(statement)).to eq(expected)

        statement = Cypher
                    .match(actor.with_properties('name', Cypher.literal_of('Tom Hanks')).relationship_to(movie, 'ACTED_IN'))
                    .returning(actor.project('name', 'realName', 'movies',
                                             Cypher.collect(movie.project(movie.property(:title), movie.property(:released)))))
                    .build
        expect(renderer.render(statement)).to eq(expected)

        statement = Cypher
                    .match(actor.with_properties('name', Cypher.literal_of('Tom Hanks')).relationship_to(movie, 'ACTED_IN'))
                    .returning(actor.project('name', 'realName', 'movies',
                                             Cypher.collect(movie.project('title', 'year', movie.property(:released)))))
                    .build
        expect(renderer.render(statement)).to eq(
          "MATCH (actor:`Person` {name: 'Tom Hanks'})-[:`ACTED_IN`]->(movie:`Movie`) RETURN actor{.name, .realName, movies: collect(movie{.title, year: movie.released})}"
        )
      end

      it 'nested' do
        n = Cypher.node('Person').named(:p)
        m = Cypher.node('Movie').named(:m)

        statement = Cypher.match(n.relationship_to(m, 'ACTED_IN'))
                          .returning(n.project('__internalNeo4jId__', Cypher.element_id(n), 'name', 'nested',
                                               m.project('title', '__internalNeo4jId__', Cypher.element_id(m))))
                          .build
        expect(Renderer.get_renderer(neo5j_config).render(statement)).to eq(
          'MATCH (p:`Person`)-[:`ACTED_IN`]->(m:`Movie`) RETURN p{__internalNeo4jId__: elementId(p), .name, nested: m{.title, __internalNeo4jId__: elementId(m)}}'
        )
      end

      it 'requiredSymbolicNameShouldBeGenerated' do
        person = Cypher.node('Person')
        statement = Cypher.match(person).returning(person.project('something')).build
        expect(renderer.render(statement))
          .to match(/\AMATCH \([a-zA-Z].*\d{3}:`Person`\) RETURN [a-zA-Z].*\d{3}\{\.something}\z/)
      end

      it 'generatedSymbolicNameMustPreventNodeContentDoubleRenderingAswWell' do
        person = Cypher.node('Person')
        expect(person.required_symbolic_name).not_to be_nil
        movie = Cypher.node('Movie')
        expect(movie.required_symbolic_name).not_to be_nil
        directed = person.relationship_to(movie, 'DIRECTED')
        acted_in = person.relationship_to(movie, 'ACTED_IN')
        statement = Cypher.match(directed).match(acted_in).returning(directed, acted_in).build

        expect(renderer.render(statement)).to match(
          /\AMATCH \(\w+:`Person`\)-\[\w+:`DIRECTED`\]->\(\w+:`Movie`\) MATCH \(\w+\)-\[\w+:`ACTED_IN`\]->\(\w+\) RETURN \w+, \w+\z/
        )
      end

      it 'addedProjections' do
        p = Cypher.node('Person').named(:p)
        m = Cypher.node('Movie').named(:m)
        rel = p.relationship_to(m, 'ACTED_IN').named(:r)

        statement = Cypher.match(rel)
                          .returning(p.project('__internalNeo4jId__', Cypher.element_id(p), 'name')
                                      .and(rel)
                                      .and(m)
                                      .and(p.property(:foo))
                                      .and('a', p.property(:x)))
                          .build
        expect(Renderer.get_renderer(neo5j_config).render(statement)).to eq(
          'MATCH (p:`Person`)-[r:`ACTED_IN`]->(m:`Movie`) RETURN p{__internalNeo4jId__: elementId(p), .name, r, m, .foo, a: p.x}'
        )
      end
    end

    describe 'OnRelationShips' do
      it 'simple' do
        n = Cypher.node('Person').named(:p)
        m = Cypher.node('Movie').named(:m)
        rel = n.relationship_to(m, 'ACTED_IN').named(:r)

        statement = Cypher.match(rel)
                          .returning(rel.project('__internalNeo4jId__', Cypher.element_id(rel), 'roles'))
                          .build
        expect(Renderer.get_renderer(neo5j_config).render(statement)).to eq(
          'MATCH (p:`Person`)-[r:`ACTED_IN`]->(m:`Movie`) RETURN r{__internalNeo4jId__: elementId(r), .roles}'
        )
      end

      it 'nested' do
        n = Cypher.node('Person').named(:p)
        m = Cypher.node('Movie').named(:m)
        rel = n.relationship_to(m, 'ACTED_IN').named(:r)

        statement = Cypher.match(rel)
                          .returning(m.project('title', 'roles',
                                               rel.project('__internalNeo4jId__', Cypher.element_id(rel), 'roles')))
                          .build
        expect(Renderer.get_renderer(neo5j_config).render(statement)).to eq(
          'MATCH (p:`Person`)-[r:`ACTED_IN`]->(m:`Movie`) RETURN m{.title, roles: r{__internalNeo4jId__: elementId(r), .roles}}'
        )
      end

      it 'requiredSymbolicNameShouldBeGenerated' do
        n = Cypher.node('Person')
        m = Cypher.node('Movie')
        rel = n.relationship_to(m, 'ACTED_IN')

        statement = Cypher.match(rel).returning(rel.project('something')).build
        expect(renderer.render(statement)).to match(
          /\AMATCH \(:`Person`\)-\[[a-zA-Z]*\d{3}:`ACTED_IN`\]->\(:`Movie`\) RETURN [a-zA-Z]*\d{3}\{\.something}\z/
        )
      end
    end
  end
end
