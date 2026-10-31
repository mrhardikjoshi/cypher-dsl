# frozen_string_literal: true

# Translated from CypherIT.java, nested class PrettyPrinting.
module CypherDSL
  RSpec.describe 'CypherIT / PrettyPrinting' do
    let(:bike_node) { Cypher.node('Bike').named(:b) }
    let(:user_node) { Cypher.node('User').named(:u) }
    let(:pretty_renderer) { Renderer.get_renderer(Renderer::Configuration.pretty_printing) }

    let(:statement) do
      other_node = Cypher.any_node(:other)
      Cypher.match(user_node)
            .where(user_node.property(:name).is_equal_to(Cypher.literal_of('Max')))
            .and(user_node.property(:lastName).is_equal_to(Cypher.literal_of('Mustermann')))
            .and(Cypher.match(user_node.relationship_to(bike_node, 'LIKES'))
                       .where(bike_node.relationship_to(Cypher.any_node, 'LINK'))
                       .or(Cypher.match(bike_node.relationship_to(Cypher.any_node, 'LINK')).as_condition)
                       .as_condition)
            .set(user_node.property(:lastName).to(Cypher.parameter(:newName)))
            .with(user_node)
            .match(bike_node)
            .create(user_node.relationship_to(bike_node, 'LIKES'))
            .with(user_node)
            .call(Cypher.with(user_node)
                        .match(user_node.relationship_to(Cypher.any_node(:x), 'SOMETHING'))
                        .call(Cypher.with(Cypher.any_node(:x))
                                    .match(Cypher.any_node(:x).relationship_to(Cypher.any_node(:y), 'DEEPER'))
                                    .returning(Cypher.any_node(:y).project('bar').as(:bar))
                                    .build)
                        .returning(Cypher.any_node(:x).project('foo', 'bar', Cypher.name(:bar)).as(:anyThing))
                        .build)
            .with(user_node)
            .call(Cypher.use('movies.actors', Cypher.match(Cypher.node('Person').named(:person)).returning(:person).build))
            .with(user_node)
            .returning(user_node.project('name', user_node.property(:name), 'anyThing', Cypher.name(:anyThing), 'nesting1',
                                         Cypher.map_of('name', user_node.property(:name), 'nesting2',
                                                       Cypher.map_of('name', bike_node.property(:name), 'pattern',
                                                                     Cypher.list_based_on(user_node.relationship_to(other_node, 'LIKES'))
                                                                           .where(other_node.property(:foo).is_equal_to(Cypher.parameter(:foo)))
                                                                           .returning(other_node.project('x', 'y'))))))
            .build
    end

    let(:expected_with_spaces) do
      <<~CYPHER.chomp
        MATCH (u:User)
        WHERE (u.name = 'Max'
          AND u.lastName = 'Mustermann'
          AND EXISTS {
            MATCH (u)-[:LIKES]->(b:Bike)
            WHERE ((b)-[:LINK]->()
              OR EXISTS {
                MATCH (b)-[:LINK]->()
              })
          })
        SET u.lastName = $newName
        WITH u
        MATCH (b:Bike)
        CREATE (u)-[:LIKES]->(b)
        WITH u
        CALL (u) {
          MATCH (u)-[:SOMETHING]->(x)
          CALL (x) {
            MATCH (x)-[:DEEPER]->(y)
            RETURN y {
              .bar
            } AS bar
          }
          RETURN x {
            .foo,
            bar: bar
          } AS anyThing
        }
        WITH u
        CALL (*) {
          USE movies.actors
          MATCH (person:Person)
          RETURN person
        }
        WITH u
        RETURN u {
          name: u.name,
          anyThing: anyThing,
          nesting1: {
            name: u.name,
            nesting2: {
              name: b.name,
              pattern: [(u)-[:LIKES]->(other) WHERE other.foo = $foo | other {
                .x,
                .y
              }]
            }
          }
        }
      CYPHER
    end

    it 'escapingNamesShouldBeOptionalInNonPrettyPrintToo' do
      renderer = Renderer.get_renderer(Renderer::Configuration.new_config.always_escape_names(false).build)
      expect(renderer.render(Cypher.match(Cypher.node('Fine').named(:a)).returning(:a).build)).to eq('MATCH (a:Fine) RETURN a')
      expect(renderer.render(Cypher.match(Cypher.node('Not Fine').named(:a)).returning(:a).build))
        .to eq('MATCH (a:`Not Fine`) RETURN a')
    end

    it 'configurationOfIndentWithShouldWork' do
      renderer = Renderer.get_renderer(Renderer::Configuration.new_config.with_pretty_print(true).with_indent_size(5).build)
      rendered = renderer.render(Cypher.match(Cypher.node('Node')).where(Cypher.is_true).and(Cypher.is_false).returning(Cypher.asterisk).build)
      expect(rendered).to eq(<<~CYPHER.chomp)
        MATCH (:Node)
        WHERE (true
             AND false)
        RETURN *
      CYPHER
    end

    it 'prettyPrintingWithDefaultSettingShouldWork' do
      expect(pretty_renderer.render(statement)).to eq(expected_with_spaces)
    end

    it 'prettyPrintingWithTabsShouldWork' do
      renderer = Renderer.get_renderer(Renderer::Configuration.new_config.with_pretty_print(true).with_indent_style(:tab).build)
      expected_with_tabs = expected_with_spaces.gsub(/^(?:  )+/) { |indentation| "\t" * (indentation.size / 2) }
      expect(renderer.render(statement)).to eq(expected_with_tabs)
    end

    # See https://neo4j.com/docs/cypher-manual/current/styleguide/#cypher-styleguide-indentation-and-line-breaks
    it 'onClauses' do
      n = Cypher.any_node(:n)
      a = Cypher.node('A').named(:a)
      b = Cypher.node('B').named(:b)

      merge_statement = Cypher.merge(n)
                              .on_create
                              .set(n.property(:prop).to(Cypher.literal_of(0)))
                              .merge(a.relationship_between(b, 'T'))
                              .on_create
                              .set(a.property(:name).to(Cypher.literal_of('me')))
                              .on_match
                              .set(b.property(:name).to(Cypher.literal_of('you')))
                              .returning(a.property(:prop))
                              .build

      expect(pretty_renderer.render(merge_statement)).to eq(<<~CYPHER.chomp)
        MERGE (n)
          ON CREATE SET n.prop = 0
        MERGE (a:A)-[:T]-(b:B)
          ON CREATE SET a.name = 'me'
          ON MATCH SET b.name = 'you'
        RETURN a.prop
      CYPHER
    end

    it 'singleExistsSubquery' do
      a = Cypher.node('A').named(:a)
      b = Cypher.node('B').named(:b)

      merge_statement = Cypher.match(a)
                              .where(Cypher.match(a.relationship_to(b)).as_condition)
                              .returning(a)
                              .build

      expect(pretty_renderer.render(merge_statement)).to eq(<<~CYPHER.chomp)
        MATCH (a:A)
        WHERE EXISTS {
          MATCH (a)-->(b:B)
        }
        RETURN a
      CYPHER
    end

    it 'multipleSubQueries' do
      a = Cypher.node('A').named(:a)
      b = Cypher.node('B').named(:b)
      c = Cypher.name(:c)

      merge_statement = Cypher.call(Cypher.create(a).returning(a).build)
                              .call(Cypher.create(b).returning(b).build)
                              .unwind(Cypher.list_of(a.required_symbolic_name, b.required_symbolic_name))
                              .as(c)
                              .returning(c.project('name'))
                              .build

      expect(pretty_renderer.render(merge_statement)).to eq(<<~CYPHER.chomp)
        CALL () {
          CREATE (a:A)
          RETURN a
        }
        CALL (*) {
          CREATE (b:B)
          RETURN b
        }
        UNWIND [a, b] AS c
        RETURN c {
          .name
        }
      CYPHER
    end

    it 'prettyPrintingQueryStartingWithSubquery' do
      raw_query = 'MATCH (node) RETURN node'
      node = Cypher.name(:node)
      result_statement = Cypher.call(Cypher.returning_raw(Cypher.raw(raw_query).as(node)).build)
                               .returning(node)
                               .build

      expect(pretty_renderer.render(result_statement)).to eq(<<~CYPHER.chomp)
        CALL () {
          MATCH (node) RETURN node AS node
        }
        RETURN node
      CYPHER
    end
  end
end
