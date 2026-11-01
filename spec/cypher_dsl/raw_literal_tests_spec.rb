# frozen_string_literal: true

# Translated from RawLiteralTests.java.
#
# `Cypher.raw` replaces `$E` placeholders with the arguments passed to it; a literal
# `$E` is written as `\$E`.
module CypherDSL
  RSpec.describe 'RawLiteralTests' do
    it 'works without place holder' do
      cypher = Cypher.returning(Cypher.raw('1 * 2').as(:result)).build.cypher
      expect(cypher).to eq('RETURN 1 * 2 AS result')
    end

    it 'unescapes escaped placeholders' do
      cypher = Cypher.returning(Cypher.raw('\$E * \$E').as(:result)).build.cypher
      expect(cypher).to eq('RETURN $E * $E AS result')
    end

    it 'no arguments' do
      expect { Cypher.raw('$E + 23 * $E') }
        .to raise_error(ArgumentError, /\AToo few arguments for the raw literal format `/)
    end

    it 'too few arguments' do
      expect { Cypher.raw('$E + 23 * $E', Cypher.literal_of(1)) }
        .to raise_error(ArgumentError, /\AToo few arguments for the raw literal format `/)
    end

    it 'too many arguments' do
      expect { Cypher.raw('$E + 23 * $E', Cypher.literal_of(1), Cypher.literal_of(2), Cypher.literal_of(3)) }
        .to raise_error(ArgumentError, /\AToo many arguments for the raw literal format `/)
    end

    it 'mixed arguments' do
      cypher = Cypher.returning(Cypher.raw('($E + $E) + \$E', Cypher.parameter(:summand1), 2).as(:result)).build.cypher
      expect(cypher).to eq('RETURN ($summand1 + 2) + $E AS result')
    end

    it 'mixed arguments2' do
      cypher = Cypher.returning(Cypher.raw('($E + $E) + \$E', Cypher.parameter(:summand1), 2, Cypher.parameter(:E)).as(:result))
                     .build
                     .cypher
      expect(cypher).to eq('RETURN ($summand1 + 2) + $E AS result')
    end

    it 'mixed arguments3' do
      expect { Cypher.raw('($E + $E) + \$E', Cypher.parameter(:summand1), 2, Cypher.parameter(:F)) }
        .to raise_error(ArgumentError, /\AToo many arguments for the raw literal format `/)
    end

    it 'string literal' do
      cypher = Cypher.returning(Cypher.raw('size($E)', 'test').as(:result)).build.cypher
      expect(cypher).to eq("RETURN size('test') AS result")
    end

    it 'with param as expression' do # GH-187
      user_provided_cypher = 'MATCH (this)-[:LINK]-(o:Other) WHERE o.name = $E RETURN o'
      cypher = Cypher.match(Cypher.any_node.named(:this))
                     .with(:this)
                     .returning_raw(Cypher.raw(user_provided_cypher, Cypher.parameter(:name).with_value('fooo')).as(:result))
                     .build
                     .cypher
      expect(cypher).to eq('MATCH (this) WITH this MATCH (this)-[:LINK]-(o:Other) WHERE o.name = $name RETURN o AS result')
    end

    it 'with param' do
      user_provided_cypher = 'MATCH (this)-[:LINK]-(o:Other) WHERE 1 = $E OR (o.name = $name AND $E IS NOT NULL) RETURN o'
      [
        [Cypher.literal_of(1), Cypher.literal_of('whatever'), Cypher.parameter(:name).with_value('fooo')],
        [Cypher.literal_of(1), Cypher.parameter(:name).with_value('fooo'), Cypher.literal_of('whatever')],
        [Cypher.literal_of(1), Cypher.literal_of('whatever')],
        [Cypher.parameter(:name).with_value('fooo'), Cypher.literal_of(1), Cypher.literal_of('whatever')]
      ].each do |args|
        cypher = Cypher.match(Cypher.any_node.named(:this))
                       .with(:this)
                       .returning_raw(Cypher.raw(user_provided_cypher, *args).as(:result))
                       .build
                       .cypher
        expect(cypher).to eq(
          "MATCH (this) WITH this MATCH (this)-[:LINK]-(o:Other) WHERE 1 = 1 OR (o.name = $name AND 'whatever' IS NOT NULL) RETURN o AS result"
        )
      end
    end

    it 'with param simple' do
      user_provided_cypher = 'MATCH (this)-[:LINK]-(o:Other) WHERE o.name = $name RETURN o'
      cypher = Cypher.match(Cypher.any_node.named(:this))
                     .with(:this)
                     .returning_raw(Cypher.raw(user_provided_cypher, Cypher.parameter(:name).with_value('fooo')).as(:result))
                     .build
                     .cypher
      expect(cypher).to eq('MATCH (this) WITH this MATCH (this)-[:LINK]-(o:Other) WHERE o.name = $name RETURN o AS result')
    end

    it 'with param simple no args' do
      user_provided_cypher = 'MATCH (this)-[:LINK]-(o:Other) WHERE o.name = $name RETURN o'
      cypher = Cypher.match(Cypher.any_node.named(:this))
                     .with(:this)
                     .returning_raw(Cypher.raw(user_provided_cypher).as(:result))
                     .build
                     .cypher
      expect(cypher).to eq('MATCH (this) WITH this MATCH (this)-[:LINK]-(o:Other) WHERE o.name = $name RETURN o AS result')
    end

    it 'unescapes escaped placeholders and use them' do
      cypher = Cypher.returning(Cypher.raw('\$E * \$E', Cypher.parameter(:E)).as(:result)).build.cypher
      expect(cypher).to eq('RETURN $E * $E AS result')
      cypher = Cypher.returning(Cypher.raw('\$E   * \$E', Cypher.parameter(:E)).as(:result)).build.cypher
      expect(cypher).to eq('RETURN $E   * $E AS result')
    end

    it 'unescapes escaped placeholders and use them and blanks dont matter' do
      cypher = Cypher.returning(Cypher.raw("\\$E   * \\$E\n", Cypher.parameter(:E)).as(:result)).build.cypher
      expect(cypher).to eq("RETURN $E   * $E\n AS result")
    end

    it 'only expression arguments' do
      cypher = Cypher.returning(Cypher.raw('$E + $E', Cypher.literal_of(1), Cypher.literal_of(2)).as(:result)).build.cypher
      expect(cypher).to eq('RETURN 1 + 2 AS result')
    end
  end
end
