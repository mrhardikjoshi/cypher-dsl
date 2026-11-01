# frozen_string_literal: true

# Translated from internal/LoadCSVTests.java.
#
# Adapted: `new LoadCSV(uri, withHeaders, alias)` is the `Clauses::LoadCsv` clause object.
module CypherDSL
  RSpec.describe 'LoadCSVTests' do
    let(:a) do
      Clauses::LoadCsv.new(uri: 'file:///f.csv', with_headers: true, alias_name: SymbolicName.of('a'),
                           field_terminator: nil, periodic_commit: nil)
    end

    it 'wither should work with nulls on both ends' do
      b = a.with_field_terminator(nil)
      expect(b).to be(a)
    end

    it 'wither should work with empty values' do
      b = a.with_field_terminator("  \t")
      expect(b).to be(a)
      expect(a.field_terminator).to be_nil
    end

    it 'wither should work with non empty values' do
      b = a.with_field_terminator(';')
      expect(b).not_to be(a)
      expect(a.field_terminator).to be_nil
      expect(b.field_terminator).to eq(';')
    end
  end
end
