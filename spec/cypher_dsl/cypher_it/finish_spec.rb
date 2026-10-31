# frozen_string_literal: true

# Translated from CypherIT.java, nested class Finish.
module CypherDSL
  RSpec.describe 'CypherIT / Finish' do
    let(:user_node) { Cypher.node('User').named(:u) }
    let(:renderer) { Renderer.default }

    it 'finishAfterMatch' do
      statement = Cypher.match(user_node).finish.build
      expect(renderer.render(statement)).to eq('MATCH (u:`User`) FINISH')
    end

    it 'finishAfterMatchWithWhere' do
      statement = Cypher.match(user_node).where(user_node.has_labels('User')).finish.build
      expect(renderer.render(statement)).to eq('MATCH (u:`User`) WHERE u:`User` FINISH')
    end

    it 'finishAfterSet' do
      statement = Cypher.match(user_node)
                        .set(user_node.property(:name).to(Cypher.literal_of('hans')))
                        .finish
                        .build
      expect(renderer.render(statement)).to eq("MATCH (u:`User`) SET u.name = 'hans' FINISH")
    end

    it 'finishAfterDelete' do
      statement = Cypher.match(user_node).delete(user_node).finish.build
      expect(renderer.render(statement)).to eq('MATCH (u:`User`) DELETE u FINISH')
    end

    it 'finishAfterCreate' do
      statement = Cypher.create(user_node).finish.build
      expect(renderer.render(statement)).to eq('CREATE (u:`User`) FINISH')
    end

    it 'finishAfterMerge' do
      statement = Cypher.merge(user_node.relationship_to(user_node, 'KNOWS')).finish.build
      expect(renderer.render(statement)).to eq('MERGE (u:`User`)-[:`KNOWS`]->(u) FINISH')
    end
  end
end
