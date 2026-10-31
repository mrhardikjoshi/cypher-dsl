# frozen_string_literal: true

# Translated from CypherIT.java, nested class Call.
module CypherDSL
  RSpec.describe 'CypherIT / Call' do
    it 'simple call raw cypher' do
      cypher = Cypher.call_raw_cypher('MATCH (n:Test) WHERE n.id = $id RETURN id(n) as a, n.id as b')
                     .build
                     .cypher
      expect(cypher).to eq('CALL () {MATCH (n:Test) WHERE n.id = $id RETURN id(n) as a, n.id as b}')
    end

    it 'raw cypher with where and return' do
      cypher = Cypher.call_raw_cypher('MATCH (n:Test) RETURN id(n) as a, n.id as b, n.timestamp as timestamp')
                     .with(Cypher.asterisk)
                     .where(Cypher.gt(Cypher.raw('timestamp'), Cypher.parameter(:from))
                                  .and(Cypher.lte(Cypher.raw('timestamp'), Cypher.parameter(:to))))
                     .returning(Cypher.asterisk)
                     .build
                     .cypher

      expect(cypher).to eq(
        'CALL () {MATCH (n:Test) RETURN id(n) as a, n.id as b, n.timestamp as timestamp} WITH * WHERE (timestamp > $from AND timestamp <= $to) RETURN *'
      )
    end
  end
end
