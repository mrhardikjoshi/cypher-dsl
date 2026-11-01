# frozen_string_literal: true

# Translated from BooleanLiteralTests.java.
#
# Adapted: `BooleanLiteral.of(null)` is FALSE in Java; in Ruby `nil` is the NULL literal,
# so that row is left out.
module CypherDSL
  RSpec.describe 'BooleanLiteralTests' do
    { false => Literal::FALSE, true => Literal::TRUE }.each do |input, expected|
      it "value of should work(#{input})" do
        literal = Cypher.literal_of(input)
        expect(literal).to be_a(Literal)
        expect(literal).to be(expected)
      end
    end
  end
end
