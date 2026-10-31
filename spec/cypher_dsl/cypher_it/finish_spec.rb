# frozen_string_literal: true

# Translated from CypherIT.java, nested class Finish.
module CypherDSL
  RSpec.describe 'CypherIT / Finish' do
    let(:user_node) { Cypher.node('User').named(:u) }
    let(:renderer) { Renderer.default }

    it 'finish after match' do
      statement = Cypher.match(user_node).finish.build
      expect(renderer.render(statement)).to eq('MATCH (u:`User`) FINISH')
    end

    it 'finish after match with where' do
      statement = Cypher.match(user_node).where(user_node.has_labels('User')).finish.build
      expect(renderer.render(statement)).to eq('MATCH (u:`User`) WHERE u:`User` FINISH')
    end

    it 'finish after set' do
      statement = Cypher.match(user_node)
                        .set(user_node.property(:name).to(Cypher.literal_of('hans')))
                        .finish
                        .build
      expect(renderer.render(statement)).to eq("MATCH (u:`User`) SET u.name = 'hans' FINISH")
    end

    it 'finish after delete' do
      statement = Cypher.match(user_node).delete(user_node).finish.build
      expect(renderer.render(statement)).to eq('MATCH (u:`User`) DELETE u FINISH')
    end

    it 'finish after create' do
      statement = Cypher.create(user_node).finish.build
      expect(renderer.render(statement)).to eq('CREATE (u:`User`) FINISH')
    end

    it 'finish after merge' do
      statement = Cypher.merge(user_node.relationship_to(user_node, 'KNOWS')).finish.build
      expect(renderer.render(statement)).to eq('MERGE (u:`User`)-[:`KNOWS`]->(u) FINISH')
    end
  end
end
