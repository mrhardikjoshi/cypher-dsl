# frozen_string_literal: true

# Translated from VectorTests.java.
#
# Adapted: the Java overloads per primitive array are `VectorLiteral.of(elements, type)`;
# Java's NullPointerExceptions are ArgumentErrors.
module CypherDSL
  RSpec.describe 'VectorTests' do
    def size_message(size) = "'#{size}' is not a valid value. Must be a number in the range 1 to 4096 (GQL 42N31)"

    {
      integer8: ['vector([1, 2, 3], 3, INTEGER8 NOT NULL)', [1, 2, 3]],
      integer16: ['vector([1, 2, 3], 3, INTEGER16 NOT NULL)', [1, 2, 3]],
      integer32: ['vector([1, 2, 3], 3, INTEGER32 NOT NULL)', [1, 2, 3]],
      integer: ['vector([1, 2, 3], 3, INTEGER NOT NULL)', [1, 2, 3]],
      float32: ['vector([1.0, 2.0, 3.0], 3, FLOAT32 NOT NULL)', [1, 2, 3]],
      float: ['vector([1.0, 2.0, 3.0], 3, FLOAT NOT NULL)', [1, 2, 3]]
    }.each do |type, (expected, elements)|
      describe type.to_s do
        it 'checks null' do
          expect { VectorLiteral.of(nil, type) }.to raise_error(ArgumentError, 'Vector elements must not be literal null')
        end

        it 'checks min size' do
          expect { VectorLiteral.of([], type) }.to raise_error(ArgumentError, size_message(0))
        end

        it 'checks max size' do
          expect { VectorLiteral.of(Array.new(5000, 0), type) }.to raise_error(ArgumentError, size_message(5000))
        end

        it 'renders the literal' do
          expect(VectorLiteral.of(elements, type).as_string).to eq(expected)
        end
      end
    end

    it 'defaults to INTEGER for integers and FLOAT for floats' do
      expect(VectorLiteral.of([1, 2, 3]).as_string).to eq('vector([1, 2, 3], 3, INTEGER NOT NULL)')
      expect(VectorLiteral.of([1.5, 2.0]).as_string).to eq('vector([1.5, 2.0], 2, FLOAT NOT NULL)')
    end

    it 'maximum size should be accepted' do
      elements = Array.new(4096, 0)
      expect(VectorLiteral.of(elements).content.size).to eq(4096)
    end

    it 'one above maximum size should be rejected' do
      elements = Array.new(4097, 0)
      expect { VectorLiteral.of(elements) }.to raise_error(ArgumentError, size_message(4097))
    end
  end
end
