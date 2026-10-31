# frozen_string_literal: true

# Translated from CypherIT.java, nested classes Returning and UnwindRendering.
module CypherDSL
  RSpec.describe 'CypherIT / Returning' do
    it 'renders leading returning' do
      cypher = Cypher.returning(Cypher.literal_of(1)).build.cypher
      expect(cypher).to eq('RETURN 1')
    end

    it 'renders leading returning based on expression collection' do # GH-189
      cypher = Cypher.returning([Cypher.literal_of(1)]).build.cypher
      expect(cypher).to eq('RETURN 1')
    end
  end

  RSpec.describe 'CypherIT / UnwindRendering' do
    let(:bike_node) { Cypher.node('Bike').named(:b) }
    let(:renderer) { Renderer.default }

    it 'unwind without with' do
      root_node = Cypher.any_node(:n)
      label = Cypher.name(:label)
      statement = Cypher.match(root_node)
                        .where(root_node.internal_id.is_equal_to(Cypher.literal_of(1)))
                        .unwind(root_node.labels_function)
                        .as(:label)
                        .with(label)
                        .where(label.in(Cypher.parameter(:fixedLabels)).not)
                        .returning(Cypher.collect(label).as(:labels))
                        .build

      expect(renderer.render(statement)).to eq(
        'MATCH (n) WHERE id(n) = 1 UNWIND labels(n) AS label WITH label WHERE NOT (label IN $fixedLabels) RETURN collect(label) AS labels'
      )
    end

    it 'renders leading unwind' do
      statement = Cypher.unwind(Cypher.literal_of(1), Cypher.literal_true, Cypher.literal_false)
                        .as(:n)
                        .returning(Cypher.name(:n))
                        .build

      expect(renderer.render(statement)).to eq('UNWIND [1, true, false] AS n RETURN n')
    end

    it 'renders leading unwind based on expression collection' do # GH-189
      expressions = [Cypher.literal_of(1), Cypher.literal_true, Cypher.literal_false]
      statement = Cypher.unwind(expressions).as(:n).returning(Cypher.name(:n)).build

      expect(renderer.render(statement)).to eq('UNWIND [1, true, false] AS n RETURN n')
    end

    it 'renders leading unwind with update' do
      statement = Cypher.unwind(Cypher.literal_of(1), Cypher.literal_true, Cypher.literal_false)
                        .as(:n)
                        .merge(bike_node.with_properties('b', Cypher.name(:n)))
                        .returning(bike_node)
                        .build

      expect(renderer.render(statement)).to eq('UNWIND [1, true, false] AS n MERGE (b:`Bike` {b: n}) RETURN b')
    end

    it 'renders leading unwind with create' do
      statement = Cypher.unwind(Cypher.literal_of(1), Cypher.literal_true, Cypher.literal_false)
                        .as(:n)
                        .create(bike_node.with_properties('b', Cypher.name(:n)))
                        .returning(bike_node)
                        .build

      expect(renderer.render(statement)).to eq('UNWIND [1, true, false] AS n CREATE (b:`Bike` {b: n}) RETURN b')
    end

    it 'renders unwind' do
      collected = Cypher.collect(bike_node).as(:collected)
      statement = Cypher.match(bike_node)
                        .with(collected)
                        .unwind(collected)
                        .as(:x)
                        .with(:x)
                        .delete(Cypher.name(:x))
                        .returning(:x)
                        .build

      expect(renderer.render(statement))
        .to eq('MATCH (b:`Bike`) WITH collect(b) AS collected UNWIND collected AS x WITH x DELETE x RETURN x')
    end
  end
end
