# frozen_string_literal: true

# Translated from ClausesTests.java.
#
# Adapted: the anonymous non-updating clause is a MATCH clause.
module CypherDSL
  RSpec.describe 'ClausesTests' do
    it 'updating clauses should be check in foreach' do
      non_updating_clause = Cypher.match(Cypher.any_node(:n)).build.clauses.first
      expect { Clauses.for_each(SymbolicName.of('x'), Cypher.literal_null, [non_updating_clause]) }.to raise_error(
        ArgumentError,
        'Only updating clauses SET, REMOVE, CREATE, MERGE, DELETE, and FOREACH are allowed as clauses applied inside FOREACH.'
      )
    end

    it 'foreach should work' do
      foreach = Clauses.for_each(SymbolicName.of('x'), Cypher.literal_null, [Clauses.set([])])
      expect(foreach).not_to be_nil
    end
  end
end
