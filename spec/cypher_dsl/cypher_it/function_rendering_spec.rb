# frozen_string_literal: true

# Translated from CypherIT.java, nested class FunctionRendering.
#
# Skipped for now:
# - functionsBasedOnRelationships: needs `any_shortest().named(p).defined_by(…)` (path patterns, pending).
module CypherDSL
  RSpec.describe 'CypherIT / FunctionRendering' do
    let(:user_node) { Cypher.node('User').named(:u) }
    let(:renderer) { Renderer.default }

    it 'inWhereClause' do
      statement = Cypher.match(user_node)
                        .where(user_node.internal_id.is_equal_to(Cypher.literal_of(1)))
                        .returning(user_node)
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) WHERE id(u) = 1 RETURN u')
    end

    it 'inReturnClause' do
      statement = Cypher.match(user_node).returning(Cypher.count(user_node)).build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) RETURN count(u)')
    end

    it 'inReturnClauseBasedOnExpressionCollection' do # GH-195
      statement = Cypher.match(user_node)
                        .returning([Cypher.count(user_node)])
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) RETURN count(u)')
    end

    it 'inDistinctReturnClauseBasedOnExpressionCollection' do # GH-195
      statement = Cypher.match(user_node)
                        .returning_distinct([Cypher.count(user_node)])
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) RETURN DISTINCT count(u)')
    end

    it 'inReturnClauseWithDistinct' do
      statement = Cypher.match(user_node).returning(Cypher.count_distinct(user_node)).build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) RETURN count(DISTINCT u)')
    end

    it 'aliasedInReturnClause' do
      statement = Cypher.match(user_node).returning(Cypher.count(user_node).as(:cnt)).build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) RETURN count(u) AS cnt')
    end

    it 'shouldSupportMoreThanOneArgument' do
      statement = Cypher.match(user_node)
                        .returning(Cypher.coalesce(user_node.property(:a), user_node.property(:b),
                                                   Cypher.literal_of('¯\\_(ツ)_/¯')))
                        .build

      expect(renderer.render(statement)).to eq("MATCH (u:`User`) RETURN coalesce(u.a, u.b, '¯\\\\_(ツ)_/¯')")
    end

    it 'literalsShouldDealWithNull' do
      statement = Cypher.match(user_node)
                        .returning(Cypher.coalesce(Cypher.literal_of(nil), user_node.property(:field)).as(:p))
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) RETURN coalesce(NULL, u.field) AS p')
    end
  end
end
