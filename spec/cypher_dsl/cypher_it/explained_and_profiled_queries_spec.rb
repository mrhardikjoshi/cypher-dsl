# frozen_string_literal: true

# Translated from CypherIT.java, nested class ExplainedAndProfiledQueries.
module CypherDSL
  RSpec.describe 'CypherIT / ExplainedAndProfiledQueries' do
    let(:bike_node) { Cypher.node('Bike').named(:b) }
    let(:user_node) { Cypher.node('User').named(:u) }
    let(:renderer) { Renderer.default }

    it 'renders explain' do # GH-98
      statement = Cypher.match(user_node.relationship_to(bike_node, 'OWNS'))
                        .where(user_node.property(:a).is_null)
                        .with(bike_node, user_node)
                        .returning(bike_node)
                        .explain

      expect(renderer.render(statement))
        .to eq('EXPLAIN MATCH (u:`User`)-[:`OWNS`]->(b:`Bike`) WHERE u.a IS NULL WITH b, u RETURN b')
    end

    it 'renders profile' do # GH-99
      trip_node = Cypher.node('Trip').named(:tt)
      statement = Cypher.match(user_node.relationship_to(bike_node, 'OWNS'))
                        .where(user_node.property(:a).is_null)
                        .with(bike_node, user_node)
                        .match(trip_node)
                        .where(trip_node.property(:name).is_equal_to(Cypher.literal_of('Festive500')))
                        .with(bike_node, user_node, trip_node)
                        .returning(bike_node, user_node, trip_node)
                        .profile

      expect(renderer.render(statement)).to eq(
        "PROFILE MATCH (u:`User`)-[:`OWNS`]->(b:`Bike`) WHERE u.a IS NULL WITH b, u MATCH (tt:`Trip`) WHERE tt.name = 'Festive500' WITH b, u, tt RETURN b, u, tt"
      )
    end
  end
end
