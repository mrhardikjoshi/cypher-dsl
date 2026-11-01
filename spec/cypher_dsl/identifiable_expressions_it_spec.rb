# frozen_string_literal: true

# Translated from IdentifiableExpressionsIT.java.
module CypherDSL
  RSpec.describe 'IdentifiableExpressionsIT' do
    def formatted(expressions) = expressions.map { |expression| Cypher.format(expression) }

    it 'simple with' do
      b = Cypher.any_node(:b)
      variables = Cypher.match(Cypher.node('Label').named(:a).relationship_to(b))
                        .with(Cypher.name(:a), b)
                        .identifiable_expressions
      expect(formatted(variables)).to contain_exactly('a', 'b')
    end

    it 'multiple hops' do
      b = Cypher.any_node(:b)
      a = Cypher.name(:a)
      variables = Cypher.match(Cypher.node('Label').named(:a).relationship_to(b))
                        .with(a, b)
                        .optional_match(b.relationship_to(Cypher.any_node(:c)))
                        .with(a, Cypher.name(:c))
                        .identifiable_expressions
      expect(formatted(variables)).to contain_exactly('a', 'c')
    end

    it 'complex with' do
      b = Cypher.any_node(:b)
      a = Cypher.node('Label').named(:a)
      variables = Cypher.match(a.relationship_to(b))
                        .with(a, b)
                        .optional_match(b.relationship_to(Cypher.any_node(:c)))
                        .with(a, Cypher.name(:c),
                              Cypher.case_expression
                                    .when(Cypher.name(:c).is_null.or(Cypher.has_labels_or_type(Cypher.name(:c), 'Label')))
                                    .then(Cypher.literal_true)
                                    .else_default(Cypher.literal_false)
                                    .as(:isNullOrLabel))
                        .identifiable_expressions
      expect(formatted(variables)).to contain_exactly('a', 'c', 'isNullOrLabel')
    end

    it 'complex with as statement' do
      b = Cypher.any_node(:b)
      a = Cypher.node('Label').named(:a)
      variables = Cypher.match(a.relationship_to(b))
                        .with(a, b)
                        .optional_match(b.relationship_to(Cypher.any_node(:c)))
                        .returning(a.required_symbolic_name, Cypher.name(:c),
                                   Cypher.case_expression
                                         .when(Cypher.name(:c).is_null.or(Cypher.has_labels_or_type(Cypher.name(:c), 'Label')))
                                         .then(Cypher.literal_true)
                                         .else_default(Cypher.literal_false)
                                         .as(:isNullOrLabel))
                        .build
                        .catalog
                        .identifiable_expressions
      expect(formatted(variables)).to contain_exactly('a', 'c', 'isNullOrLabel')
    end

    it 'none expressions in return' do
      b = Cypher.any_node(:b)
      a = Cypher.node('Label').named(:a)
      variables = Cypher.match(a.relationship_to(b)).returning(a).build.catalog.identifiable_expressions
      expect(formatted(variables)).to contain_exactly('a')
    end

    it 'non identifiable items' do
      b = Cypher.any_node(:b)
      a = Cypher.node('Label').named(:a)
      variables = Cypher.match(a.relationship_to(b)).with(b.as('007')).identifiable_expressions
      expect(formatted(variables)).to contain_exactly('007')
    end

    it 'on return' do
      b = Cypher.any_node(:b)
      variables = Cypher.returning(Cypher.literal_of(1), b.as('007'), b.property(:f)).identifiable_expressions
      expect(formatted(variables)).to contain_exactly('007', 'b.f')
    end

    it 'returned properties' do
      b = Cypher.any_node(:b)
      variables = Cypher.match(b).returning(b.property(:x), b.as('007')).identifiable_expressions
      expect(formatted(variables)).to contain_exactly('b.x', '007')
    end
  end
end
