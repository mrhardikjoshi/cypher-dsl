# frozen_string_literal: true

# Translated from ParameterLiteralTests.java.
#
# Adapted: `Cypher.literal_of(parameter)` hands the parameter back (there is no separate
# parameter literal), so `anonParametersAreUnsupported` has no counterpart.
module CypherDSL
  RSpec.describe 'ParameterLiteralTests' do
    [
      [true, 'blah', 'MATCH (n:`F`) WHERE n.x = $blah RETURN n'],
      [true, 'p OR true OR $q', 'MATCH (n:`F`) WHERE n.x = $`p OR true OR $q` RETURN n'],
      [false, 'blah', 'MATCH (n:`F`) WHERE n.x = $blah RETURN n'],
      [false, 'p OR true OR $q', 'MATCH (n:`F`) WHERE n.x = $`p OR true OR $q` RETURN n']
    ].each do |use_literal, name, expected|
      it "names must be escaped if necessary(#{use_literal}, #{name})" do
        n = Cypher.node('F').named(:n)
        parameter = Cypher.parameter(name)
        q = Cypher.match(n)
                  .where(n.property(:x).is_equal_to(use_literal ? Cypher.literal_of(parameter) : parameter))
                  .returning(n)
                  .build
                  .cypher
        expect(q).to eq(expected)
      end
    end
  end
end
