# frozen_string_literal: true

# Translated from RelationshipTests.java.
module CypherDSL
  RSpec.describe 'RelationshipTests' do
    it 'relationship without types must not throw NPEs' do
      relationship = Cypher.any_node.relationship_to(Cypher.any_node)
      expect(relationship.details.types).to be_empty
    end
  end
end
