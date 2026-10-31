# frozen_string_literal: true

# Translated from CypherIT.java, nested class FunctionRendering.
module CypherDSL
  RSpec.describe 'CypherIT / FunctionRendering' do
    let(:user_node) { Cypher.node('User').named(:u) }
    let(:renderer) { Renderer.default }

    it 'in where clause' do
      statement = Cypher.match(user_node)
                        .where(user_node.internal_id.is_equal_to(Cypher.literal_of(1)))
                        .returning(user_node)
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) WHERE id(u) = 1 RETURN u')
    end

    it 'in return clause' do
      statement = Cypher.match(user_node).returning(Cypher.count(user_node)).build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) RETURN count(u)')
    end

    it 'in return clause based on expression collection' do # GH-195
      statement = Cypher.match(user_node)
                        .returning([Cypher.count(user_node)])
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) RETURN count(u)')
    end

    it 'in distinct return clause based on expression collection' do # GH-195
      statement = Cypher.match(user_node)
                        .returning_distinct([Cypher.count(user_node)])
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) RETURN DISTINCT count(u)')
    end

    it 'in return clause with distinct' do
      statement = Cypher.match(user_node).returning(Cypher.count_distinct(user_node)).build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) RETURN count(DISTINCT u)')
    end

    it 'aliased in return clause' do
      statement = Cypher.match(user_node).returning(Cypher.count(user_node).as(:cnt)).build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) RETURN count(u) AS cnt')
    end

    it 'supports more than one argument' do
      statement = Cypher.match(user_node)
                        .returning(Cypher.coalesce(user_node.property(:a), user_node.property(:b),
                                                   Cypher.literal_of('¯\\_(ツ)_/¯')))
                        .build

      expect(renderer.render(statement)).to eq("MATCH (u:`User`) RETURN coalesce(u.a, u.b, '¯\\\\_(ツ)_/¯')")
    end

    it 'literals should deal with null' do
      statement = Cypher.match(user_node)
                        .returning(Cypher.coalesce(Cypher.literal_of(nil), user_node.property(:field)).as(:p))
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) RETURN coalesce(NULL, u.field) AS p')
    end

    it 'functions based on relationships' do # GH-257
      expected = "MATCH p = ANY (bacon:`Person` {name: 'Kevin Bacon'})-[*]-(meg:`Person` {name: 'Meg Ryan'}) RETURN p"

      relationship = Cypher.node('Person')
                           .named(:bacon)
                           .with_properties('name', Cypher.literal_of('Kevin Bacon'))
                           .relationship_between(Cypher.node('Person').named(:meg).with_properties('name', Cypher.literal_of('Meg Ryan')))
                           .unbounded
      statement = Cypher.match(Cypher.any_shortest.named(:p).defined_by(relationship))
                        .returning(:p)
                        .build

      expect(renderer.render(statement)).to eq(expected)

      p = Cypher.name(:p)
      statement = Cypher.match(Cypher.any_shortest.named(p).defined_by(relationship)).returning(p).build

      expect(renderer.render(statement)).to eq(expected)
    end
  end
end
