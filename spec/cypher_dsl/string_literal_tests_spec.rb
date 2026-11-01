# frozen_string_literal: true

# Translated from StringLiteralTests.java.
#
# Adapted: `new StringLiteral(…).asString()` is `Cypher.literal_of(…).as_string`, the static
# `escapeString` is `Literal.escape_string`; a `nil` string quotes as `''` through `Literal.quote`.
module CypherDSL
  RSpec.describe 'StringLiteralTests' do
    it 'escapes content' do
      literal = Cypher.literal_of("A\\B\\\\Ca'bc123\\")
      expect(literal.as_string).to eq("'A\\\\B\\\\\\\\Ca\\'bc123\\\\'")
    end

    it 'escapes null' do
      expect(Literal.quote(nil)).to eq("''")
    end

    it 'correctly escapes empty strings' do
      [['', ''], [" \t ", " \t "], ['Nothing to escape', 'Nothing to escape'], ["' \" '", "\\' \\\" \\'"]]
        .each do |string, expected_escaped_string|
        expect(Literal.escape_string(string)).to eq(expected_escaped_string)
      end
    end

    it 'does not try to escape null strings' do
      expect(Literal.escape_string(nil)).to be_nil
    end
  end
end
