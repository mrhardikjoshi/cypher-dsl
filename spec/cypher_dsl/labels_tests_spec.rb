# frozen_string_literal: true

# Translated from LabelsTests.java.
module CypherDSL
  RSpec.describe 'LabelsTests' do
    let(:simple_or) { Labels.exactly('Person').or(Labels.exactly('Organization')) }
    let(:or_and_not) { simple_or.and(Labels.exactly('Sanctioned').negate) }

    it 'label expressions should work 1' do # GH-1077
      node = Cypher.node(simple_or).named(:n)
      cypher = Cypher.match(node).returning(node).build.cypher

      expect(cypher).to eq('MATCH (n:`Person`|`Organization`) RETURN n')
    end

    it 'label expressions should work 2' do # GH-1077
      node = Cypher.node(or_and_not).named(:n)
      cypher = Cypher.match(node).returning(node).build.cypher

      expect(cypher).to eq('MATCH (n:(`Person`|`Organization`)&!`Sanctioned`) RETURN n')
    end

    it 'matches labels dynamically' do
      labels = Cypher.list_of(Cypher.literal_of('Person'), Cypher.literal_of('Director')).as(:labels)
      directors = Cypher.node(Cypher.all_labels(labels)).named(:directors)
      stmt = Cypher.with(labels).match(directors).returning(directors).build
      expect(stmt.cypher).to eq("WITH ['Person', 'Director'] AS labels MATCH (directors:$(labels)) RETURN directors")
    end

    it 'matches nodes dynamically using any' do
      labels = Cypher.list_of(Cypher.literal_of('Movie'), Cypher.literal_of('Actor'))
      n = Cypher.node(Cypher.any_label(labels)).named(:n)
      stmt = Cypher.match(n).returning(n.as(:nodes)).build
      expect(stmt.cypher).to eq("MATCH (n:$any(['Movie', 'Actor'])) RETURN n AS nodes")
    end

    it 'combination with label expressions should work' do
      labels = Cypher.any_label(Cypher.list_of(Cypher.literal_of('Movie'), Cypher.literal_of('Actor')))
                     .and(Cypher.exactly_label('Foo'))
                     .or(Cypher.exactly_label('Bar').and(Cypher.all_labels(Cypher.parameter(:IWantToDie))))
      n = Cypher.node(labels).named(:n)
      stmt = Cypher.match(n).returning(n.as(:nodes)).build
      expect(stmt.cypher).to eq("MATCH (n:$any(['Movie', 'Actor'])&`Foo`|`Bar`&$($IWantToDie)) RETURN n AS nodes")
    end

    it 'dynamic conjunctions should work' do
      labels = Cypher.all_labels(Cypher.parameter(:a)).or(Cypher.any_label(Cypher.parameter(:b)))
      n = Cypher.node(labels).named(:n)
      stmt = Cypher.match(n).returning(n.as(:nodes)).build
      expect(stmt.cypher).to eq('MATCH (n:$($a)|$any($b)) RETURN n AS nodes')
    end

    it 'dynamic set wrong type 1' do
      labels = Cypher.all_labels(Cypher.parameter(:a)).or(Cypher.any_label(Cypher.parameter(:b)))
      n = Cypher.node('Whatever').named(:n)
      match = Cypher.match(n)
      expect { match.set(n, labels) }
        .to raise_error(ArgumentError, 'Only a single dynamic label expression or a set of static labels might be used in an updating clause')
    end

    it 'dynamic remove wrong type 1' do
      labels = Cypher.all_labels(Cypher.parameter(:a)).or(Cypher.any_label(Cypher.parameter(:b)))
      n = Cypher.node('Whatever').named(:n)
      match = Cypher.match(n)
      expect { match.remove(n, labels) }
        .to raise_error(ArgumentError, 'Only a single dynamic label expression or a set of static labels might be used in an updating clause')
    end

    it 'dynamic set wrong selector' do
      labels = Cypher.any_label(Cypher.parameter(:a))
      n = Cypher.node('Whatever').named(:n)
      match = Cypher.match(n)
      expect { match.set(n, labels) }
        .to raise_error(ArgumentError, 'Only a single dynamic label expression or a set of static labels might be used in an updating clause')
    end

    it 'dynamic remove wrong selector' do
      labels = Cypher.any_label(Cypher.parameter(:a))
      n = Cypher.node('Whatever').named(:n)
      match = Cypher.match(n)
      expect { match.remove(n, labels) }
        .to raise_error(ArgumentError, 'Only a single dynamic label expression or a set of static labels might be used in an updating clause')
    end

    it 'dynamic set all' do
      labels = Cypher.all_labels(Cypher.parameter(:a))
      n = Cypher.node('Whatever').named(:n)
      stmt = Cypher.match(n).set(n, labels).build
      expect(stmt.cypher).to eq('MATCH (n:`Whatever`) SET n:$($a)')
    end

    it 'dynamic remove all' do
      labels = Cypher.all_labels(Cypher.parameter(:a))
      n = Cypher.node('Whatever').named(:n)
      stmt = Cypher.match(n).remove(n, labels).build
      expect(stmt.cypher).to eq('MATCH (n:`Whatever`) REMOVE n:$($a)')
    end

    it 'dynamic set all colon' do
      labels = Cypher.all_labels(Cypher.parameter(:a)).conjunction_with(Cypher.all_labels(Cypher.parameter(:b)))
      n = Cypher.node('Whatever').named(:n)
      stmt = Cypher.match(n).set(n, labels).build
      expect(stmt.cypher).to eq('MATCH (n:`Whatever`) SET n:$($a):$($b)')
    end

    it 'dynamic remove all colon' do
      labels = Cypher.all_labels(Cypher.parameter(:a)).conjunction_with(Cypher.all_labels(Cypher.parameter(:b)))
      n = Cypher.node('Whatever').named(:n)
      stmt = Cypher.match(n).remove(n, labels).build
      expect(stmt.cypher).to eq('MATCH (n:`Whatever`) REMOVE n:$($a):$($b)')
    end

    it 'dynamic set all colon mixed' do
      labels = Cypher.all_labels(Cypher.parameter(:a))
                     .conjunction_with(Cypher.all_labels(Cypher.parameter(:b)))
                     .conjunction_with(Labels.exactly('OhBuggerOff'))
      n = Cypher.node('Whatever').named(:n)
      stmt = Cypher.match(n).set(n, labels).build
      expect(stmt.cypher).to eq('MATCH (n:`Whatever`) SET n:$($a):$($b):`OhBuggerOff`')
    end

    it 'dynamic remove all colon mixed' do
      labels = Cypher.all_labels(Cypher.parameter(:a))
                     .conjunction_with(Cypher.all_labels(Cypher.parameter(:b)))
                     .conjunction_with(Labels.exactly('OhBuggerOff'))
      n = Cypher.node('Whatever').named(:n)
      stmt = Cypher.match(n).remove(n, labels).build
      expect(stmt.cypher).to eq('MATCH (n:`Whatever`) REMOVE n:$($a):$($b):`OhBuggerOff`')
    end

    it 'labels as parameters must be in the catalog' do
      labels = Cypher.all_labels(Cypher.parameter(:a, 'X')).conjunction_with(Cypher.all_labels(Cypher.parameter(:b, 'Y')))
      n = Cypher.node('Whatever').named(:n)
      stmt = Cypher.match(n).remove(n, labels).build
      expect(stmt.cypher).to eq('MATCH (n:`Whatever`) REMOVE n:$($a):$($b)')
      expect(stmt.catalog.parameter_names).to eq(%w[a b])
      expect(stmt.catalog.parameters).to include('a' => 'X', 'b' => 'Y')
    end

    describe 'AsConditions' do
      it 'label expressions should work 1' do # GH-1077
        node = Cypher.any_node(:n)
        cypher = Cypher.match(node).where(node.has_labels(simple_or)).returning(node).build.cypher

        expect(cypher).to eq('MATCH (n) WHERE n:`Person`|`Organization` RETURN n')
      end

      it 'label expressions should work 2' do # GH-1077
        node = Cypher.any_node(:n)
        cypher = Cypher.match(node).where(node.has_labels(or_and_not)).returning(node).build.cypher

        expect(cypher).to eq('MATCH (n) WHERE n:(`Person`|`Organization`)&!`Sanctioned` RETURN n')
      end

      it 'label expressions in predicates' do # GH-1141
        movie_or_film = Labels.exactly('Movie').or(Labels.exactly('Film'))

        a = Cypher.node('Person').with_properties('name', Cypher.literal_of('Keanu Reeves')).named(:a)
        b = Cypher.any_node(:b)

        statement = Cypher.match(a)
                          .returning(Cypher.list_based_on(a.relationship_between(b))
                                           .where(b.has_labels(movie_or_film).and(b.property(:released).is_not_null))
                                           .returning(b.property(:released))
                                           .as(:years))
                          .build
                          .cypher
        expect(statement).to eq(
          "MATCH (a:`Person` {name: 'Keanu Reeves'}) RETURN [(a)--(b) WHERE (b:`Movie`|`Film` AND b.released IS NOT NULL) | b.released] AS years"
        )

        statement = Cypher.match(a)
                          .returning(Cypher.list_based_on(a.relationship_between(b))
                                           .where(b.has_labels(movie_or_film)
                                                   .and(b.property(:released).is_not_null)
                                                   .or(b.property(:title).is_equal_to(Cypher.literal_of('The Matrix')))
                                                   .or(b.property(:title).is_equal_to(Cypher.literal_of('The Matrix 2'))))
                                           .returning(b.property(:released))
                                           .as(:years))
                          .build
                          .cypher
        expect(statement).to eq(
          "MATCH (a:`Person` {name: 'Keanu Reeves'}) RETURN [(a)--(b) WHERE ((b:`Movie`|`Film` AND b.released IS NOT NULL) OR b.title = 'The Matrix' OR b.title = 'The Matrix 2') | b.released] AS years"
        )

        statement = Cypher.match(a)
                          .returning(Cypher.list_based_on(a.relationship_between(b))
                                           .where(b.has_labels(movie_or_film))
                                           .and(b.property(:released).is_not_null)
                                           .or(b.property(:title).is_equal_to(Cypher.literal_of('The Matrix')))
                                           .or(b.property(:title).is_equal_to(Cypher.literal_of('The Matrix 2')))
                                           .returning(b.property(:released))
                                           .as(:years))
                          .build
                          .cypher
        expect(statement).to eq(
          "MATCH (a:`Person` {name: 'Keanu Reeves'}) RETURN [(a)--(b) WHERE ((b:`Movie`|`Film` AND b.released IS NOT NULL) OR b.title = 'The Matrix' OR b.title = 'The Matrix 2') | b.released] AS years"
        )

        statement = Cypher.match(a)
                          .returning(Cypher.list_based_on(a.relationship_between(b))
                                           .where(b.has_labels(movie_or_film))
                                           .returning(b.property(:released))
                                           .as(:years))
                          .build
                          .cypher
        expect(statement).to eq(
          "MATCH (a:`Person` {name: 'Keanu Reeves'}) RETURN [(a)--(b) WHERE b:`Movie`|`Film` | b.released] AS years"
        )
      end
    end
  end
end
