# frozen_string_literal: true

# Translated from SymbolicNameTests.java.
#
# Adapted: `toString` of a resolved name is its value (`a`) rather than `SymbolicName{cypher=a}`.
module CypherDSL
  RSpec.describe 'SymbolicNameTests' do
    describe 'ResolvedSymbolicNames' do
      it 'equals should work same value' do
        name1 = SymbolicName.of('a')
        name2 = name1
        name3 = SymbolicName.of('a')
        expect(name1).to eq(name2)
        expect(name1).to eq(name3)
      end

      it 'equals should work different value' do
        expect(SymbolicName.of('a')).not_to eq(SymbolicName.of('b'))
      end

      it 'does not equal unresolved' do
        expect(SymbolicName.of('a')).not_to eq(SymbolicName.unresolved)
      end

      it 'same resolved names should have same hash codes' do
        name1 = SymbolicName.of('a')
        name2 = SymbolicName.of('a')
        expect(name1.hash).to eq(name2.hash)
      end

      it 'different resolved names should have different hash codes' do
        expect(SymbolicName.of('a').hash).not_to eq(SymbolicName.of('b').hash)
      end

      it 'to string should work' do
        expect(SymbolicName.of('a').to_s).to eq('a')
      end
    end

    describe 'UnresolvedSymbolicNames' do
      it 'equals should work same value' do
        name1 = SymbolicName.unresolved
        name2 = name1
        name3 = SymbolicName.unresolved
        expect(name1).to eq(name2)
        expect(name1).not_to eq(name3)
        expect(name2).not_to eq(name3)
      end

      it 'does not equal resolved' do
        expect(SymbolicName.unresolved).not_to eq(SymbolicName.of('a'))
      end

      it 'different unresolved names should have different hash codes' do
        expect(SymbolicName.unresolved.hash).not_to eq(SymbolicName.unresolved.hash)
      end

      it 'to string should work' do
        expect(SymbolicName.unresolved.to_s).to eq('Unresolved SymbolicName')
      end
    end
  end
end
