# frozen_string_literal: true

# Translated from InternalRelationshipImplTests.java.
#
# Adapted: `new InternalRelationshipImpl(…)` is `Relationship.create(left, direction, right, types)`;
# the Java visitor-based property checks inspect the Ruby objects.
module CypherDSL
  RSpec.describe 'InternalRelationshipImplTests' do
    it 'preconditions should be asserted' do
      expect { Relationship.create(nil, :ltr, Cypher.node('a'), []) }.to raise_error(ArgumentError, 'Left node is required.')
      expect { Relationship.create(Cypher.node('a'), :ltr, nil, []) }.to raise_error(ArgumentError, 'Right node is required.')
    end

    describe 'PropertiesShouldBeHandled' do
      [
        Cypher.node('N').named(:n).relationship_to(Cypher.any_node).with_properties('p', Cypher.literal_true),
        Cypher.node('N').named(:n).relationship_to(Cypher.any_node).with_properties(MapExpression.of('p', Cypher.literal_true))
      ].each_with_index do |relationship, index|
        it "adds properties(#{index})" do
          expect(relationship.left.symbolic_name.value).to eq('n')
          expect(relationship.left.labels).to eq(['N'])
          expect(relationship.details.properties.entries).to eq([['p', Literal::TRUE]])
        end
      end

      it 'creates property' do
        relationship = Cypher.node('N').named(:n).relationship_to(Cypher.any_node).named(:r)
        property = relationship.property('p')
        expect(property.names).to eq(['p'])
        expect(property.container).to be(relationship)
        expect(property.container.required_symbolic_name).to eq(SymbolicName.of('r'))
      end
    end
  end
end
