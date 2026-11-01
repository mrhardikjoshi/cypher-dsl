# frozen_string_literal: true

# Translated from DefaultStatementBuilderTests.java.
#
# Adapted: Java distinguishes a null array (`…are required.`) from an empty one or a single
# null element (`At least one…`); here `nil` among the arguments means the former, no
# arguments the latter.
module CypherDSL
  RSpec.describe 'DefaultStatementBuilderTests' do
    let(:builder) { Statement.builder }

    it 'match preconditions should be asserted' do
      expect { builder.match(nil) }.to raise_error(ArgumentError, 'Patterns to match are required.')
      expect { builder.match }.to raise_error(ArgumentError, 'At least one pattern to match is required.')
    end

    describe 'MessageBundles' do
      it 'uses message bundle on null expressions' do
        expect { builder.returning(nil) }.to raise_error(ArgumentError, 'Expressions to return are required.')
        expect { builder.with(nil) }.to raise_error(ArgumentError, 'Expressions to return are required.')
        update = builder.set(Cypher.node('N').named(:n), 'x')
        expect { update.returning(nil) }.to raise_error(ArgumentError, 'Expressions to return are required.')
      end

      it 'uses message bundle on empty expressions' do
        expect { builder.returning }.to raise_error(ArgumentError, 'At least one expressions to return is required.')
        expect { builder.with }.to raise_error(ArgumentError, 'At least one expressions to return is required.')
        update = builder.set(Cypher.node('N').named(:n), 'x')
        expect { update.returning }.to raise_error(ArgumentError, 'At least one expressions to return is required.')
      end
    end

    describe 'ReturningPreconditionsShouldBeAsserted' do
      it 'for expressions' do
        expect { builder.returning(nil) }.to raise_error(ArgumentError, 'Expressions to return are required.')
        expect { builder.returning([]) }.to raise_error(ArgumentError, 'At least one expressions to return is required.')
      end
    end
  end
end
