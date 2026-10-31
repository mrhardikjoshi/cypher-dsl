# frozen_string_literal: true

# Translated from CypherIT.java, nested class WithAndOrder.
module CypherDSL
  RSpec.describe 'CypherIT / WithAndOrder' do
    let(:renderer) { Renderer.default }

    it 'order on with should work' do
      by_title = Cypher.sort(Cypher.property(:m, :title))
      by_name = Cypher.sort(Cypher.property(:p, :name))

      base_statement = lambda do
        Cypher.match(Cypher.node('Movie').named(:m).relationship_from(Cypher.node('Person').named(:p), 'ACTED_IN').named(:r))
              .with(Cypher.name(:m), Cypher.name(:p))
      end

      [base_statement.call.order_by(by_title, by_name), base_statement.call.order_by([by_title, by_name])].each do |ordered|
        statement = ordered.returning(Cypher.property(:m, :title).as(:movie), Cypher.collect(Cypher.property(:p, :name)).as(:actors))
                           .build
        expected = 'MATCH (m:`Movie`)<-[r:`ACTED_IN`]-(p:`Person`) WITH m, p ORDER BY m.title, p.name RETURN m.title AS movie, collect(p.name) AS actors'
        expect(renderer.render(statement)).to eq(expected)
      end
    end

    it 'concatenated ordering' do
      statement = Cypher
                  .match(Cypher.node('Movie').named(:m).relationship_from(Cypher.node('Person').named(:p), 'ACTED_IN').named(:r))
                  .with(Cypher.name(:m), Cypher.name(:p))
                  .order_by(Cypher.property(:m, :title))
                  .ascending
                  .and(Cypher.property(:p, :name))
                  .ascending
                  .returning(Cypher.property(:m, :title).as(:movie), Cypher.collect(Cypher.property(:p, :name)).as(:actors))
                  .build

      expected = 'MATCH (m:`Movie`)<-[r:`ACTED_IN`]-(p:`Person`) WITH m, p ORDER BY m.title ASC, p.name ASC RETURN m.title AS movie, collect(p.name) AS actors'
      expect(renderer.render(statement)).to eq(expected)
    end
  end
end
