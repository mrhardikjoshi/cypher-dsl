# frozen_string_literal: true

# Translated from DeleteTests.java.
#
# Adapted: `Delete.delete(names…)` is `Clauses.delete(false, names)`; its `toString`
# (`Delete{cypher=…}`) is the clause rendered as a fragment.
module CypherDSL
  RSpec.describe 'DeleteTests' do
    it 'building delete clause with multiple elements' do
      delete = Clauses.delete(false, [Cypher.name(:n), Cypher.name(:b)])
      expect(Renderer.default.render_fragment(delete)).to eq('DELETE n, b')
    end
  end
end
