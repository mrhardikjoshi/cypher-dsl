# frozen_string_literal: true

# Translated from CypherTests.java.
#
# Adapted: the Java visitor-based structural assertions check the Ruby objects directly;
# `Literal#asString` is `to_s`; a `Character` map key is a symbol.
module CypherDSL
  RSpec.describe 'CypherTests' do
    it 'sort direction should be specified' do
      sort_item = Cypher.sort(Cypher.literal_false, :asc)
      expect(sort_item.direction).to eq(:asc)
      expect(Cypher.returning(:n).order_by(sort_item).build.cypher).to eq('RETURN n ORDER BY false ASC')
    end

    it 'does not create illegal literals' do
      expect { Cypher.literal_of(Object.new) }.to raise_error(ArgumentError, /\AUnsupported literal type: /)
    end

    it 'null literal should be same instance' do
      expect(Cypher.literal_null).to be(Literal::NULL)
      expect(Cypher.literal_of(nil)).to be(Literal::NULL)
    end

    it 'creates list literals' do
      params = [Cypher.literal_false, Cypher.literal_true]
      list_literal = Cypher.literal_of(params)
      expect(list_literal).to be_a(ListExpression)
      expect(list_literal.to_s).to eq('[false, true]')
    end

    it 'creates map literals' do
      map_value = { 'm1' => 1, 'm2' => 'm2' }
      params = { k: Cypher.literal_false, 'k2' => Cypher.literal_true, 'k3' => Cypher.literal_of(%w[a b c]),
                 'k4' => Cypher.literal_of(map_value) }
      map_literal = Cypher.literal_of(params)
      expect(map_literal).to be_a(MapExpression)
      expect(map_literal.to_s).to eq("{k: false, k2: true, k3: ['a', 'b', 'c'], k4: {m1: 1, m2: 'm2'}}")
    end

    it 'quotes strings' do
      expect(Cypher.quote('foo')).to eq("'foo'")
      expect(Cypher.quote('fo`o')).to eq("'fo`o'")
    end

    it 'creates property pointing to symbolic name' do
      property = Cypher.property('a', 'b')
      expect(property.container).to eq(SymbolicName.of('a'))
      expect(property.names).to eq(['b'])
    end

    it 'creates property with name from collection pointing to symbolic name' do # GH-189
      property = Cypher.property('a', ['b'])
      expect(property.container).to eq(SymbolicName.of('a'))
      expect(property.names).to eq(['b'])
    end

    it 'creates additional labels from collection' do # GH-189
      node = Cypher.node('Primary', Cypher.map_of, ['Secondary'])
      expect(node.labels).to eq(%w[Primary Secondary])
    end
  end
end
