# frozen_string_literal: true

# Translated from CypherIT.java, the tests directly in the class (not nested).
module CypherDSL
  RSpec.describe 'CypherIT' do
    let(:bike_node) { Cypher.node('Bike').named(:b) }
    let(:user_node) { Cypher.node('User').named(:u) }

    it 'statement should be renderable' do
      statement = Cypher.returning(Cypher.literal_true.as(:t)).build
      cypher = statement.cypher
      expect(cypher).to eq('RETURN true AS t')
      expect(statement.cypher).to equal(cypher)
    end

    it 'parameter literals' do
      statement = Cypher
                  .returning(Cypher.literal_of(Cypher.parameter(:asd)).as(:t),
                             Cypher.literal_of({ another: Cypher.parameter(:parameter) }).as(:t2))
                  .build
      cypher = statement.cypher
      expect(cypher).to eq('RETURN $asd AS t, {another: $parameter} AS t2')
      expect(statement.cypher).to equal(cypher)
    end

    it 'map literal keys must be escaped' do
      n = Cypher.any_node(:n)
      evil_key = 'a: 1} OR true OR {b'

      stmt = Cypher.match(n)
                   .where(n.property(:attrs).is_equal_to(Cypher.literal_of({ evil_key => 1 })))
                   .returning(n)
                   .build

      expect(stmt.cypher).to eq('MATCH (n) WHERE n.attrs = {`a: 1} OR true OR {b`: 1} RETURN n')
    end

    it 'generates statements of correct type' do
      statement = Cypher.returning(Cypher.literal_true.as(:t)).build
      expect(statement).to be_result_statement.and be_single_query

      statement = Cypher.match(bike_node, user_node, Cypher.node('U').named(:o))
                        .set(bike_node.property(:x).to(Cypher.literal_true))
                        .build
      expect(statement).not_to be_result_statement
      expect(statement).to be_single_query

      statement = Cypher.match(bike_node, user_node, Cypher.node('U').named(:o))
                        .set(bike_node.property(:x).to(Cypher.literal_true))
                        .with(bike_node)
                        .returning(bike_node)
                        .build
      expect(statement).to be_result_statement.and be_multi_part_query
    end
  end
end
