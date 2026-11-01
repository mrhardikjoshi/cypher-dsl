# frozen_string_literal: true

# Translated from InternalNodeImplTests.java.
#
# Adapted: `new InternalNodeImpl(…)` is `Cypher.node(…)`; the Java visitor-based checks of
# labels and properties inspect the Ruby objects; IllegalStateException is an ArgumentError.
module CypherDSL
  RSpec.describe 'InternalNodeImplTests' do
    it 'preconditions should be asserted' do
      expected_message = 'A primary label is required.'
      expect { Cypher.node('') }.to raise_error(ArgumentError, expected_message)
      expect { Cypher.node(" \t") }.to raise_error(ArgumentError, expected_message)
    end

    it 'does not add empty additional labels' do
      expect { Cypher.node('primary', ' ', "\t ") }.to raise_error(ArgumentError, 'An empty label is not allowed.')
    end

    it 'creates nodes' do
      node = Cypher.node('primary', 'secondary')
      expect(node.labels).to contain_exactly('primary', 'secondary')
    end

    describe 'MutationsAndSetShouldRequireName' do
      let(:message) { 'A property container must be named to be mutated.' }

      it 'mutation with parameter' do
        expect { Cypher.any_node.mutate(Cypher.parameter(:x)) }.to raise_error(ArgumentError, message)
      end

      it 'mutation with map' do
        expect { Cypher.any_node.mutate(Cypher.map_of('a', Cypher.literal_true)) }.to raise_error(ArgumentError, message)
      end

      it 'set with parameter' do
        expect { Cypher.any_node.set(Cypher.parameter(:x)) }.to raise_error(ArgumentError, message)
      end

      it 'set with map' do
        expect { Cypher.any_node.set(Cypher.map_of('a', Cypher.literal_true)) }.to raise_error(ArgumentError, message)
      end
    end

    describe 'PropertiesShouldBeHandled' do
      [
        Cypher.node('N').named(:n).with_properties('p', Cypher.literal_true),
        Cypher.node('N').named(:n).with_properties(MapExpression.of('p', Cypher.literal_true))
      ].each_with_index do |node, index|
        it "adds properties(#{index})" do
          expect(node.symbolic_name.value).to eq('n')
          expect(node.labels).to eq(['N'])
          expect(node.properties.entries).to eq([['p', Literal::TRUE]])
        end
      end

      it 'creates property' do
        node = Cypher.node('N').named(:n)
        property = node.property('p')
        expect(property.names).to eq(['p'])
        expect(property.container).to be(node)
        expect(property.container.required_symbolic_name).to eq(SymbolicName.of('n'))
      end
    end
  end
end
