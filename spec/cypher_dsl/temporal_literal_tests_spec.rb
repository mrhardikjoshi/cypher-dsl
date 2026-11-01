# frozen_string_literal: true

# Translated from TemporalLiteralTests.java.
#
# Adapted: Ruby has no local date-time, local time or offset time types, so only `Date`
# (`date(…)`) and `Time` / `DateTime` (`datetime(…)`) are literals; a `Time` carries an
# offset but no zone id, hence `+01:00` without `[Europe/Berlin]`.
module CypherDSL
  RSpec.describe 'TemporalLiteralTests' do
    it 'local date should work' do
      literal = Cypher.literal_of(Date.new(2021, 3, 10))
      expect(literal.as_string).to eq("date('2021-03-10')")
    end

    it 'zoned date time should work' do
      literal = Cypher.literal_of(Time.new(2021, 3, 10, 15, 41, 0, '+01:00'))
      expect(literal.as_string).to eq("datetime('2021-03-10T15:41:00+01:00')")
    end

    it 'date time should work' do
      literal = Cypher.literal_of(DateTime.new(2021, 3, 10, 15, 13, 0))
      expect(literal.as_string).to eq("datetime('2021-03-10T15:13:00+00:00')")
    end

    it 'throws an exception on unsupported temporal accessor' do
      expect { Cypher.literal_of(Struct.new(:year).new(2021)) }.to raise_error(ArgumentError, /\AUnsupported literal type: /)
    end
  end
end
