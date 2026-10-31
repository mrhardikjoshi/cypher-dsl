# frozen_string_literal: true

# Translated from CypherIT.java, nested class SingleQuerySinglePart.ReadingAndReturn.
module CypherDSL
  RSpec.describe 'CypherIT / SingleQuerySinglePart / ReadingAndReturn' do
    let(:bike_node) { Cypher.node('Bike').named(:b) }
    let(:user_node) { Cypher.node('User').named(:u) }
    let(:renderer) { Renderer.default }

    it 'unrelatedNodes' do
      statement = Cypher.match(bike_node, user_node, Cypher.node('U').named(:o))
                        .returning(bike_node, user_node)
                        .build

      expect(renderer.render(statement)).to eq('MATCH (b:`Bike`), (u:`User`), (o:`U`) RETURN b, u')
    end

    it 'asteriskShouldWork' do
      statement = Cypher.match(bike_node, user_node, Cypher.node('U').named(:o))
                        .returning(Cypher.asterisk)
                        .build

      expect(renderer.render(statement)).to eq('MATCH (b:`Bike`), (u:`User`), (o:`U`) RETURN *')
    end

    it 'aliasedExpressionsInReturn' do
      unnamed_node = Cypher.node('ANode')
      named_node = Cypher.node('AnotherNode').named(:o)
      statement = Cypher.match(unnamed_node, named_node)
                        .returning(named_node.as(:theOtherNode))
                        .build

      expect(renderer.render(statement)).to eq('MATCH (:`ANode`), (o:`AnotherNode`) RETURN o AS theOtherNode')
    end

    it 'simpleRelationship' do
      statement = Cypher.match(user_node.relationship_to(bike_node, 'OWNS'))
                        .returning(bike_node, user_node)
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`)-[:`OWNS`]->(b:`Bike`) RETURN b, u')
    end

    it 'simpleRelationshipChainNamed' do
      chains = [
        user_node.relationship_to(bike_node, 'OWNS').relationship_to(Cypher.node('Brand'), 'MADE_BY')
                 .named(SymbolicName.of('m')),
        user_node.relationship_to(bike_node, 'OWNS').relationship_to(Cypher.node('Brand'), 'MADE_BY').named(:m)
      ]
      chains.each do |chain|
        statement = Cypher.match(chain).returning(bike_node, user_node).build

        expect(renderer.render(statement))
          .to eq('MATCH (u:`User`)-[:`OWNS`]->(b:`Bike`)-[m:`MADE_BY`]->(:`Brand`) RETURN b, u')
      end
    end

    it 'multipleRelationshipTypes' do # GH-169
      statement = Cypher.match(user_node.relationship_to(bike_node, 'OWNS', 'RIDES'))
                        .returning(bike_node, user_node)
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`)-[:`OWNS`|`RIDES`]->(b:`Bike`) RETURN b, u')
    end

    it 'relationshipWithProperties' do # GH-170
      statement = Cypher
                  .match(user_node.relationship_to(bike_node, 'OWNS')
                                  .with_properties(Cypher.map_of('boughtOn', Cypher.literal_of('2019-04-16'))))
                  .returning(bike_node, user_node)
                  .build

      expect(renderer.render(statement))
        .to eq("MATCH (u:`User`)-[:`OWNS` {boughtOn: '2019-04-16'}]->(b:`Bike`) RETURN b, u")
    end

    it 'relationshipWithMinimumLength' do # GH-168
      statement = Cypher.match(user_node.relationship_to(bike_node, 'OWNS').min(3))
                        .returning(bike_node, user_node)
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`)-[:`OWNS`*3..]->(b:`Bike`) RETURN b, u')
    end

    it 'relationshipWithMaximumLength' do # GH-168
      statement = Cypher.match(user_node.relationship_to(bike_node, 'OWNS').max(5))
                        .returning(bike_node, user_node)
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`)-[:`OWNS`*..5]->(b:`Bike`) RETURN b, u')
    end

    it 'unboundedRelationship' do # GH-168
      statement = Cypher.match(user_node.relationship_to(bike_node, 'OWNS').unbounded)
                        .returning(bike_node, user_node)
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`)-[:`OWNS`*]->(b:`Bike`) RETURN b, u')
    end

    it 'relationshipWithLength' do # GH-168
      statement = Cypher.match(user_node.relationship_to(bike_node, 'OWNS').length(3, 5))
                        .returning(bike_node, user_node)
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`)-[:`OWNS`*3..5]->(b:`Bike`) RETURN b, u')
    end

    it 'relationshipWithLengthAndProperties' do # GH-168
      statement = Cypher
                  .match(user_node.relationship_to(bike_node, 'OWNS')
                                  .length(3, 5)
                                  .with_properties(Cypher.map_of('boughtOn', Cypher.literal_of('2019-04-16'))))
                  .returning(bike_node, user_node)
                  .build

      expect(renderer.render(statement))
        .to eq("MATCH (u:`User`)-[:`OWNS`*3..5 {boughtOn: '2019-04-16'}]->(b:`Bike`) RETURN b, u")
    end

    it 'simpleRelationshipWithReturn' do
      owns = user_node.relationship_to(bike_node, 'OWNS').named(:o)

      statement = Cypher.match(owns).returning(bike_node, user_node, owns).build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`)-[o:`OWNS`]->(b:`Bike`) RETURN b, u, o')
    end

    it 'chainedRelations' do
      trip_node = Cypher.node('Trip').named(:t)
      statement = Cypher
                  .match(user_node.relationship_to(bike_node, 'OWNS')
                                  .named(:r1)
                                  .relationship_to(trip_node, 'USED_ON')
                                  .named(:r2))
                  .where(user_node.property(:name).matches('.*aName'))
                  .returning(bike_node, user_node)
                  .build

      expect(renderer.render(statement)).to eq(
        "MATCH (u:`User`)-[r1:`OWNS`]->(b:`Bike`)-[r2:`USED_ON`]->(t:`Trip`) WHERE u.name =~ '.*aName' RETURN b, u"
      )

      statement = Cypher
                  .match(user_node.relationship_to(bike_node, 'OWNS').relationship_to(trip_node, 'USED_ON').named(:r2))
                  .where(user_node.property(:name).matches('.*aName'))
                  .returning(bike_node, user_node)
                  .build

      expect(renderer.render(statement)).to eq(
        "MATCH (u:`User`)-[:`OWNS`]->(b:`Bike`)-[r2:`USED_ON`]->(t:`Trip`) WHERE u.name =~ '.*aName' RETURN b, u"
      )

      statement = Cypher
                  .match(user_node.relationship_to(bike_node, 'OWNS')
                                  .relationship_to(trip_node, 'USED_ON')
                                  .named(:r2)
                                  .relationship_from(user_node, 'WAS_ON')
                                  .named(:x)
                                  .relationship_between(Cypher.node('SOMETHING'))
                                  .named(:y))
                  .where(user_node.property(:name).matches('.*aName'))
                  .returning(bike_node, user_node)
                  .build

      expect(renderer.render(statement)).to eq(
        "MATCH (u:`User`)-[:`OWNS`]->(b:`Bike`)-[r2:`USED_ON`]->(t:`Trip`)<-[x:`WAS_ON`]-(u)-[y]-(:`SOMETHING`) WHERE u.name =~ '.*aName' RETURN b, u"
      )
    end

    it 'chainedRelationshipsWithPropertiesAndLength' do # GH-177
      trip_node = Cypher.node('Trip').named(:t)
      statement = Cypher
                  .match(user_node.relationship_to(bike_node, 'OWNS')
                                  .relationship_to(trip_node, 'USED_ON')
                                  .named(:r2)
                                  .min(1)
                                  .properties(Cypher.map_of('when', Cypher.literal_of('2019-04-16')))
                                  .relationship_from(user_node, 'WAS_ON')
                                  .named(:x)
                                  .max(2)
                                  .properties('whatever', Cypher.literal_of('2020-04-16'))
                                  .relationship_between(Cypher.node('SOMETHING'))
                                  .named(:y)
                                  .length(2, 3)
                                  .properties(Cypher.map_of('idk', Cypher.literal_of('2021-04-16'))))
                  .where(user_node.property(:name).matches('.*aName'))
                  .returning(bike_node, user_node)
                  .build

      expect(renderer.render(statement)).to eq(
        "MATCH (u:`User`)-[:`OWNS`]->(b:`Bike`)-[r2:`USED_ON`*1.. {when: '2019-04-16'}]->(t:`Trip`)<-[x:`WAS_ON`*..2 {whatever: '2020-04-16'}]-(u)-[y*2..3 {idk: '2021-04-16'}]-(:`SOMETHING`) WHERE u.name =~ '.*aName' RETURN b, u"
      )
    end

    it 'sizeOfRelationship' do # GH-182
      statement = Cypher.match(Cypher.any_node(:a))
                        .where(Cypher.property(:a, :name).is_equal_to(Cypher.literal_of('Alice')))
                        .returning(Cypher.size(Cypher.any_node(:a).relationship_to(Cypher.any_node)).as(:fof))
                        .build

      expect(renderer.render(statement)).to eq("MATCH (a) WHERE a.name = 'Alice' RETURN size((a)-->()) AS fof")
    end

    it 'sizeOfRelationshipChain' do # GH-182
      statement = Cypher.match(Cypher.any_node(:a))
                        .where(Cypher.property(:a, :name).is_equal_to(Cypher.literal_of('Alice')))
                        .returning(Cypher
                          .size(Cypher.any_node(:a).relationship_to(Cypher.any_node).relationship_to(Cypher.any_node))
                          .as(:fof))
                        .build

      expect(renderer.render(statement)).to eq("MATCH (a) WHERE a.name = 'Alice' RETURN size((a)-->()-->()) AS fof")
    end

    it 'sortOrderDefault' do
      statement = Cypher.match(user_node)
                        .returning(user_node)
                        .order_by(Cypher.sort(user_node.property(:name)))
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) RETURN u ORDER BY u.name')
    end

    it 'sortOrderDefaultBasedOnSortItemCollection' do # GH-189
      statement = Cypher.match(user_node)
                        .returning(user_node)
                        .order_by([Cypher.sort(user_node.property(:name))])
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) RETURN u ORDER BY u.name')
    end

    it 'sortOrderAscending' do
      statement = Cypher.match(user_node)
                        .returning(user_node)
                        .order_by(Cypher.sort(user_node.property(:name)).ascending)
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) RETURN u ORDER BY u.name ASC')
    end

    it 'sortOrderDescending' do
      statement = Cypher.match(user_node)
                        .returning(user_node)
                        .order_by(Cypher.sort(user_node.property(:name)).descending)
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) RETURN u ORDER BY u.name DESC')
    end

    it 'sortOrderConcatenation' do
      statement = Cypher.match(user_node)
                        .returning(user_node)
                        .order_by(Cypher.sort(user_node.property(:name)).descending,
                                  Cypher.sort(user_node.property(:age)).ascending)
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) RETURN u ORDER BY u.name DESC, u.age ASC')
    end

    it 'sortOrderDefaultExpression' do
      statement = Cypher.match(user_node)
                        .returning(user_node)
                        .order_by(user_node.property(:name))
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) RETURN u ORDER BY u.name')
    end

    it 'sortOrderAscendingExpression' do
      statement = Cypher.match(user_node)
                        .returning(user_node)
                        .order_by(user_node.property(:name).ascending)
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) RETURN u ORDER BY u.name ASC')
    end

    it 'sortOrderDescendingExpression' do
      statement = Cypher.match(user_node)
                        .returning(user_node)
                        .order_by(user_node.property(:name).descending)
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) RETURN u ORDER BY u.name DESC')
    end

    it 'sortOrderConcatenationExpression' do
      statement = Cypher.match(user_node)
                        .returning(user_node)
                        .order_by(user_node.property(:name))
                        .descending
                        .and(user_node.property(:age))
                        .ascending
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) RETURN u ORDER BY u.name DESC, u.age ASC')
    end

    it 'skip' do
      statement = Cypher.match(user_node).returning(user_node).skip(1).build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) RETURN u SKIP 1')
    end

    it 'nullSkip' do
      statement = Cypher.match(user_node).returning(user_node).skip(nil).build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) RETURN u')
    end

    it 'limit' do
      statement = Cypher.match(user_node).returning(user_node).limit(1).build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) RETURN u LIMIT 1')
    end

    it 'limitWithParams' do # GH-129
      statement = Cypher.match(user_node)
                        .returning(user_node)
                        .limit(Cypher.parameter(:param))
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) RETURN u LIMIT $param')
    end

    it 'nullLimit' do
      statement = Cypher.match(user_node).returning(user_node).limit(nil).build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) RETURN u')
    end

    it 'skipAndLimit' do
      statement = Cypher.match(user_node).returning(user_node).skip(1).limit(1).build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) RETURN u SKIP 1 LIMIT 1')
    end

    it 'skipAndLimitWithParams' do # GH-129
      statement = Cypher.match(user_node)
                        .returning(user_node)
                        .skip(Cypher.parameter(:skip))
                        .limit(Cypher.parameter(:limit))
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) RETURN u SKIP $skip LIMIT $limit')
    end

    it 'nullSkipAndLimit' do
      statement = Cypher.match(user_node)
                        .returning(user_node)
                        .skip(nil)
                        .limit(nil)
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) RETURN u')
    end

    it 'distinct' do
      expected = 'MATCH (u:`User`) RETURN DISTINCT u SKIP 1 LIMIT 1'

      statement = Cypher.match(user_node).returning_distinct(user_node).skip(1).limit(1).build
      expect(renderer.render(statement)).to eq(expected)

      statement = Cypher.match(user_node).returning_distinct('u').skip(1).limit(1).build
      expect(renderer.render(statement)).to eq(expected)
    end
  end
end
