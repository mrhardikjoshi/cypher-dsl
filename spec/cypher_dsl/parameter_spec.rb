# frozen_string_literal: true

# Translated from ParameterIT.java.
#
# Adapted: `parameterNamesShouldBeSanitized` checks `to_s` (`$name`) instead of the Java
# `Parameter{cypher=…}` toString format.
module CypherDSL
  RSpec.describe 'ParameterIT' do
    let(:user_node) { Cypher.node('User').named(:u) }

    it 'collects parameters' do
      statement = Cypher.match(user_node)
                        .where(user_node.property(:name).is_equal_to(Cypher.parameter(:name, 'Neo')))
                        .returning(user_node)
                        .limit(Cypher.parameter(:param).with_value(5))
                        .build

      expect(statement.catalog.parameters).to include('param' => 5, 'name' => 'Neo')
      expect(statement.catalog.parameter_names).to contain_exactly('param', 'name')
    end

    it 'collects parameters only once' do
      statement = Cypher.match(user_node)
                        .where(user_node.property(:cnt).is_equal_to(Cypher.parameter(:param, 5)))
                        .and(Cypher.anon_parameter('y').is_true)
                        .or(Cypher.anon_parameter('y').is_false)
                        .and(Cypher.anon_parameter('z').is_true)
                        .or(Cypher.anon_parameter('z').is_false)
                        .returning(user_node)
                        .limit(Cypher.parameter(:param).with_value(5))
                        .build

      expect(statement.catalog.parameters).to eq('param' => 5, 'pcdsl01' => 'y', 'pcdsl02' => 'z')
    end

    it 'equals should work' do
      p1 = Cypher.anon_parameter('y')
      p2 = Cypher.anon_parameter('y')
      p3 = Cypher.anon_parameter('z')
      p4 = Cypher.parameter('pcdsl01', 'z')
      expect(p1).to eq(p1) # rubocop:disable RSpec/IdenticalEqualityAssertion
      expect(p1).to eq(p2)
      expect(p1).not_to eq(p3)
      expect(p1).not_to eq(p4)
    end

    it 'parameter names should be sanitized' do
      p1 = Cypher.parameter('pcdsl01', 'z')
      expect(p1.to_s).to eq('$pcdsl01')

      p2 = Cypher.parameter("Hallo ' ` das", 'z')
      expect(p2.to_s).to eq("$`Hallo ' `` das`")
    end

    it 'deals with null values' do
      statement = Cypher.match(user_node)
                        .set(user_node.property(:name).to(Cypher.parameter(:param).with_value(nil)))
                        .returning(user_node)
                        .build

      expect(Renderer.default.render(statement)).to eq('MATCH (u:`User`) SET u.name = $param RETURN u')
      expect(statement.catalog.parameters).to include('param' => nil)
    end

    ['x', nil].each do |value|
      it "fails with no value vs null (bound first, value #{value.inspect})" do
        statement = Cypher.match(user_node)
                          .set(user_node.property(:name).to(Cypher.parameter(:param).with_value(value)),
                               user_node.property(:firstName).to(Cypher.parameter(:param)))
                          .returning(user_node)
                          .build
        expect { statement.catalog }.to raise_error(ConflictingParametersException)
      end

      it "fails with no value vs null (unbound first, value #{value.inspect})" do
        statement = Cypher.match(user_node)
                          .set(user_node.property(:firstName).to(Cypher.parameter(:param)),
                               user_node.property(:name).to(Cypher.parameter(:param).with_value(value)))
                          .returning(user_node)
                          .build
        expect { statement.catalog }.to raise_error(ConflictingParametersException)
      end
    end

    it 'does not fail with same name and multiple nul l values' do
      statement = Cypher.match(user_node)
                        .set(user_node.property(:name).to(Cypher.parameter(:param).with_value(nil)),
                             user_node.property(:firstName).to(Cypher.parameter(:param).with_value(nil)))
                        .returning(user_node)
                        .build

      expect(Renderer.default.render(statement)).to eq('MATCH (u:`User`) SET u.name = $param, u.firstName = $param RETURN u')
      expect(statement.catalog.parameters).to include('param' => nil)
    end

    it 'does not fail with same name and no value' do
      statement = Cypher.match(user_node)
                        .set(user_node.property(:name).to(Cypher.parameter(:param)),
                             user_node.property(:firstName).to(Cypher.parameter(:param)))
                        .returning(user_node)
                        .build

      expect(Renderer.default.render(statement)).to eq('MATCH (u:`User`) SET u.name = $param, u.firstName = $param RETURN u')
      expect(statement.catalog.parameters).to be_empty
      expect(statement.catalog.parameter_names).to contain_exactly('param')
    end

    it 'fails on different bound values' do
      statement = Cypher.match(user_node)
                        .returning(user_node)
                        .skip(Cypher.parameter(:param).with_value(1))
                        .limit(Cypher.parameter(:param).with_value(5))
                        .build

      expect { statement.catalog }.to raise_error(ConflictingParametersException) do |e|
        expect(e.erroneous_parameters).to have_key('param')
        expect(e.erroneous_parameters['param']).to contain_exactly(1, 5)
      end
    end

    it 'fails on different bound values when same value is used twice' do
      statement = Cypher.match(user_node)
                        .where(user_node.internal_id.is_equal_to(Cypher.parameter(:param).with_value(5)))
                        .returning(user_node)
                        .skip(Cypher.parameter(:param).with_value(1))
                        .limit(Cypher.parameter(:param).with_value(1))
                        .build

      expect { statement.catalog }.to raise_error(ConflictingParametersException) do |e|
        expect(e.erroneous_parameters).to have_key('param')
        expect(e.erroneous_parameters['param']).to contain_exactly(1, 5)
      end
    end

    it 'works with unions' do
      bike_node = Cypher.node('Bike').named(:b)

      statement1 = Cypher.match(bike_node)
                         .where(bike_node.property(:a).is_equal_to(Cypher.parameter(:p1).with_value('A')))
                         .returning(bike_node)
                         .build
      expect(statement1.catalog.parameters).to include('p1' => 'A')

      statement2 = Cypher.match(bike_node)
                         .where(bike_node.property(:b).is_equal_to(Cypher.parameter(:p2).with_value('B')))
                         .returning(bike_node)
                         .build
      expect(statement2.catalog.parameters).to include('p2' => 'B')

      statement3 = Cypher.match(bike_node)
                         .where(bike_node.property(:c).is_equal_to(Cypher.parameter(:p3).with_value('C')))
                         .returning(bike_node)
                         .build
      expect(statement3.catalog.parameters).to include('p3' => 'C')

      statement = Cypher.union(statement1, statement2, statement3)

      expect(Renderer.default.render(statement)).to eq(
        'MATCH (b:`Bike`) WHERE b.a = $p1 RETURN b UNION MATCH (b:`Bike`) WHERE b.b = $p2 RETURN b UNION MATCH (b:`Bike`) WHERE b.c = $p3 RETURN b'
      )

      expect(statement.catalog.parameters).to include('p1' => 'A', 'p2' => 'B', 'p3' => 'C')
    end
  end
end
