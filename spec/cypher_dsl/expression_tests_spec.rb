# frozen_string_literal: true

# Translated from ExpressionTests.java.
#
# Adapted: the Java visitor collects the operation's segments; here the operands and the
# operator are read from the {Operation} / {Comparison} directly.
module CypherDSL
  RSpec.describe 'ExpressionTests' do
    {
      Cypher.literal_of(1).add(Cypher.literal_of(2)) => '+',
      Cypher.literal_of(1).subtract(Cypher.literal_of(2)) => '-',
      Cypher.literal_of(1).multiply(Cypher.literal_of(2)) => '*',
      Cypher.literal_of(1).divide(Cypher.literal_of(2)) => '/',
      Cypher.literal_of(1).remainder(Cypher.literal_of(2)) => '%',
      Cypher.literal_of(1).pow(Cypher.literal_of(2)) => '^'
    }.each do |operation, expected_operator|
      it "correct mathematical operators should be used(#{expected_operator})" do
        expect(operation).to be_a(Operation)
        expect(operation.left.value).to eq(1)
        expect(operation.operator).to eq(expected_operator)
        expect(operation.right.value).to eq(2)
      end
    end

    {
      Cypher.literal_of('a').concat(Cypher.literal_of('b')) => '+',
      Cypher.literal_of('a').matches(Cypher.literal_of('b')) => '=~'
    }.each do |visitable, expected_operator|
      it "correct string operators should be used(#{expected_operator})" do
        expect(visitable.left.value).to eq('a')
        expect(visitable.operator).to eq(expected_operator)
        expect(visitable.right.value).to eq('b')
      end
    end
  end
end
