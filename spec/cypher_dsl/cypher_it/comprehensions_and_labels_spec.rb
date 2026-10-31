# frozen_string_literal: true

# Translated from CypherIT.java, nested classes ListComprehensions, PatternComprehensions and
# MultipleLabels.
module CypherDSL
  RSpec.describe 'CypherIT / ListComprehensions' do
    let(:renderer) { Renderer.default }
    let(:one_to_four) { Cypher.list_of(Cypher.literal_of(1), Cypher.literal_of(2), Cypher.literal_of(3), Cypher.literal_of(4)) }

    it 'simple' do
      name = Cypher.name(:a)
      statement = Cypher.returning(Cypher.list_with(name).in(one_to_four).returning).build
      expect(renderer.render(statement)).to eq('RETURN [a IN [1, 2, 3, 4]]')
    end

    it 'with returning' do
      name = Cypher.name(:a)
      statement = Cypher.returning(Cypher.list_with(name).in(one_to_four).returning(name.remainder(Cypher.literal_of(2)))).build
      expect(renderer.render(statement)).to eq('RETURN [a IN [1, 2, 3, 4] | (a % 2)]')
    end

    it 'with where' do
      name = Cypher.name(:a)
      statement = Cypher.returning(Cypher.list_with(name).in(one_to_four).where(name.gt(Cypher.literal_of(2))).returning).build
      expect(renderer.render(statement)).to eq('RETURN [a IN [1, 2, 3, 4] WHERE a > 2]')
    end

    it 'with where and returning' do
      name = Cypher.name(:a)
      statement = Cypher
                  .returning(Cypher.list_with(name)
                                   .in(one_to_four)
                                   .where(name.gt(Cypher.literal_of(2)))
                                   .returning(name.remainder(Cypher.literal_of(2))))
                  .build
      expect(renderer.render(statement)).to eq('RETURN [a IN [1, 2, 3, 4] WHERE a > 2 | (a % 2)]')
    end

    it 'simple with collection' do # GH-189
      name = Cypher.name(:a)
      expressions = [Cypher.literal_of(1), Cypher.literal_of(2), Cypher.literal_of(3), Cypher.literal_of(4)]
      statement = Cypher.returning(Cypher.list_with(name).in(Cypher.list_of(expressions)).returning).build
      expect(renderer.render(statement)).to eq('RETURN [a IN [1, 2, 3, 4]]')
    end

    it 'docs example' do
      name = Cypher.name(:x)

      statement = Cypher
                  .returning(Cypher.list_with(name)
                                   .in(Cypher.range(Cypher.literal_of(0), Cypher.literal_of(10)))
                                   .where(name.remainder(Cypher.literal_of(2)).is_equal_to(Cypher.literal_of(0)))
                                   .returning(name.pow(Cypher.literal_of(3)))
                                   .as(:result))
                  .build
      expect(renderer.render(statement)).to eq('RETURN [x IN range(0, 10) WHERE (x % 2) = 0 | x^3] AS result')

      statement = Cypher
                  .returning(Cypher.list_with(name)
                                   .in(Cypher.range(Cypher.literal_of(0), Cypher.literal_of(10)))
                                   .where(name.remainder(Cypher.literal_of(2)).is_equal_to(Cypher.literal_of(0)))
                                   .returning
                                   .as(:result))
                  .build
      expect(renderer.render(statement)).to eq('RETURN [x IN range(0, 10) WHERE (x % 2) = 0] AS result')

      statement = Cypher
                  .returning(Cypher.list_with(name)
                                   .in(Cypher.range(Cypher.literal_of(0), Cypher.literal_of(10)))
                                   .returning(name.pow(Cypher.literal_of(3)))
                                   .as(:result))
                  .build
      expect(renderer.render(statement)).to eq('RETURN [x IN range(0, 10) | x^3] AS result')
    end
  end

  RSpec.describe 'CypherIT / PatternComprehensions' do
    let(:renderer) { Renderer.default }

    it 'simple' do
      a = Cypher.node('Person').with_properties('name', Cypher.literal_of('Keanu Reeves')).named(:a)
      b = Cypher.any_node(:b)

      statement = Cypher.match(a)
                        .returning(Cypher.list_based_on(a.relationship_between(b)).returning(b.property(:released)).as(:years))
                        .build
      expect(renderer.render(statement))
        .to eq("MATCH (a:`Person` {name: 'Keanu Reeves'}) RETURN [(a)--(b) | b.released] AS years")
    end

    it 'simple with where' do
      a = Cypher.node('Person').with_properties('name', Cypher.literal_of('Keanu Reeves')).named(:a)
      b = Cypher.any_node(:b)

      statement = Cypher.match(a)
                        .returning(Cypher.list_based_on(a.relationship_between(b))
                                         .where(b.has_labels('Movie'))
                                         .returning(b.property(:released))
                                         .as(:years))
                        .build
      expect(renderer.render(statement))
        .to eq("MATCH (a:`Person` {name: 'Keanu Reeves'}) RETURN [(a)--(b) WHERE b:`Movie` | b.released] AS years")
    end

    it 'nested' do
      n = Cypher.node('Person').named(:n)
      o1 = Cypher.node('Organisation').named(:o1)
      l1 = Cypher.node('Location').named(:l1)
      p2 = Cypher.node('Person').named(:p2)

      r_f1 = n.relationship_to(o1, 'FOUNDED').named(:r_f1)
      r_e1 = n.relationship_to(o1, 'EMPLOYED_BY').named(:r_e1)
      r_l1 = n.relationship_to(l1, 'LIVES_AT').named(:r_l1)
      r_l2 = l1.relationship_from(p2, 'LIVES_AT').named(:r_l2)

      statement = Cypher.match(n)
                        .returning(n.required_symbolic_name,
                                   Cypher.list_of(Cypher.list_based_on(r_f1).returning(r_f1, o1),
                                                  Cypher.list_based_on(r_e1).returning(r_e1, o1),
                                                  Cypher.list_based_on(r_l1)
                                                        .returning(r_l1.required_symbolic_name, l1.required_symbolic_name,
                                                                   # The building of the statement works with and without the outer list,
                                                                   # I'm not sure if it would be necessary for the result, but as I took
                                                                   # the query from Neo4j-OGM, I'd like to keep it
                                                                   Cypher.list_of(Cypher.list_based_on(r_l2).returning(r_l2, p2)))))
                        .build

      expect(renderer.render(statement)).to eq(
        'MATCH (n:`Person`) RETURN n, [[(n)-[r_f1:`FOUNDED`]->(o1:`Organisation`) | [r_f1, o1]], [(n)-[r_e1:`EMPLOYED_BY`]->(o1:`Organisation`) | [r_e1, o1]], [(n)-[r_l1:`LIVES_AT`]->(l1:`Location`) | [r_l1, l1, [[(l1)<-[r_l2:`LIVES_AT`]-(p2:`Person`) | [r_l2, p2]]]]]]'
      )
    end
  end

  RSpec.describe 'CypherIT / MultipleLabels' do
    let(:renderer) { Renderer.default }

    it 'match with multiple labels' do
      node = Cypher.node('a', 'b', 'c').named(:n)
      statement = Cypher.match(node).returning(node).build

      expect(renderer.render(statement)).to eq('MATCH (n:`a`:`b`:`c`) RETURN n')
    end

    it 'create with multiple labels' do
      node = Cypher.node('a', 'b', 'c').named(:n)
      statement = Cypher.create(node).build

      expect(renderer.render(statement)).to eq('CREATE (n:`a`:`b`:`c`)')
    end
  end
end
