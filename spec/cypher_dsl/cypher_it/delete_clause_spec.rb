# frozen_string_literal: true

# Translated from CypherIT.java, nested class DeleteClause.
module CypherDSL
  RSpec.describe 'CypherIT / DeleteClause' do
    let(:bike_node) { Cypher.node('Bike').named(:b) }
    let(:user_node) { Cypher.node('User').named(:u) }
    let(:renderer) { Renderer.default }

    it 'shouldRenderDeleteWithoutReturn' do
      statement = Cypher.match(user_node).detach_delete(user_node).build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) DETACH DELETE u')

      statement = Cypher.match(user_node).detach_delete('u').build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) DETACH DELETE u')

      statement = Cypher.match(user_node).with(user_node).detach_delete(user_node).build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) WITH u DETACH DELETE u')

      statement = Cypher.match(user_node)
                        .where(user_node.property(:a).is_not_null)
                        .and(user_node.property(:b).is_null)
                        .delete(user_node)
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) WHERE (u.a IS NOT NULL AND u.b IS NULL) DELETE u')

      statement = Cypher.match(user_node, bike_node).delete(user_node, bike_node).build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`), (b:`Bike`) DELETE u, b')
    end

    it 'shouldRenderDeleteBasedOnExpressionCollectionWithoutReturn' do
      statement = Cypher.match(user_node)
                        .detach_delete([user_node.required_symbolic_name])
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) DETACH DELETE u')

      statement = Cypher.match(user_node)
                        .with(user_node)
                        .detach_delete([user_node.required_symbolic_name])
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) WITH u DETACH DELETE u')

      statement = Cypher.match(user_node)
                        .where(user_node.property(:a).is_not_null)
                        .and(user_node.property(:b).is_null)
                        .delete([user_node.required_symbolic_name])
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) WHERE (u.a IS NOT NULL AND u.b IS NULL) DELETE u')

      named_ones = [user_node.required_symbolic_name, bike_node.required_symbolic_name]
      statement = Cypher.match(user_node, bike_node).delete(named_ones).build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`), (b:`Bike`) DELETE u, b')
    end

    it 'shouldRenderDeleteWithReturn' do
      statement = Cypher.match(user_node).detach_delete(user_node).returning(user_node).build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) DETACH DELETE u RETURN u')

      statement = Cypher.match(user_node)
                        .where(user_node.property(:a).is_not_null)
                        .and(user_node.property(:b).is_null)
                        .detach_delete(user_node)
                        .returning(user_node)
                        .order_by(user_node.property(:a).ascending)
                        .skip(2)
                        .limit(1)
                        .build

      expect(renderer.render(statement)).to eq(
        'MATCH (u:`User`) WHERE (u.a IS NOT NULL AND u.b IS NULL) DETACH DELETE u RETURN u ORDER BY u.a ASC SKIP 2 LIMIT 1'
      )

      statement = Cypher.match(user_node)
                        .where(user_node.property(:a).is_not_null)
                        .and(user_node.property(:b).is_null)
                        .detach_delete(user_node)
                        .returning_distinct(user_node)
                        .order_by(user_node.property(:a).ascending)
                        .skip(2)
                        .limit(1)
                        .build

      expect(renderer.render(statement)).to eq(
        'MATCH (u:`User`) WHERE (u.a IS NOT NULL AND u.b IS NULL) DETACH DELETE u RETURN DISTINCT u ORDER BY u.a ASC SKIP 2 LIMIT 1'
      )
    end

    it 'shouldRenderNodeDelete' do
      n = Cypher.any_node(:n)
      r = n.relationship_between(Cypher.any_node).named(:r0)
      statement = Cypher.match(n)
                        .where(n.internal_id.is_equal_to(Cypher.literal_of(4711)))
                        .optional_match(r)
                        .delete(r, n)
                        .build

      expect(renderer.render(statement)).to eq('MATCH (n) WHERE id(n) = 4711 OPTIONAL MATCH (n)-[r0]-() DELETE r0, n')
    end

    it 'shouldRenderChainedDeletes' do
      n = Cypher.any_node(:n)
      r = n.relationship_between(Cypher.any_node).named(:r0)
      statement = Cypher.match(n)
                        .where(n.internal_id.is_equal_to(Cypher.literal_of(4711)))
                        .optional_match(r)
                        .delete(r, n)
                        .delete(bike_node)
                        .detach_delete(user_node)
                        .build

      expect(renderer.render(statement)).to eq(
        'MATCH (n) WHERE id(n) = 4711 OPTIONAL MATCH (n)-[r0]-() DELETE r0, n DELETE b DETACH DELETE u'
      )
    end
  end
end
