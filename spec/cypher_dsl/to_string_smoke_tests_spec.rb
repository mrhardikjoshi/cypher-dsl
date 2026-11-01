# frozen_string_literal: true

# Translated from ToStringSmokeTests.java.
#
# Adapted: `toString` is `to_s` and gives the plain Cypher (`(n:Person)`) rather than
# `InternalNodeImpl{cypher=(n:Person)}`; `mostConstructsShouldNotHaveDefaultToString` relies
# on Java reflection and has no counterpart.
module CypherDSL
  RSpec.describe 'ToStringSmokeTests' do
    {
      Cypher.node('Person').named(:n) => '(n:Person)',
      Cypher.node('Person').named(:p).relationship_to(Cypher.node('Movie').named(:m), 'PLAYED_IN').named(:r) =>
        '(p:Person)-[r:PLAYED_IN]->(m:Movie)',
      Cypher.node('Person').named(:p).relationship_to(Cypher.node('Movie').named(:m), 'PLAYED_IN').named(:r)
            .relationship_from(Cypher.node('Person').named(:d), 'DIRECTED') =>
        '(p:Person)-[r:PLAYED_IN]->(m:Movie)<-[:DIRECTED]-(d:Person)',
      Cypher.element_id(Cypher.any_node(:n)) => 'elementId(n)',
      Cypher.call('db.labels').as_function => 'db.labels()',
      Cypher.literal_of('aString') => "'aString'",
      Cypher.literal_of(1) => '1',
      Cypher.parameter(:p) => '$p',
      Cypher.any_node(:n).property(:prop) => 'n.prop'
    }.each do |visitable, expected|
      it "to string should work(#{expected})" do
        expect(visitable.to_s).to eq(expected)
      end
    end
  end
end
