# frozen_string_literal: true

# Translated from IssueRelatedIT.java, second slice (GH-106 … GH-193).
module CypherDSL
  RSpec.describe 'IssueRelatedIT (2)' do
    let(:cypher_renderer) { Renderer.default }
    let(:person) { Cypher.node('Person').named(:person) }

    it 'map keys should be escaped if necessary' do # GH-106
      statement = Cypher.returning(Cypher.map_of('key 1', Cypher.literal_true, 'key 2', Cypher.literal_false)).build

      expect(cypher_renderer.render(statement)).to eq('RETURN {`key 1`: true, `key 2`: false}')
    end

    it 'alias on wrong position' do # GH-121
      u = Cypher.name(:u)
      rn = Cypher.name(:rn)
      nn = Cypher.name(:nn)

      rn_node = Cypher.node('SomeLabel').named(rn)
      rn_aliased_as_nn = rn_node.as(:nn)
      statement = Cypher.match(Cypher.node('User').named(u), rn_node, Cypher.node('SomeLabel').named(nn))
                        .with_distinct(u, rn, rn_aliased_as_nn)
                        .returning(u, rn, rn_aliased_as_nn)
                        .build

      expect(cypher_renderer.render(statement))
        .to eq('MATCH (u:`User`), (rn:`SomeLabel`), (nn:`SomeLabel`) WITH DISTINCT u, rn, rn AS nn RETURN u, rn, nn')
    end

    it 'properties of functions' do # GH-123
      statement = Cypher.returning(Cypher.property(Cypher.datetime, 'epochSeconds')).build
      expect(cypher_renderer.render(statement)).to eq('RETURN datetime().epochSeconds')
    end

    it 'properties of functions inside query' do # GH-123
      collected_things = Cypher.collect(Cypher.name(:n)).as(:collectedThings)
      statement = Cypher.match(Cypher.any_node.named(:n))
                        .with(collected_things)
                        .returning(Cypher.property(Cypher.last(collected_things), :name))
                        .build
      expect(cypher_renderer.render(statement)).to eq('MATCH (n) WITH collect(n) AS collectedThings RETURN last(collectedThings).name')
    end

    it 'gh127' do
      key = Cypher.name(:key)
      dynamic_prefix = 'properties.'
      statement = Cypher.match(person)
                        .returning(person.project('json',
                                                  Cypher.call('apoc.map.fromPairs')
                                                        .with_args(Cypher.list_with(key)
                                                                         .in(Cypher.call('keys').with_args(person.required_symbolic_name).as_function)
                                                                         .where(key.starts_with(Cypher.literal_of(dynamic_prefix)))
                                                                         .returning(Cypher.call('substring').with_args(key, Cypher.literal_of(dynamic_prefix.length)).as_function,
                                                                                    person.property(key)))
                                                        .as_function))
                        .build

      expect(cypher_renderer.render(statement)).to eq(
        "MATCH (person:`Person`) RETURN person{json: apoc.map.fromPairs([key IN keys(person) WHERE key STARTS WITH 'properties.' | [substring(key, 11), person[key]]])}"
      )
    end

    it 'allow symbolic names as condition' do # GH-133
      company = Cypher.node('Company').named(:company)
      cond = Cypher.name(:cond)
      cypher = Cypher.match(company)
                     .where(Cypher.any(cond)
                                  .in(Cypher.list_based_on(company.relationship_to(person, 'WORKS_AT'))
                                            .returning(person.property(:name).is_equal_to(Cypher.parameter(:name))))
                                  .where(cond.as_condition))
                     .returning(company)

      expect(cypher_renderer.render(cypher.build)).to eq(
        'MATCH (company:`Company`) WHERE any(cond IN [(company)-[:`WORKS_AT`]->(person:`Person`) | person.name = $name] WHERE cond) RETURN company'
      )
    end

    it 'project symbolic names' do # GH-131
      user = Cypher.node('User').named(:user)
      user_knows = Cypher.node('User').named(:userKnows)
      sorted_element = Cypher.name(:sortedElement)

      inner_pattern_comprehension = Cypher.list_based_on(user.relationship_to(user_knows, 'KNOWS'))
                                          .returning(user_knows.project('born', user_knows.property(:born)))
      statement = Cypher.match(user)
                        .returning(user.project('knows', Cypher.list_with(sorted_element)
                                                               .in(inner_pattern_comprehension)
                                                               .returning(sorted_element.project('born', Cypher.map_of('formatted',
                                                                                                                       Cypher.call('toString').with_args(Cypher.property(sorted_element, :born)).as_function)))))
                        .build
      expect(cypher_renderer.render(statement)).to eq(
        'MATCH (user:`User`) RETURN user{knows: [sortedElement IN [(user)-[:`KNOWS`]->(userKnows:`User`) | userKnows{born: userKnows.born}] | sortedElement{born: {formatted: toString(sortedElement.born)}}]}'
      )
    end

    it 'relationship patterns as condition' do # GH-128
      statement = Cypher.match(person)
                        .where(person.relationship_to(Cypher.any_node, 'A')
                                     .as_condition
                                     .or(person.relationship_to(Cypher.any_node, 'B')))
                        .and(person.relationship_to(Cypher.any_node, 'C')
                                   .as_condition
                                   .or(person.relationship_to(Cypher.any_node, 'D')
                                             .as_condition
                                             .and(person.relationship_to(Cypher.any_node, 'E')))
                                   .or(person.relationship_to(Cypher.any_node, 'F')))
                        .returning(person)
                        .build

      expected = 'MATCH (person:`Person`) WHERE (  (      (person)-[:`A`]->() OR (person)-[:`B`]->()  ) AND (      (          (person)-[:`C`]->() OR (              (person)-[:`D`]->() AND (person)-[:`E`]->()          )      ) OR (person)-[:`F`]->())) RETURN person'
                 .gsub(/\s{2,}/, '')

      expect(cypher_renderer.render(statement)).to eq(expected)
    end

    it 'point should accept expression too' do # GH-142
      location = Cypher.parameter(:location)
      distance = Cypher.property(location, :distance)

      point = Cypher.point(Cypher.property(location, :point))

      statement = Cypher.match(person)
                        .where(Cypher.distance(person.property(:location), point).is_equal_to(distance))
                        .returning(person)
                        .build

      expect(cypher_renderer.render(statement)).to eq(
        'MATCH (person:`Person`) WHERE point.distance(person.location, point($location.point)) = $location.distance RETURN person'
      )
    end

    it 'properties should be extractable from expressions' do # GH-141
      location = Cypher.parameter(:location)

      point = Cypher.call('point').with_args(location.property(:point)).as_function
      distance = Cypher.property(location, :distance)

      statement = Cypher.match(person)
                        .where(Cypher.distance(person.property(:location), point).is_equal_to(distance))
                        .returning(person)
                        .build

      expect(cypher_renderer.render(statement)).to eq(
        'MATCH (person:`Person`) WHERE point.distance(person.location, point($location.point)) = $location.distance RETURN person'
      )
    end

    it 'remove all properties should work' do
      n = Cypher.node('DeleteMe').named(:n)
      cypher = Cypher.match(n)
                     .set(n, Cypher.map_of)
                     .set(n.property(:newProperty).to(Cypher.literal_of('aValue')))
                     .returning(n)
                     .build
                     .cypher
      expect(cypher).to eq("MATCH (n:`DeleteMe`) SET n = {} SET n.newProperty = 'aValue' RETURN n")
    end

    it 'containers must be mutatable by properties' do # GH-168
      node_a = Cypher.node('Target').named(:t)
      node_b = Cypher.node('Source').named(:s)
      cypher = Cypher.match(node_a, node_b).mutate(node_a, node_b.property(:whatever)).build.cypher
      expect(cypher).to eq('MATCH (t:`Target`), (s:`Source`) SET t += s.whatever')
    end

    [
      [true, 1, false, 'MATCH (s)-[:`PART_OF`*0..1]->(:`Resume`)-[:`IS_PARALLEL`*0..1]->(:`Resume`)-[l:`LEADS_TO`]->(e) RETURN s, l, e'],
      [true, 2, false, 'MATCH (s)-[:`PART_OF`*0..1]->(:`Resume`)-[:`IS_PARALLEL`*0..1]->(:`Resume`)-[l:`LEADS_TO`*2..2]->(e) RETURN s, l, e'],
      [true, 1, true, 'MATCH (s)-[:`PART_OF`*0..1]->(:`Resume`)-[:`IS_PARALLEL`*0..1]->(:`Resume`)<-[l:`LEADS_TO`]-(e) RETURN s, l, e'],
      [true, 2, true, 'MATCH (s)-[:`PART_OF`*0..1]->(:`Resume`)-[:`IS_PARALLEL`*0..1]->(:`Resume`)<-[l:`LEADS_TO`*2..2]-(e) RETURN s, l, e'],
      [false, 1, false, 'MATCH (s)-[l:`LEADS_TO`]->(e) RETURN s, l, e'],
      [false, 2, false, 'MATCH (s)-[l:`LEADS_TO`*2..2]->(e) RETURN s, l, e'],
      [false, 1, true, 'MATCH (s)<-[l:`LEADS_TO`]-(e) RETURN s, l, e'],
      [false, 2, true, 'MATCH (s)<-[l:`LEADS_TO`*2..2]-(e) RETURN s, l, e']
    ].each do |multihops, length, backward, expected|
      it "relpattern chaining(multihops=#{multihops}, length=#{length}, backward=#{backward})" do # GH-152
        start = Cypher.any_node(:s)
        finish = Cypher.any_node(:e)

        leads_to = if multihops
                     start.relationship_to(Cypher.node('Resume'), 'PART_OF')
                          .length(0, 1)
                          .relationship_to(Cypher.node('Resume'), 'IS_PARALLEL')
                          .length(0, 1)
                   else
                     start
                   end
        leads_to = backward ? leads_to.relationship_from(finish, 'LEADS_TO').named(:l) : leads_to.relationship_to(finish, 'LEADS_TO').named(:l)
        leads_to = leads_to.length(length, length) if length > 1
        cypher = Cypher.match(leads_to).returning(:s, :l, :e).build.cypher
        expect(cypher).to eq(expected)
      end
    end

    it 'returning raw should work' do # GH-187
      user_provided_cypher = 'MATCH (this)-[:LINK]-(o:Other) RETURN o'
      node = Cypher.node('Node').named(:node)
      result = Cypher.name(:result)
      statement = Cypher.match(node)
                        .call(Cypher.with(node)
                                    # Aliasing or expressions are not supported in importing WITH clauses.
                                    .with(node.as(:this))
                                    .returning_raw(Cypher.raw(user_provided_cypher).as(result))
                                    .build)
                        .returning(result.project('foo', 'bar'))
                        .build

      cypher = Renderer.get_renderer(Renderer::Configuration.pretty_printing).render(statement)
      expect(cypher).to eq(<<~CYPHER.chomp)
        MATCH (node:Node)
        CALL (node) {
          WITH node AS this
          MATCH (this)-[:LINK]-(o:Other) RETURN o AS result
        }
        RETURN result {
          .foo,
          .bar
        }
      CYPHER
    end

    it 'very raw call should work' do
      msg = Cypher.name(:message)
      statement = Cypher.unwind(Cypher.parameter(:events))
                        .as(msg)
                        .with(msg.property(:value).as(:event), msg.property(:header).as(:header), msg.property(:key).as(:key),
                              msg.property(:value).as(:value))
                        .call_raw_cypher('WITH key, value CREATE (e:Event {key: key, value: value})')
                        .build
                        .cypher

      expect(statement).to eq(
        'UNWIND $events AS message WITH message.value AS event, message.header AS header, message.key AS key, message.value AS value CALL (*) {WITH key, value CREATE (e:Event {key: key, value: value})}'
      )
    end

    it 'mixed with should make sense' do # GH-190
      node = Cypher.node('Node').named(:node)
      some_expression = Cypher.literal_false

      ll = node.property(:ll)
      l = node.property(:l)

      a_case = Cypher.case_expression.when(ll.is_null).then(l).else_default(ll).as(:l)

      cypher = Cypher.match(node)
                     .with(node, some_expression.as(:f), a_case)
                     .returning(Cypher.asterisk)
                     .build
                     .cypher
      expect(cypher).to eq('MATCH (node:`Node`) WITH node, false AS f, CASE WHEN node.ll IS NULL THEN node.l ELSE node.ll END AS l RETURN *')
    end

    it 'with alias on top level' do # GH-190
      cypher = Cypher.with(Cypher.literal_false.as(:f)).returning(Cypher.asterisk).build.cypher
      expect(cypher).to eq('WITH false AS f RETURN *')
    end

    it 'mixed with distinct should make sense' do # GH-190
      node = Cypher.node('Node').named(:node)
      some_expression = Cypher.literal_false

      ll = node.property(:ll)
      l = node.property(:l)

      a_case = Cypher.case_expression.when(ll.is_null).then(l).else_default(ll).as(:l)

      cypher = Cypher.match(node)
                     .with_distinct(node, some_expression.as(:f), a_case)
                     .returning(Cypher.asterisk)
                     .build
                     .cypher
      expect(cypher).to eq('MATCH (node:`Node`) WITH DISTINCT node, false AS f, CASE WHEN node.ll IS NULL THEN node.l ELSE node.ll END AS l RETURN *')
    end

    it 'heterogen alias with distinct should make sense' do # GH-190
      node = Cypher.node('Node').named(:node)
      some_expression = Cypher.literal_false

      cypher = Cypher.match(node)
                     .with_distinct(some_expression.as(:f), Cypher.date.as(:aDate))
                     .returning(Cypher.asterisk)
                     .build
                     .cypher
      expect(cypher).to eq('MATCH (node:`Node`) WITH DISTINCT false AS f, date() AS aDate RETURN *')
    end

    it 'symbolic name and alias' do # GH-190
      node = Cypher.node('Node').named(:node)
      some_expression = Cypher.literal_false

      cypher = Cypher.match(node)
                     .with(Cypher.name(:n), some_expression.as(:f), Cypher.date.as(:aDate))
                     .returning(Cypher.asterisk)
                     .build
                     .cypher
      expect(cypher).to eq('MATCH (node:`Node`) WITH n, false AS f, date() AS aDate RETURN *')
    end

    it 'pattern expressions are not allowed to introduce new variables' do # GH-192
      bike = Cypher.node('Bike').named(:b)
      owner = Cypher.node('Person').named(:o)
      owns = owner.relationship_to(bike, 'OWNS').named(:r)
      p = owns.property(:x)

      statement = Cypher.match(bike)
                        .where(owns.as_condition)
                        .with(bike)
                        .match(owns)
                        .returning(bike.property(:f), p)
                        .build
      expect(statement.cypher).to eq(
        'MATCH (b:`Bike`) WHERE (:`Person`)-[:`OWNS`]->(b) WITH b MATCH (o:`Person`)-[r:`OWNS`]->(b) RETURN b.f, r.x'
      )

      statement = Cypher.match(owns).where(owns.as_condition).returning(owns).build
      expect(statement.cypher).to eq('MATCH (o:`Person`)-[r:`OWNS`]->(b:`Bike`) WHERE (o)-[r]->(b) RETURN r')
    end

    it 'match after yield should work standalone' do # GH-193
      g = Cypher.node('Group').named(:g)
      a = Cypher.node('Asset').named(:a)
      d = Cypher.node('Device').named(:d)
      node = Cypher.name(:node)
      cypher = Cypher.call('db.index.fulltext.queryNodes')
                     .with_args(Cypher.literal_of('livesearch'), Cypher.literal_of('*a*'))
                     .yield(node)
                     .match(g.relationship_to(a, 'GROUPS')
                             .relationship_from(Cypher.node('Deploy'), 'ON')
                             .relationship_from(d, 'SCHEDULED'))
                     .where(a.property(:asset_id).is_equal_to(Cypher.property(node, :asset_id)))
                     .with_distinct(Cypher.collect(d.project(d.property(:sigfox_id), a)).as(:assetdata))
                     .returning(:assetdata)
                     .build
                     .cypher
      expect(cypher).to eq(
        "CALL db.index.fulltext.queryNodes('livesearch', '*a*') YIELD node MATCH (g:`Group`)-[:`GROUPS`]->(a:`Asset`)<-[:`ON`]-(:`Deploy`)<-[:`SCHEDULED`]-(d:`Device`) WHERE a.asset_id = node.asset_id WITH DISTINCT collect(d{.sigfox_id, a}) AS assetdata RETURN assetdata"
      )
    end

    it 'match after yield should work in query' do # GH-193
      g = Cypher.node('Group').named(:g)
      a = Cypher.node('Asset').named(:a)
      d = Cypher.node('Device').named(:d)
      node = Cypher.name(:node)
      name_of_index = Cypher.name(:nameOfIndex)
      cypher = Cypher.with(Cypher.parameter(:p).as(name_of_index))
                     .call('db.index.fulltext.queryNodes')
                     .with_args(name_of_index, Cypher.literal_of('*a*'))
                     .yield(node)
                     .match(g.relationship_to(a, 'GROUPS')
                             .relationship_from(Cypher.node('Deploy'), 'ON')
                             .relationship_from(d, 'SCHEDULED'))
                     .where(a.property(:asset_id).is_equal_to(Cypher.property(node, :asset_id)))
                     .with_distinct(Cypher.collect(d.project(d.property(:sigfox_id), a)).as(:assetdata))
                     .returning(:assetdata)
                     .build
                     .cypher
      expect(cypher).to eq(
        "WITH $p AS nameOfIndex CALL db.index.fulltext.queryNodes(nameOfIndex, '*a*') YIELD node MATCH (g:`Group`)-[:`GROUPS`]->(a:`Asset`)<-[:`ON`]-(:`Deploy`)<-[:`SCHEDULED`]-(d:`Device`) WHERE a.asset_id = node.asset_id WITH DISTINCT collect(d{.sigfox_id, a}) AS assetdata RETURN assetdata"
      )
    end
  end
end
