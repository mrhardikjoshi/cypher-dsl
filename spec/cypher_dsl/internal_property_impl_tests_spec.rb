# frozen_string_literal: true

# Translated from InternalPropertyImplTests.java.
#
# Adapted: `InternalPropertyImpl.create(container, names…)` is `Property.new(container, names)`.
module CypherDSL
  RSpec.describe 'InternalPropertyImplTests' do
    it 'simple property get name should work' do
      expect(Property.new(SymbolicName.unresolved, ['simple']).name).to eq('simple')
    end

    it 'multiple property get name should work' do
      expect(Property.new(SymbolicName.unresolved, %w[foo bar]).name).to eq('foo.bar')
    end

    it 'external reference has priority' do
      expect(Property.new(SymbolicName.unresolved, %w[foo bar]).referenced_as('something').name).to eq('something')
    end
  end
end
