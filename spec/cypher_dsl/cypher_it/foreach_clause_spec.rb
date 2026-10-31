# frozen_string_literal: true

# Translated from CypherIT.java, nested class ForeachClause.
module CypherDSL
  RSpec.describe 'CypherIT / ForeachClause' do
    let(:renderer) { Renderer.default }

    let(:merge_on_create) do
      on_create = MergeAction.of(:ON_CREATE, Clauses.set([Cypher.name(:n).property(:prop).to(Cypher.literal_of(1))]))
      Clauses.merge([Cypher.any_node(:n)], [on_create])
    end

    it 'shouldRenderForeach' do
      clause = Clauses.for_each(Cypher.name(:a), Cypher.list_of, [merge_on_create])

      expect(renderer.render(Statement.of([clause]))).to eq('FOREACH (a IN [] | MERGE (n) ON CREATE SET n.prop = 1)')
    end

    it 'shouldRenderNestedForeach' do
      inner = Clauses.for_each(Cypher.name(:a), Cypher.list_of, [merge_on_create])
      clause = Clauses.for_each(Cypher.name(:a), Cypher.list_of, [inner])

      expect(renderer.render(Statement.of([clause])))
        .to eq('FOREACH (a IN [] | FOREACH (a IN [] | MERGE (n) ON CREATE SET n.prop = 1))')
    end

    it 'fakeIfAsDocumentedInKbShouldWork' do
      node = Cypher.node('Node').named(:node).with_properties('id', Cypher.literal_of(12_345))

      needs_update = node.property(:needsUpdate)
      stmt = Cypher.match(node)
                   .foreach(Cypher.name(:i))
                   .in(Cypher.case_expression
                             .when(needs_update)
                             .then(Cypher.list_of(Cypher.literal_of('1')))
                             .else_default(Cypher.list_of))
                   .apply(Clauses.set([Cypher.set(node.property(:newProperty), Cypher.literal_of(5678))]),
                          Clauses.remove([needs_update]),
                          Clauses.set([Cypher.set_label(node, 'Updated')]))
                   .build

      expect(stmt.cypher).to eq(
        "MATCH (node:`Node` {id: 12345}) FOREACH (i IN CASE WHEN node.needsUpdate THEN ['1'] ELSE [] END | SET node.newProperty = 5678 REMOVE node.needsUpdate SET node:`Updated`)"
      )
    end

    it 'foreachCanBeChained' do
      event = Cypher.name(:event)
      create = Cypher.name(:create)
      delete = Cypher.name(:delete)

      t = Cypher.list_of(Cypher.literal_of('1'))
      f = Cypher.list_of

      user = Cypher.node('User')
                   .with_properties('id', Cypher.property(Cypher.property(:event, :keys), :id))
                   .named(:n)
      merge = Clauses.merge([user], [])

      stmt = Cypher.unwind(Cypher.parameter(:messages))
                   .as(event)
                   .with(Cypher.case_expression
                               .when(Cypher.value_at(event, 0).eq(Cypher.literal_of('C')))
                               .then(t)
                               .else_default(f)
                               .as(create),
                         Cypher.case_expression
                               .when(Cypher.value_at(event, 0).eq(Cypher.literal_of('d')))
                               .then(t)
                               .else_default(f)
                               .as(delete),
                         Cypher.value_at(event, 1).as(event))
                   .foreach(Cypher.name(:i))
                   .in(create)
                   .apply(merge,
                          Clauses.set([Cypher.set(user.as_expression, Cypher.property(:event, :properties))]),
                          Clauses.set([Cypher.mutate(user.as_expression, Cypher.property(:event, :keys))]))
                   .foreach(Cypher.name(:i))
                   .in(delete)
                   .apply(merge, Clauses.delete(true, [user.as_expression]))
                   .build
      expect(stmt.cypher).to eq(
        "UNWIND $messages AS event WITH CASE WHEN event[0] = 'C' THEN ['1'] ELSE [] END AS create, CASE WHEN event[0] = 'd' THEN ['1'] ELSE [] END AS delete, event[1] AS event FOREACH (i IN create | MERGE (n:`User` {id: event.keys.id}) SET n = event.properties SET n += event.keys) FOREACH (i IN delete | MERGE (n:`User` {id: event.keys.id}) DETACH DELETE n)"
      )
    end
  end
end
