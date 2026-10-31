# frozen_string_literal: true

# Translated from CypherIT.java, nested classes ListOperator, DoubleRendering and Foreach.
#
# Skipped for now:
# - Foreach.inComplexStatement: needs CALL … YIELD and the pretty-printing renderer.
module CypherDSL
  RSpec.describe 'CypherIT / ListOperator' do
    let(:renderer) { Renderer.default }

    it 'valueAtShouldWork' do
      statement = Cypher.returning(Cypher.value_at(Cypher.range(0, 10), 3)).build
      expect(renderer.render(statement)).to eq('RETURN range(0, 10)[3]')
    end

    it 'subListUntilShouldWork' do
      statement = Cypher.returning(Cypher.sub_list_until(Cypher.range(0, 10), 3)).build
      expect(renderer.render(statement)).to eq('RETURN range(0, 10)[..3]')
    end

    it 'subListFromShouldWork' do
      statement = Cypher.returning(Cypher.sub_list_from(Cypher.range(0, 10), -3)).build
      expect(renderer.render(statement)).to eq('RETURN range(0, 10)[-3..]')
    end

    it 'subListShouldWork' do
      statement = Cypher.returning(Cypher.sub_list(Cypher.range(0, 10), 2, 4)).build
      expect(renderer.render(statement)).to eq('RETURN range(0, 10)[2..4]')
    end

    it 'subListUntilExpressionShouldWork' do
      statement = Cypher.returning(Cypher.sub_list_until(Cypher.range(0, 10), Cypher.parameter(:end))).build
      expect(renderer.render(statement)).to eq('RETURN range(0, 10)[..$end]')
    end

    it 'subListFromExpressionShouldWork' do
      statement = Cypher.returning(Cypher.sub_list_from(Cypher.range(0, 10), Cypher.parameter(:start))).build
      expect(renderer.render(statement)).to eq('RETURN range(0, 10)[$start..]')
    end

    it 'subListExpressionShouldWork' do
      statement = Cypher
                  .returning(Cypher.sub_list(Cypher.range(0, 10), Cypher.parameter(:start), Cypher.parameter(:end)))
                  .build
      expect(renderer.render(statement)).to eq('RETURN range(0, 10)[$start..$end]')
    end

    it 'shouldWorkWithMapProjections' do
      person = Cypher.node('Person').named(:person)
      location = Cypher.node('Location').named(:personLivesIn)

      statement = Cypher.match(person)
                        .returning(person.project('livesIn',
                                                  Cypher.value_at(Cypher.list_based_on(person.relationship_to(location, 'LIVES_IN'))
                                                                        .returning(location.project('name')), 0)))
                        .build
      expect(renderer.render(statement)).to eq(
        'MATCH (person:`Person`) RETURN person{livesIn: [(person)-[:`LIVES_IN`]->(personLivesIn:`Location`) | personLivesIn{.name}][0]}'
      )
    end

    it 'shouldSupportExpressions' do
      person = Cypher.node('Person').named(:person)
      location = Cypher.node('Location').named(:personLivesIn)
      statement = Cypher.match(person)
                        .returning(person.project('livesIn',
                                                  Cypher.sub_list(
                                                    Cypher.list_based_on(person.relationship_to(location, 'LIVES_IN'))
                                                          .returning(location.project('name')),
                                                    Cypher.parameter(:personLivedInOffset),
                                                    Cypher.parameter(:personLivedInOffset).add(Cypher.parameter(:personLivedInFirst))
                                                  )))
                        .build
      expect(renderer.render(statement)).to eq(
        'MATCH (person:`Person`) RETURN person{livesIn: [(person)-[:`LIVES_IN`]->(personLivesIn:`Location`) | personLivesIn{.name}][$personLivedInOffset..($personLivedInOffset + $personLivedInFirst)]}'
      )
    end

    it 'propertiesShouldBeAccessibleOnResolvedNodes' do
      nodes = Cypher.name(:nodes)
      cypher = Cypher.match(Cypher.node('Foo').named(:n))
                     .with(Cypher.collect(Cypher.name(:n)).as(:nodes))
                     .returning(Cypher.property(Cypher.value_at(nodes, 0), :foo))
                     .build
                     .cypher
      expect(cypher).to eq('MATCH (n:`Foo`) WITH collect(n) AS nodes RETURN nodes[0].foo')
    end
  end

  RSpec.describe 'CypherIT / DoubleRendering' do
    let(:renderer) { Renderer.default }

    it 'fragmentOfStatementShouldBeReusable' do
      person_node = Cypher.node('Person').named(:p)
      age_property = person_node.property(:age)

      returning = Cypher.match(person_node).returning(:p)
      s1 = returning.order_by(age_property.ascending).limit(1).build
      s2 = returning.order_by(age_property.descending).limit(1).build

      expect(renderer.render(s1)).to eq('MATCH (p:`Person`) RETURN p ORDER BY p.age ASC LIMIT 1')
      expect(renderer.render(s2)).to eq('MATCH (p:`Person`) RETURN p ORDER BY p.age DESC LIMIT 1')
    end

    it 'aliasedFunctionsShouldNotBeRenderedTwiceInProjection' do
      o = Cypher.node('Order').named(:o)
      li = Cypher.node('LineItem').named(:li)
      has_line_items = o.relationship_to(li).named(:h)

      net_amount = Cypher.sum(li.property(:price).multiply(li.property(:quantity))).as(:netAmount)
      total_amount = net_amount.multiply(Cypher.literal_of(1).add(Cypher.parameter(:taxRate))).as(:totalAmount)
      statement = Cypher.match(has_line_items)
                        .where(o.property(:id).is_equal_to(Cypher.parameter(:id)))
                        .with(o.required_symbolic_name, net_amount, total_amount)
                        .returning(o.project(o.property(:x), net_amount, total_amount,
                                             net_amount.multiply(Cypher.parameter(:taxRate)).as(:taxAmount)))
                        .build
      expect(renderer.render(statement)).to eq(
        'MATCH (o:`Order`)-[h]->(li:`LineItem`) WHERE o.id = $id WITH o, sum((li.price * li.quantity)) AS netAmount, (netAmount * (1 + $taxRate)) AS totalAmount RETURN o{.x, netAmount: netAmount, totalAmount: totalAmount, taxAmount: (netAmount * $taxRate)}'
      )
    end

    it 'aliasedFunctionsShouldNotBeRenderedTwiceInReturn' do
      o = Cypher.node('Order').named(:o)
      li = Cypher.node('LineItem').named(:li)
      has_line_items = o.relationship_to(li).named(:h)

      net_amount = Cypher.sum(li.property(:price).multiply(li.property(:quantity))).as(:netAmount)
      total_amount = net_amount.multiply(Cypher.literal_of(1).add(Cypher.parameter(:taxRate))).as(:totalAmount)
      statement = Cypher.match(has_line_items)
                        .where(o.property(:id).is_equal_to(Cypher.parameter(:id)))
                        .with(o.required_symbolic_name, net_amount, total_amount)
                        .returning(net_amount, total_amount)
                        .build
      expect(renderer.render(statement)).to eq(
        'MATCH (o:`Order`)-[h]->(li:`LineItem`) WHERE o.id = $id WITH o, sum((li.price * li.quantity)) AS netAmount, (netAmount * (1 + $taxRate)) AS totalAmount RETURN netAmount, totalAmount'
      )
    end
  end

  RSpec.describe 'CypherIT / Foreach' do
    it 'basic' do
      start = Cypher.any_node(:start)
      finish = Cypher.any_node(:finish)
      p = Cypher.path(:p).defined_by(start.relationship_to(finish).unbounded)
      n = Cypher.name(:n)
      stmnt = Cypher.match(p)
                    .where(start.property(:name).eq(Cypher.literal_of('A')).and(finish.property(:name).eq(Cypher.literal_of('D'))))
                    .foreach(n)
                    .in(Cypher.nodes(p))
                    .apply(Clauses.set([n.property(:marked).to(Cypher.literal_true)]))
                    .build
      expect(stmnt.cypher).to eq(
        "MATCH p = (start)-[*]->(finish) WHERE (start.name = 'A' AND finish.name = 'D') FOREACH (n IN nodes(p) | SET n.marked = true)"
      )
    end

    it 'mixedWithOtherClauses' do
      start = Cypher.any_node(:start)
      finish = Cypher.any_node(:finish)
      p = Cypher.path(:p).defined_by(start.relationship_to(finish).unbounded)
      n = Cypher.name(:n)
      stmnt = Cypher.match(p)
                    .where(start.property(:name).eq(Cypher.literal_of('A')).and(finish.property(:name).eq(Cypher.literal_of('D'))))
                    .set(start.property(:x).to(Cypher.literal_true))
                    .foreach(n)
                    .in(Cypher.nodes(p))
                    .apply(Clauses.set([n.property(:marked).to(Cypher.literal_true), n.property(:foo).to(Cypher.literal_of('bar'))]))
                    .delete(finish)
                    .build
      expect(stmnt.cypher).to eq(
        "MATCH p = (start)-[*]->(finish) WHERE (start.name = 'A' AND finish.name = 'D') SET start.x = true FOREACH (n IN nodes(p) | SET n.marked = true, n.foo = 'bar') DELETE finish"
      )
    end

    it 'withWith' do
      start = Cypher.any_node(:start)
      n = Cypher.name(:n)
      stmnt = Cypher.match(start)
                    .with(start)
                    .foreach(n)
                    .in(Cypher.list_of(start.as_expression))
                    .apply(Clauses.delete(false, [n]))
                    .build
      # Probably the worst way to delete a graph I ever wrote down
      expect(stmnt.cypher).to eq('MATCH (start) WITH start FOREACH (n IN [start] | DELETE n)')
    end
  end
end
