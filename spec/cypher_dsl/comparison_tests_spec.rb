# frozen_string_literal: true

# Translated from ComparisonTests.java.
#
# Adapted: `Comparison.create(left, operator, right)` is `Comparison.new`, operators are strings.
module CypherDSL
  RSpec.describe 'ComparisonTests' do
    it 'preconditions should be asserted' do
      expression = Cypher.literal_of('Arbitrary expression')
      expect { Comparison.new(nil, '=', expression) }.to raise_error(ArgumentError, 'Left expression must not be null.')
      expect { Comparison.new(expression, '=', nil) }.to raise_error(ArgumentError, 'Right expression must not be null.')
      expect { Comparison.new(expression, nil, expression) }.to raise_error(ArgumentError, 'Operator must not be empty.')
    end
  end
end
