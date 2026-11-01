# frozen_string_literal: true

# Translated from FunctionInvocationTests.java.
#
# Adapted: the Java null-argument preconditions have no counterpart (`nil` is the NULL literal);
# `FunctionInvocation.createDistinct(HEAD, …)` is `FunctionInvocation.new('head', …, distinct: true)`.
module CypherDSL
  RSpec.describe 'FunctionInvocationTests' do
    it 'arguments should be asserted' do
      expect { FunctionInvocation.new('head', [Cypher.name(:x)], distinct: true) }
        .to raise_error(ArgumentError, 'The distinct operator can only be applied within aggregate functions.')
      expect(FunctionInvocation.new('avg', [Cypher.name(:x)], distinct: true).to_s).to eq('avg(DISTINCT x)')
    end
  end
end
