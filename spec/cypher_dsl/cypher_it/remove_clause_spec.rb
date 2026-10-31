# frozen_string_literal: true

# Translated from CypherIT.java, nested class RemoveClause.
module CypherDSL
  RSpec.describe 'CypherIT / RemoveClause' do
    let(:user_node) { Cypher.node('User').named(:u) }
    let(:renderer) { Renderer.default }

    it 'renders remove on nodes' do
      statement = Cypher.match(user_node).remove(user_node, 'A', 'B').returning(user_node).build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) REMOVE u:`A`:`B` RETURN u')

      statement = Cypher.match(user_node)
                        .with(user_node)
                        .set(user_node, 'A', 'B')
                        .remove(user_node, 'C', 'D')
                        .returning(user_node)
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) WITH u SET u:`A`:`B` REMOVE u:`C`:`D` RETURN u')
    end

    it 'renders remove of properties' do
      statement = Cypher.match(user_node)
                        .remove(user_node.property(:a), user_node.property(:b))
                        .returning(user_node)
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) REMOVE u.a, u.b RETURN u')

      statement = Cypher.match(user_node)
                        .with(user_node)
                        .remove(user_node.property(:a))
                        .remove(user_node.property(:b))
                        .returning(user_node)
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) WITH u REMOVE u.a REMOVE u.b RETURN u')
    end
  end
end
