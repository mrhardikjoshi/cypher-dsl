# frozen_string_literal: true

# Translated from CypherIT.java, nested classes Expressions, OperationsAndComparisons and
# ExpressionsRendering.
#
# Skipped on purpose:
# - preconditionsShouldBeAssertedOnUnary: exercises the Java-internal `Operation.create` factory.
module CypherDSL
  RSpec.describe 'CypherIT / Expressions' do
    let(:user_node) { Cypher.node('User').named(:u) }
    let(:renderer) { Renderer.default }

    it 'renders parameters' do
      statement = Cypher.match(user_node)
                        .where(user_node.property(:a).is_equal_to(Cypher.parameter(:aParameter)))
                        .detach_delete(user_node)
                        .returning(user_node)
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) WHERE u.a = $aParameter DETACH DELETE u RETURN u')
    end
  end

  RSpec.describe 'CypherIT / OperationsAndComparisons' do
    let(:renderer) { Renderer.default }

    {
      'Unary minus' => [-> { Cypher.minus(Cypher.literal_of(1)) }, 'RETURN -1'],
      'Unary plus' => [-> { Cypher.plus(Cypher.literal_of(1)) }, 'RETURN +1']
    }.each do |name, (operator, expected)|
      it "unary operators should work: #{name}" do
        expect(renderer.render(Cypher.returning(operator.call).build)).to eq(expected)
      end
    end

    it 'renders operations' do
      statement = Cypher.match(Cypher.any_node(:n))
                        .returning(Cypher.literal_of(1).add(Cypher.literal_of(2)))
                        .build

      expect(renderer.render(statement)).to eq('MATCH (n) RETURN (1 + 2)')
    end

    it 'renders comparision' do
      statement = Cypher.match(Cypher.any_node(:n))
                        .returning(Cypher.literal_of(1).gt(Cypher.literal_of(2)))
                        .build

      expect(renderer.render(statement)).to eq('MATCH (n) RETURN 1 > 2')

      statement = Cypher.match(Cypher.any_node(:n))
                        .returning(Cypher.literal_of(1).gt(Cypher.literal_of(2)).is_true)
                        .build

      expect(renderer.render(statement)).to eq('MATCH (n) RETURN (1 > 2) = true')

      statement = Cypher.match(Cypher.any_node(:n))
                        .returning(Cypher.literal_of(1).gt(Cypher.literal_of(2)).is_true.is_false)
                        .build

      expect(renderer.render(statement)).to eq('MATCH (n) RETURN ((1 > 2) = true) = false')
    end
  end

  RSpec.describe 'CypherIT / ExpressionsRendering' do
    let(:renderer) { Renderer.default }

    it 'renders map' do
      map = Cypher.map_of('latitude', Cypher.parameter(:latitude), 'longitude', Cypher.parameter(:longitude),
                          'crs', Cypher.literal_of('WGS-84'))
      statement = Cypher.match(Cypher.any_node(:n)).returning(Cypher.point(map)).build

      expect(renderer.render(statement))
        .to eq("MATCH (n) RETURN point({latitude: $latitude, longitude: $longitude, crs: 'WGS-84'})")
    end

    it 'renders point function' do
      n = Cypher.any_node(:n)
      statement = Cypher.match(n)
                        .where(Cypher.distance(n.property(:location), Cypher.point(Cypher.parameter('point.point')))
                                     .gt(Cypher.parameter('point.distance')))
                        .returning(n)
                        .build

      expect(renderer.render(statement))
        .to eq('MATCH (n) WHERE point.distance(n.location, point($point.point)) > $point.distance RETURN n')
    end
  end
end
