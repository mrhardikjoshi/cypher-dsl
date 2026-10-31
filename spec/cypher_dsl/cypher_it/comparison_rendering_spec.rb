# frozen_string_literal: true

# Translated from CypherIT.java, nested class ComparisonRendering.
module CypherDSL
  RSpec.describe 'CypherIT / ComparisonRendering' do
    let(:user_node) { Cypher.node('User').named(:u) }
    let(:renderer) { Renderer.default }

    it 'equals with string literal' do
      statement = Cypher.match(user_node)
                        .where(user_node.property(:name).is_equal_to(Cypher.literal_of('Test')))
                        .returning(user_node)
                        .build

      expect(renderer.render(statement)).to eq("MATCH (u:`User`) WHERE u.name = 'Test' RETURN u")
    end

    it 'equals with number literal' do
      statement = Cypher.match(user_node)
                        .where(user_node.property(:age).is_equal_to(Cypher.literal_of(21)))
                        .returning(user_node)
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) WHERE u.age = 21 RETURN u')
    end
  end
end
