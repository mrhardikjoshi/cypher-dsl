# frozen_string_literal: true

# Translated from CypherIT.java, nested class Case.
module CypherDSL
  RSpec.describe 'CypherIT / Case' do
    let(:node) { Cypher.node('a').named(:n) }
    let(:renderer) { Renderer.default }

    it 'simpleCase' do
      statement = Cypher.match(node)
                        .where(Cypher.case_expression(node.property(:value))
                                     .when(Cypher.literal_of('blubb'))
                                     .then(Cypher.literal_true)
                                     .as_condition)
                        .returning(node)
                        .build

      expect(renderer.render(statement)).to eq("MATCH (n:`a`) WHERE CASE n.value WHEN 'blubb' THEN true END RETURN n")
    end

    it 'simpleCaseWithElse' do
      statement = Cypher.match(node)
                        .where(Cypher.case_expression(node.property(:value))
                                     .when(Cypher.literal_of('blubb'))
                                     .then(Cypher.literal_true)
                                     .else_default(Cypher.literal_false)
                                     .as_condition)
                        .returning(node)
                        .build

      expect(renderer.render(statement))
        .to eq("MATCH (n:`a`) WHERE CASE n.value WHEN 'blubb' THEN true ELSE false END RETURN n")
    end

    it 'simpleCaseWithMultipleWhenThen' do
      statement = Cypher.match(node)
                        .where(Cypher.case_expression(node.property(:value))
                                     .when(Cypher.literal_of('blubb'))
                                     .then(Cypher.literal_true)
                                     .when(Cypher.literal_of('bla'))
                                     .then(Cypher.literal_false)
                                     .as_condition)
                        .returning(node)
                        .build

      expect(renderer.render(statement))
        .to eq("MATCH (n:`a`) WHERE CASE n.value WHEN 'blubb' THEN true WHEN 'bla' THEN false END RETURN n")
    end

    it 'simpleCaseWithMultipleWhenThenAndElse' do
      statement = Cypher.match(node)
                        .where(Cypher.case_expression(node.property(:value))
                                     .when(Cypher.literal_of('blubb'))
                                     .then(Cypher.literal_true)
                                     .when(Cypher.literal_of('bla'))
                                     .then(Cypher.literal_false)
                                     .else_default(Cypher.literal_of(1))
                                     .as_condition)
                        .returning(node)
                        .build

      expect(renderer.render(statement))
        .to eq("MATCH (n:`a`) WHERE CASE n.value WHEN 'blubb' THEN true WHEN 'bla' THEN false ELSE 1 END RETURN n")
    end

    it 'genericCase' do
      statement = Cypher.match(node)
                        .where(Cypher.case_expression
                                     .when(node.property(:value).is_equal_to(Cypher.literal_of('blubb')))
                                     .then(Cypher.literal_true)
                                     .as_condition)
                        .returning(node)
                        .build

      expect(renderer.render(statement)).to eq("MATCH (n:`a`) WHERE CASE WHEN n.value = 'blubb' THEN true END RETURN n")
    end

    it 'genericCaseWithElse' do
      statement = Cypher.match(node)
                        .where(Cypher.case_expression
                                     .when(node.property(:value).is_equal_to(Cypher.literal_of('blubb')))
                                     .then(Cypher.literal_true)
                                     .else_default(Cypher.literal_false)
                                     .as_condition)
                        .returning(node)
                        .build

      expect(renderer.render(statement))
        .to eq("MATCH (n:`a`) WHERE CASE WHEN n.value = 'blubb' THEN true ELSE false END RETURN n")
    end

    it 'genericCaseWithMultipleWhenThen' do
      statement = Cypher.match(node)
                        .where(Cypher.case_expression
                                     .when(node.property(:value).is_equal_to(Cypher.literal_of('blubb')))
                                     .then(Cypher.literal_true)
                                     .when(node.property(:value).is_equal_to(Cypher.literal_of('bla')))
                                     .then(Cypher.literal_false)
                                     .as_condition)
                        .returning(node)
                        .build

      expect(renderer.render(statement)).to eq(
        "MATCH (n:`a`) WHERE CASE WHEN n.value = 'blubb' THEN true WHEN n.value = 'bla' THEN false END RETURN n"
      )
    end

    it 'genericCaseWithMultipleWhenThenAndElse' do
      statement = Cypher.match(node)
                        .where(Cypher.case_expression
                                     .when(node.property(:value).is_equal_to(Cypher.literal_of('blubb')))
                                     .then(Cypher.literal_true)
                                     .when(node.property(:value).is_equal_to(Cypher.literal_of('bla')))
                                     .then(Cypher.literal_false)
                                     .else_default(Cypher.literal_of(1))
                                     .as_condition)
                        .returning(node)
                        .build

      expect(renderer.render(statement)).to eq(
        "MATCH (n:`a`) WHERE CASE WHEN n.value = 'blubb' THEN true WHEN n.value = 'bla' THEN false ELSE 1 END RETURN n"
      )
    end

    # from https://neo4j.com/docs/cypher-manual/current/syntax/expressions/#syntax-simple-case
    it 'canGetAliasedInReturn' do
      node = Cypher.any_node(:n)
      statement = Cypher.match(node)
                        .returning(Cypher.case_expression(node.property(:eyes))
                                         .when(Cypher.literal_of('blue'))
                                         .then(Cypher.literal_of(1))
                                         .when(Cypher.literal_of('brown'))
                                         .then(Cypher.literal_of(2))
                                         .else_default(Cypher.literal_of(3))
                                         .as(:result))
                        .build

      expect(renderer.render(statement))
        .to eq("MATCH (n) RETURN CASE n.eyes WHEN 'blue' THEN 1 WHEN 'brown' THEN 2 ELSE 3 END AS result")
    end
  end
end
