# frozen_string_literal: true

# Translated from CypherIT.java, nested class MultipleMatches.
#
# Skipped on purpose:
# - usingSameWithStepWithoutReassign, usingSameWithStepWithoutReassignThenUpdate: they rely on the Java
#   builder being mutable (calls without reassignment still change the statement). This builder is
#   immutable by design, so only the reassigning variant applies.
module CypherDSL
  RSpec.describe 'CypherIT / MultipleMatches' do
    let(:bike_node) { Cypher.node('Bike').named(:b) }
    let(:user_node) { Cypher.node('User').named(:u) }
    let(:renderer) { Renderer.default }

    it 'simple' do
      statement = Cypher.match(bike_node)
                        .match(user_node, Cypher.node('U').named(:o))
                        .returning(bike_node)
                        .build

      expect(renderer.render(statement)).to eq('MATCH (b:`Bike`) MATCH (u:`User`), (o:`U`) RETURN b')
    end

    it 'simple with pattern collection' do # GH-189
      statement = Cypher.match([bike_node])
                        .match(user_node, Cypher.node('U').named(:o))
                        .returning(bike_node)
                        .build

      expect(renderer.render(statement)).to eq('MATCH (b:`Bike`) MATCH (u:`User`), (o:`U`) RETURN b')
    end

    it 'simple with pattern collection in exposes match' do # GH-189
      pattern_elements = [user_node, Cypher.node('U').named(:o)]
      statement = Cypher.match([bike_node])
                        .match(pattern_elements)
                        .returning(bike_node)
                        .build

      expect(renderer.render(statement)).to eq('MATCH (b:`Bike`) MATCH (u:`User`), (o:`U`) RETURN b')
    end

    it 'simple where' do
      statement = Cypher.match(bike_node)
                        .match(user_node, Cypher.node('U').named(:o))
                        .where(user_node.property(:a).is_null)
                        .returning(bike_node)
                        .build

      expect(renderer.render(statement)).to eq('MATCH (b:`Bike`) MATCH (u:`User`), (o:`U`) WHERE u.a IS NULL RETURN b')
    end

    it 'multi where' do
      statement = Cypher.match(bike_node)
                        .where(bike_node.property(:a).is_not_null)
                        .match(user_node, Cypher.node('U').named(:o))
                        .where(user_node.property(:a).is_null)
                        .returning(bike_node)
                        .build

      expect(renderer.render(statement)).to eq(
        'MATCH (b:`Bike`) WHERE b.a IS NOT NULL MATCH (u:`User`), (o:`U`) WHERE u.a IS NULL RETURN b'
      )
    end

    it 'multi where multi conditions' do
      statement = Cypher.match(bike_node)
                        .where(bike_node.property(:a).is_not_null)
                        .and(bike_node.property(:b).is_null)
                        .match(user_node, Cypher.node('U').named(:o))
                        .where(user_node.property(:a).is_null
                                        .or(user_node.internal_id.is_equal_to(Cypher.literal_of(4711))))
                        .returning(bike_node)
                        .build

      expect(renderer.render(statement)).to eq(
        'MATCH (b:`Bike`) WHERE (b.a IS NOT NULL AND b.b IS NULL) MATCH (u:`User`), (o:`U`) WHERE (u.a IS NULL OR id(u) = 4711) RETURN b'
      )
    end

    it 'optional' do
      statement = Cypher.optional_match(bike_node)
                        .match(user_node, Cypher.node('U').named(:o))
                        .where(user_node.property(:a).is_null)
                        .returning(bike_node)
                        .build

      expect(renderer.render(statement))
        .to eq('OPTIONAL MATCH (b:`Bike`) MATCH (u:`User`), (o:`U`) WHERE u.a IS NULL RETURN b')
    end

    it 'optional with flag' do
      statement = Cypher.match(true, bike_node)
                        .match(user_node, Cypher.node('U').named(:o))
                        .where(user_node.property(:a).is_null)
                        .returning(bike_node)
                        .build

      expect(renderer.render(statement))
        .to eq('OPTIONAL MATCH (b:`Bike`) MATCH (u:`User`), (o:`U`) WHERE u.a IS NULL RETURN b')
    end

    it 'optional with flag and pattern collection' do # GH-189
      statement = Cypher.match(true, [bike_node])
                        .match(user_node, Cypher.node('U').named(:o))
                        .where(user_node.property(:a).is_null)
                        .returning(bike_node)
                        .build

      expect(renderer.render(statement))
        .to eq('OPTIONAL MATCH (b:`Bike`) MATCH (u:`User`), (o:`U`) WHERE u.a IS NULL RETURN b')
    end

    it 'optional with pattern collection' do # GH-189
      statement = Cypher.optional_match([bike_node])
                        .match(user_node, Cypher.node('U').named(:o))
                        .where(user_node.property(:a).is_null)
                        .returning(bike_node)
                        .build

      expect(renderer.render(statement))
        .to eq('OPTIONAL MATCH (b:`Bike`) MATCH (u:`User`), (o:`U`) WHERE u.a IS NULL RETURN b')
    end

    it 'using same with step with reassign' do
      first_step = Cypher.match(bike_node).with(bike_node)

      first_step = first_step.optional_match(user_node)
      first_step = first_step.optional_match(Cypher.node('Trip'))

      statement = first_step.returning(Cypher.asterisk).build
      expect(renderer.render(statement))
        .to eq('MATCH (b:`Bike`) WITH b OPTIONAL MATCH (u:`User`) OPTIONAL MATCH (:`Trip`) RETURN *')
    end

    it 'query parts should be extractable in queries' do
      # Those can be a couple of queries ending in a WITH statement so the
      # pipeline they present in the full query is also present in Ruby.
      step1 = lambda do |previous|
        previous.match(Cypher.node('S1').named(:n))
                .where(Cypher.property(:n, :a).is_equal_to(Cypher.literal_of('A')))
                .with(:n)
      end
      step2 = lambda do |previous|
        previous.match(Cypher.any_node(:n).relationship_to(Cypher.node('S2').named(:m), 'SOMEHOW_RELATED'))
                .with(:n, :m)
      end

      builder = (step1 >> step2).call(Statement.builder)
      statement = builder.returning(:n, :m).build
      expect(renderer.render(statement)).to eq(
        "MATCH (n:`S1`) WHERE n.a = 'A' WITH n MATCH (n)-[:`SOMEHOW_RELATED`]->(m:`S2`) WITH n, m RETURN n, m"
      )
    end

    it 'optional next' do
      statement = Cypher.match(bike_node)
                        .optional_match(user_node, Cypher.node('U').named(:o))
                        .where(user_node.property(:a).is_null)
                        .returning(bike_node)
                        .build

      expect(renderer.render(statement))
        .to eq('MATCH (b:`Bike`) OPTIONAL MATCH (u:`User`), (o:`U`) WHERE u.a IS NULL RETURN b')
    end

    it 'optional next based on pattern element collection' do
      pattern_elements = [user_node, Cypher.node('U').named(:o)]
      statement = Cypher.match(bike_node)
                        .optional_match(pattern_elements)
                        .where(user_node.property(:a).is_null)
                        .returning(bike_node)
                        .build

      expect(renderer.render(statement))
        .to eq('MATCH (b:`Bike`) OPTIONAL MATCH (u:`User`), (o:`U`) WHERE u.a IS NULL RETURN b')
    end

    it 'optional match then delete' do
      statement = Cypher.match(bike_node)
                        .optional_match(user_node, Cypher.node('U').named(:o))
                        .delete(user_node, bike_node)
                        .build

      expect(renderer.render(statement)).to eq('MATCH (b:`Bike`) OPTIONAL MATCH (u:`User`), (o:`U`) DELETE u, b')
    end
  end
end
