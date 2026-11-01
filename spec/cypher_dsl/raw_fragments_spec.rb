# frozen_string_literal: true

# Ruby-only, no upstream counterpart: raw fragments (`Cypher.raw`) accepted where host
# DSLs built on strings need them, i.e. as pattern elements, as conditions inside compound
# conditions, as SET operations and as whole clauses (`raw_clause`).
module CypherDSL
  RSpec.describe 'Raw fragments (Ruby extension)' do
    let(:n) { Cypher.any_node(:n) }

    describe 'as pattern elements' do
      it 'renders raw patterns in MATCH, CREATE and MERGE' do
        expect(Cypher.match(Cypher.raw('(n)-->(m)')).returning(:n).build.cypher).to eq('MATCH (n)-->(m) RETURN n')
        expect(Cypher.create(Cypher.raw('(:Person)')).build.cypher).to eq('CREATE (:Person)')
        expect(Cypher.merge(Cypher.raw('(:Person)')).build.cypher).to eq('MERGE (:Person)')
      end

      it 'mixes raw and typed patterns and renders embedded expressions' do
        map = Cypher.map_of('name', Cypher.parameter(:name, 'A'))
        statement = Cypher.match(Cypher.node('Person').named(:p), RawExpression.new(['(n:Movie ', map, ')']))
                          .returning(:p).build
        expect(statement.cypher).to eq('MATCH (p:`Person`), (n:Movie {name: $name}) RETURN p')
        expect(statement.parameters).to eq('name' => 'A')
      end
    end

    describe 'as conditions' do
      it 'renders a single raw condition verbatim' do
        expect(Cypher.match(n).where(Cypher.raw('n.age > 30')).returning(:n).build.cypher)
          .to eq('MATCH (n) WHERE n.age > 30 RETURN n')
      end

      it 'is accepted by and, or and xor' do
        condition = Cypher.property(:n, :a).is_equal_to(1).and(Cypher.raw('n.b > 2')).or(Cypher.raw('(n.c)'))
        expect(Cypher.match(n).where(condition).returning(:n).build.cypher)
          .to eq('MATCH (n) WHERE ((n.a = 1 AND (n.b > 2)) OR (n.c)) RETURN n')
      end

      it 'parenthesises raw operands of a compound condition unless they already are one group' do
        condition = Cypher.raw('n.a = 1 OR n.b = 2').as_condition.and(Cypher.raw('(n.c = 3) OR (n.d = 4)'))
        expect(Cypher.match(n).where(condition).returning(:n).build.cypher)
          .to eq('MATCH (n) WHERE ((n.a = 1 OR n.b = 2) AND ((n.c = 3) OR (n.d = 4))) RETURN n')
      end

      it 'negates raw conditions' do
        expect(Cypher.match(n).where(Cypher.not(Cypher.raw('n.a > 1'))).returning(:n).build.cypher)
          .to eq('MATCH (n) WHERE NOT (n.a > 1) RETURN n')
      end
    end

    describe 'as SET operations' do
      it 'renders raw operations next to typed ones' do
        statement = Cypher.match(n).set(Cypher.raw('n = {name: "Brian"}'), Cypher.set(n.property(:age), 30)).build
        expect(statement.cypher).to eq('MATCH (n) SET n = {name: "Brian"}, n.age = 30')
      end

      it 'renders raw operations in ON CREATE / ON MATCH' do
        statement = Cypher.merge(n).on_create.set(Cypher.raw('n.created = timestamp()')).on_match.set(Cypher.raw('n.seen = 1')).build
        expect(statement.cypher).to eq('MERGE (n) ON CREATE SET n.created = timestamp() ON MATCH SET n.seen = 1')
      end
    end

    describe 'raw_clause' do
      it 'renders the text verbatim as its own clause' do
        statement = Statement.builder.raw_clause('CALL db.labels() YIELD label').returning(:label).build
        expect(statement.cypher).to eq('CALL db.labels() YIELD label RETURN label')
      end

      it 'takes the arguments of Cypher.raw' do
        statement = Cypher.match(n).raw_clause('WHERE $E', Cypher.property(:n, :a).is_equal_to(Cypher.parameter(:a, 1)))
                          .returning(:n).build
        expect(statement.cypher).to eq('MATCH (n) WHERE n.a = $a RETURN n')
        expect(statement.parameters).to eq('a' => 1)
      end

      it 'takes a ready raw expression' do
        statement = Cypher.match(n).raw_clause(RawExpression.new(['ORDER BY ', Cypher.property(:n, :a).descending])).build
        expect(statement.cypher).to eq('MATCH (n) ORDER BY n.a DESC')
      end

      it 'cannot be refined' do
        expect { Statement.builder.raw_clause('START n = node(1)').where(Cypher.raw('true')) }.to raise_error(ArgumentError)
      end
    end
  end
end
