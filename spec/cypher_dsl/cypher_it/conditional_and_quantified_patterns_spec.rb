# frozen_string_literal: true

# Translated from CypherIT.java, nested classes ConditionalPatterns and QuantifiedPathPatterns.
module CypherDSL
  RSpec.describe 'CypherIT / ConditionalPatterns' do
    it 'nodesWithWhere' do
      node = Cypher.node('Movie').with_properties({ 'title' => 'The Matrix' }).named(:n)
      cypher = Cypher.match(node.where(node.property(:released).eq(Cypher.literal_of(1999))))
                     .returning(node)
                     .build
                     .cypher
      expect(cypher).to eq("MATCH (n:`Movie` {title: 'The Matrix'} WHERE n.released = 1999) RETURN n")
    end

    it 'relationshipsWithWhere' do
      node = Cypher.node('Movie').with_properties({ 'title' => 'The Matrix' }).named(:n)
      actor = Cypher.node('Actor')
      cypher = Cypher
               .match(node.relationship_from(actor, 'ACTED_IN')
                          .named(:r)
                          .where(Cypher.property(:r, :role).eq(Cypher.literal_of('Neo4j'))))
               .returning(Cypher.asterisk)
               .build
               .cypher
      expect(cypher).to eq("MATCH (n:`Movie` {title: 'The Matrix'})<-[r:`ACTED_IN` WHERE r.role = 'Neo4j']-(:`Actor`) RETURN *")
    end
  end

  RSpec.describe 'CypherIT / QuantifiedPathPatterns' do
    let(:relationship_pattern) { Cypher.node('A').named(:a).relationship_to(Cypher.node('B').named(:b), 'X') }

    it 'quantifyShouldWork' do
      cypher = Cypher.match(relationship_pattern.quantify(QuantifiedPathPattern.interval(1, 3)))
                     .returning(Cypher.asterisk)
                     .build
                     .cypher
      expect(cypher).to eq('MATCH ((a:`A`)-[:`X`]->(b:`B`)){1,3} RETURN *')
    end

    it 'nestingInBooleanExpressionIsAllowed' do
      pattern = Cypher.any_node(:n)
                      .relationship_to(Cypher.node('X'))
                      .quantify_relationship(QuantifiedPathPattern.plus)
      inner_rel = Cypher.node('A')
                        .named(:n)
                        .relationship_to(Cypher.any_node.with_properties({ 'p' => 30 }), 'R')
                        .quantify(QuantifiedPathPattern.interval(2, 3))
                        .where(Cypher.exists(pattern))
      cypher = Cypher.match(inner_rel).returning(Cypher.asterisk).build.cypher
      expect(cypher).to eq('MATCH ((n:`A`)-[:`R`]->( {p: 30}) WHERE EXISTS { (n)-->+(:`X`) }){2,3} RETURN *')
    end

    it 'betweenMAndNIterations' do
      cypher = Cypher.match(relationship_pattern.quantify_relationship(QuantifiedPathPattern.interval(1, 3)))
                     .returning(Cypher.asterisk)
                     .build
                     .cypher
      expect(cypher).to eq('MATCH (a:`A`)-[:`X`]->{1,3}(b:`B`) RETURN *')
    end

    it 'oneOrMoreIterations' do
      cypher = Cypher.match(relationship_pattern.quantify_relationship(QuantifiedPathPattern.interval(1, nil)))
                     .returning(Cypher.asterisk)
                     .build
                     .cypher
      expect(cypher).to eq('MATCH (a:`A`)-[:`X`]->{1,}(b:`B`) RETURN *')
    end

    it 'zeroOrMoreIterations' do
      cypher = Cypher.match(relationship_pattern.quantify_relationship(QuantifiedPathPattern.interval(0, nil)))
                     .returning(Cypher.asterisk)
                     .build
                     .cypher
      expect(cypher).to eq('MATCH (a:`A`)-[:`X`]->{0,}(b:`B`) RETURN *')
    end

    it 'nIterations' do
      cypher = Cypher.match(relationship_pattern.quantify_relationship(QuantifiedPathPattern.interval(1, 1)))
                     .returning(Cypher.asterisk)
                     .build
                     .cypher
      expect(cypher).to eq('MATCH (a:`A`)-[:`X`]->{1,1}(b:`B`) RETURN *')
    end

    it 'zeroOrMore' do
      cypher = Cypher.match(relationship_pattern.quantify_relationship(QuantifiedPathPattern.interval(nil, nil)))
                     .returning(Cypher.asterisk)
                     .build
                     .cypher
      expect(cypher).to eq('MATCH (a:`A`)-[:`X`]->{0,}(b:`B`) RETURN *')
    end

    it 'between0AndNIterations' do
      cypher = Cypher.match(relationship_pattern.quantify_relationship(QuantifiedPathPattern.interval(nil, 3)))
                     .returning(Cypher.asterisk)
                     .build
                     .cypher
      expect(cypher).to eq('MATCH (a:`A`)-[:`X`]->{0,3}(b:`B`) RETURN *')
    end

    it 'invalidLower' do
      expect { QuantifiedPathPattern.interval(-1, nil) }
        .to raise_error(ArgumentError, 'Lower bound must be greater than or equal to zero')
    end

    it 'invalidLower1' do
      expect { QuantifiedPathPattern.interval(nil, 0) }
        .to raise_error(ArgumentError, 'Upper bound must be greater than zero')
    end

    it 'invalidLower2' do
      expect { QuantifiedPathPattern.interval(2, 1) }
        .to raise_error(ArgumentError, 'Upper bound must be greater than or equal to 2')
      expect { QuantifiedPathPattern.interval(2, 2) }.not_to raise_error
    end
  end
end
