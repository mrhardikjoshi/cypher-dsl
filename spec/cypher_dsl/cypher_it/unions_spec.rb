# frozen_string_literal: true

# Translated from CypherIT.java, nested class Unions.
module CypherDSL
  RSpec.describe 'CypherIT / Unions' do
    let(:bike_node) { Cypher.node('Bike').named(:b) }
    let(:renderer) { Renderer.default }

    def bikes_where(property, value)
      Cypher.match(bike_node)
            .where(bike_node.property(property).is_equal_to(Cypher.literal_of(value)))
            .returning(bike_node)
            .build
    end

    it 'renders unions' do
      statement = Cypher.union(bikes_where(:a, 'A'), bikes_where(:b, 'B'), bikes_where(:c, 'C'))

      expect(renderer.render(statement)).to eq(
        "MATCH (b:`Bike`) WHERE b.a = 'A' RETURN b UNION MATCH (b:`Bike`) WHERE b.b = 'B' RETURN b UNION MATCH (b:`Bike`) WHERE b.c = 'C' RETURN b"
      )
    end

    it 'renders unions based on statement collections' do # GH-189
      statements = [bikes_where(:a, 'A'), bikes_where(:b, 'B'), bikes_where(:c, 'C')]
      statement = Cypher.union(statements)

      expect(renderer.render(statement)).to eq(
        "MATCH (b:`Bike`) WHERE b.a = 'A' RETURN b UNION MATCH (b:`Bike`) WHERE b.b = 'B' RETURN b UNION MATCH (b:`Bike`) WHERE b.c = 'C' RETURN b"
      )
    end

    it 'renders all unions' do
      statement = Cypher.union_all(bikes_where(:a, 'A'), bikes_where(:b, 'B'))

      expect(renderer.render(statement))
        .to eq("MATCH (b:`Bike`) WHERE b.a = 'A' RETURN b UNION ALL MATCH (b:`Bike`) WHERE b.b = 'B' RETURN b")
    end

    it 'renders all unions based on statement collections' do # GH-189
      statement = Cypher.union_all([bikes_where(:a, 'A'), bikes_where(:b, 'B')])

      expect(renderer.render(statement))
        .to eq("MATCH (b:`Bike`) WHERE b.a = 'A' RETURN b UNION ALL MATCH (b:`Bike`) WHERE b.b = 'B' RETURN b")
    end

    it 'appends to existing unions' do
      statement = Cypher.union_all(bikes_where(:a, 'A'), bikes_where(:b, 'B'))
      statement = Cypher.union_all(statement, bikes_where(:c, 'C'), bikes_where(:d, 'D'))

      expect(renderer.render(statement)).to eq(
        "MATCH (b:`Bike`) WHERE b.a = 'A' RETURN b UNION ALL MATCH (b:`Bike`) WHERE b.b = 'B' RETURN b UNION ALL MATCH (b:`Bike`) WHERE b.c = 'C' RETURN b UNION ALL MATCH (b:`Bike`) WHERE b.d = 'D' RETURN b"
      )
    end

    it 'does not mix' do
      statement = Cypher.union_all(bikes_where(:a, 'A'), bikes_where(:b, 'B'))

      expect { Cypher.union(statement, bikes_where(:c, 'C')) }
        .to raise_error(ArgumentError, 'Cannot mix union and union all!')
    end
  end
end
