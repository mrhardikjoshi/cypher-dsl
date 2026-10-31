# frozen_string_literal: true

# Translated from IssueRelatedIT.java (regression cases named after GitHub issues).
module CypherDSL
  RSpec.describe 'IssueRelatedIT' do
    let(:cypher_renderer) { Renderer.default }
    let(:person) { Cypher.node('Person').named(:person) }

    it 'gh266 size should be supported' do
      node = Cypher.node('Node').named(:node)
      cypher = Cypher.match(node).returning(node.property(:thing).size).build.cypher
      expect(cypher).to eq('MATCH (node:`Node`) RETURN size(node.thing)')
    end

    it 'gh266 has size utility should work' do
      node = Cypher.node('Node').named(:node)
      cypher = Cypher.match(node)
                     .where(node.property(:thing).has_size(Cypher.literal_of(0)))
                     .returning(Cypher.asterisk)
                     .build
                     .cypher
      expect(cypher).to eq('MATCH (node:`Node`) WHERE size(node.thing) = 0 RETURN *')
    end

    it 'gh115' do
      nodes = Cypher.node('Node').named(:node).with_properties('id', Cypher.literal_of('node_42'))
      match_nodes = Cypher.match(nodes)

      p = Cypher.path(Cypher.name(:path)).get
      statement = match_nodes.call('apoc.path.spanningTree')
                             .with_args(nodes.required_symbolic_name,
                                        Cypher.map_of('relationshipFilter', Cypher.literal_of('<rel_filter>'),
                                                      'labelFilter', Cypher.literal_of('<label_filter>')))
                             .yield(p)
                             .returning_distinct(nodes.required_symbolic_name, Cypher.collect(Cypher.relationships(p)).as(:rels),
                                                 Cypher.collect(Cypher.nodes(p)).as(:nodes))
                             .build

      expect(cypher_renderer.render(statement)).to eq(
        "MATCH (node:`Node` {id: 'node_42'}) CALL apoc.path.spanningTree(node, {relationshipFilter: '<rel_filter>', labelFilter: '<label_filter>'}) YIELD path RETURN DISTINCT node, collect(relationships(path)) AS rels, collect(nodes(path)) AS nodes"
      )
    end

    it 'gh70' do
      strawberry = Cypher.node('Fruit', Cypher.map_of('kind', Cypher.literal_of('strawberry')))
      statement = Cypher.match(strawberry)
                        .set(strawberry.property(:color).to(Cypher.literal_of('red')))
                        .build

      expect(cypher_renderer.render(statement))
        .to match(/\AMATCH \([a-zA-Z]*\d{3}:`Fruit` \{kind: 'strawberry'}\) SET [a-zA-Z]*\d{3}\.color = 'red'\z/)
    end

    it 'gh167' do
      app = Cypher.node('Location').named(:app).with_properties('uuid', Cypher.parameter(:app_uuid))
      loc_start = Cypher.node('Location').named(:loc_start)
      resume = Cypher.node('Resume').named(:r)
      offer = Cypher.node('Offer').named(:o)
      start_n = Cypher.node('ResumeNode').named(:start_n)

      a_fl = app.relationship_from(loc_start, 'PART_OF').length(0, 3)
      l_fr = loc_start.relationship_from(resume, 'IN', 'IN_ANALYTICS')

      statement = Cypher.match(a_fl, l_fr)
                        .with_distinct(resume, loc_start, app)
                        .match(resume.relationship_to(offer.with_properties('is_valid', Cypher.literal_true), 'IN_COHORT_OF')
                                     .relationship_to(Cypher.any_node(:app), 'IN'))
                        .with_distinct(resume, loc_start, app, offer)
                        .match(offer.relationship_to(start_n, 'FOR'))
                        .where(Cypher.id(start_n).in(Cypher.parameter(:start_ids)))
                        .returning_distinct(resume, loc_start, app, offer, start_n)
                        .build

      expect(cypher_renderer.render(statement)).to eq(
        'MATCH (app:`Location` {uuid: $app_uuid})<-[:`PART_OF`*0..3]-(loc_start:`Location`), (loc_start)<-[:`IN`|`IN_ANALYTICS`]-(r:`Resume`) WITH DISTINCT r, loc_start, app MATCH (r)-[:`IN_COHORT_OF`]->(o:`Offer` {is_valid: true})-[:`IN`]->(app) WITH DISTINCT r, loc_start, app, o MATCH (o)-[:`FOR`]->(start_n:`ResumeNode`) WHERE id(start_n) IN $start_ids RETURN DISTINCT r, loc_start, app, o, start_n'
      )
    end

    it 'gh174' do
      r = Cypher.node('Resume').named(:r)
      o = Cypher.node('Offer').named(:o)

      s = Cypher.match(r.relationship_to(o, 'FOR'))
                .where(r.has_labels('LastResume').not)
                .and(Cypher.coalesce(o.property(:valid_only), Cypher.literal_false)
                           .is_equal_to(Cypher.literal_false)
                           .and(r.has_labels('InvalidStatus').not)
                           .or(o.property(:valid_only).is_true.and(r.has_labels('InvalidStatus'))))
                .returning_distinct(r, o)
                .build

      expect(cypher_renderer.render(s)).to eq(
        'MATCH (r:`Resume`)-[:`FOR`]->(o:`Offer`) WHERE (NOT (r:`LastResume`) AND ((coalesce(o.valid_only, false) = false AND NOT (r:`InvalidStatus`)) OR (o.valid_only = true AND r:`InvalidStatus`))) RETURN DISTINCT r, o'
      )
    end

    it 'gh184' do
      r = Cypher.node('Resume').named(:r)
      u = Cypher.node('UserSearchable').named(:u)
      o = Cypher.node('Offer').named(:o)

      s = Cypher.match(r.relationship_from(u, 'HAS'))
                .where(r.has_labels('LastResume').not)
                .and(Cypher.coalesce(o.property(:valid_only), Cypher.literal_false)
                           .is_equal_to(Cypher.literal_false)
                           .and(r.has_labels('InvalidStatus').not)
                           .or(o.property(:valid_only).is_true.and(r.has_labels('ValidStatus'))))
                .and(r.property(:is_internship)
                      .is_true
                      .and(Cypher.size(r.relationship_to(Cypher.any_node, 'PART_OF')).is_empty)
                      .not)
                .and(r.property(:is_sandwich_training)
                      .is_true
                      .and(Cypher.size(r.relationship_to(Cypher.any_node, 'PART_OF')).is_empty)
                      .not)
                .returning_distinct(r, o)
                .build

      expect(cypher_renderer.render(s)).to eq(
        'MATCH (r:`Resume`)<-[:`HAS`]-(u:`UserSearchable`) WHERE (NOT (r:`LastResume`) AND ((coalesce(o.valid_only, false) = false AND NOT (r:`InvalidStatus`)) OR (o.valid_only = true AND r:`ValidStatus`)) AND NOT ((r.is_internship = true AND size(size((r)-[:`PART_OF`]->())) = 0)) AND NOT ((r.is_sandwich_training = true AND size(size((r)-[:`PART_OF`]->())) = 0))) RETURN DISTINCT r, o'
      )
    end

    it 'gh185' do
      r = Cypher.node('Resume').named(:r)
      u = Cypher.node('UserSearchable').named(:u)

      s = Cypher.match(r.relationship_from(u, 'HAS'))
                .where(Cypher.not(Cypher.exists(r.relationship_to(u, 'EXCLUDES'))))
                .returning_distinct(r)
                .build

      expect(cypher_renderer.render(s))
        .to eq('MATCH (r:`Resume`)<-[:`HAS`]-(u:`UserSearchable`) WHERE NOT (exists((r)-[:`EXCLUDES`]->(u))) RETURN DISTINCT r')
    end

    it 'gh187' do
      r = Cypher.node('Resume').named(:r)
      u = Cypher.node('User').named(:u)

      s = Cypher.match(r.relationship_from(u, 'HAS'))
                .with(Cypher.head(Cypher.collect(r.required_symbolic_name)).as(:r))
                .returning(r)
                .build

      expect(cypher_renderer.render(s)).to eq('MATCH (r:`Resume`)<-[:`HAS`]-(u:`User`) WITH head(collect(r)) AS r RETURN r')
    end

    it 'gh188' do
      r = Cypher.node('Resume').named(:r)
      u = Cypher.node('User').named(:u)

      s = Cypher.match(r.relationship_from(u, 'HAS'))
                .returning(Cypher.count_distinct(r.required_symbolic_name).as(:r))
                .build

      expect(cypher_renderer.render(s)).to eq('MATCH (r:`Resume`)<-[:`HAS`]-(u:`User`) RETURN count(DISTINCT r) AS r')
    end

    it 'gh197' do
      # avg
      s = Cypher.match(person).returning(Cypher.avg(person.property(:age))).build
      expect(cypher_renderer.render(s)).to eq('MATCH (person:`Person`) RETURN avg(person.age)')

      # max/min
      list = Cypher.list_of(Cypher.literal_of(1), Cypher.literal_of('a'), Cypher.literal_of(nil),
                            Cypher.literal_of(0.2), Cypher.literal_of('b'), Cypher.literal_of('1'), Cypher.literal_of('99'))
      s = Cypher.unwind(list).as(:val).returning(Cypher.max(Cypher.name(:val))).build
      expect(cypher_renderer.render(s)).to eq("UNWIND [1, 'a', NULL, 0.2, 'b', '1', '99'] AS val RETURN max(val)")
      s = Cypher.unwind(list).as(:val).returning(Cypher.min(Cypher.name(:val))).build
      expect(cypher_renderer.render(s)).to eq("UNWIND [1, 'a', NULL, 0.2, 'b', '1', '99'] AS val RETURN min(val)")

      # percentileCont/percentileDisc
      s = Cypher.match(person).returning(Cypher.percentile_cont(person.property(:age), 0.4)).build
      expect(cypher_renderer.render(s)).to eq('MATCH (person:`Person`) RETURN percentileCont(person.age, 0.4)')
      s = Cypher.match(person).returning(Cypher.percentile_disc(person.property(:age), 0.5)).build
      expect(cypher_renderer.render(s)).to eq('MATCH (person:`Person`) RETURN percentileDisc(person.age, 0.5)')

      # stDev/stDevP
      names = Cypher.list_of(Cypher.literal_of('A'), Cypher.literal_of('B'), Cypher.literal_of('C'))
      s = Cypher.match(person).where(person.property(:name).in(names)).returning(Cypher.st_dev(person.property(:age))).build
      expect(cypher_renderer.render(s)).to eq("MATCH (person:`Person`) WHERE person.name IN ['A', 'B', 'C'] RETURN stDev(person.age)")
      s = Cypher.match(person).where(person.property(:name).in(names)).returning(Cypher.st_dev_p(person.property(:age))).build
      expect(cypher_renderer.render(s)).to eq("MATCH (person:`Person`) WHERE person.name IN ['A', 'B', 'C'] RETURN stDevP(person.age)")

      # sum
      s = Cypher.match(person)
                .with(Cypher.list_of(Cypher.map_of('type', person.required_symbolic_name, 'nb', Cypher.sum(person.required_symbolic_name)))
                            .as(:counts))
                .returning(Cypher.sum(person.property(:age)))
                .build
      expect(cypher_renderer.render(s)).to eq('MATCH (person:`Person`) WITH [{type: person, nb: sum(person)}] AS counts RETURN sum(person.age)')
    end

    it 'gh200' do
      r = Cypher.node('Resume').named(:r)

      s = Cypher.match(r)
                .with(r.required_symbolic_name)
                .returning_distinct(r.required_symbolic_name)
                .build

      expect(cypher_renderer.render(s)).to eq('MATCH (r:`Resume`) WITH r RETURN DISTINCT r')
    end

    it 'gh204' do
      a = Cypher.node('A').named(:a)
      b = Cypher.node('B').named(:b)
      c = Cypher.node('C').named(:c)

      s = Cypher.match(a.relationship_to(b).relationship_to(c).max(2)).returning(a).build

      expect(cypher_renderer.render(s)).to eq('MATCH (a:`A`)-->(b:`B`)-[*..2]->(c:`C`) RETURN a')
    end

    it 'gh245' do
      expected = 'MATCH (person:`Person`) RETURN person{alias: person.name}'

      statement = Cypher.match(person).returning(person.project('alias', person.property(:name))).build
      expect(cypher_renderer.render(statement)).to eq(expected)

      statement = Cypher.match(person).returning(person.project(person.property(:name).as(:alias))).build
      expect(cypher_renderer.render(statement)).to eq(expected)
    end

    it 'gh44' do
      n = Cypher.any_node(:n)
      statement = Cypher.match(n).returning(Cypher.collect_distinct(n).as(:distinctNodes)).build
      expect(cypher_renderer.render(statement)).to eq('MATCH (n) RETURN collect(DISTINCT n) AS distinctNodes')
    end

    it 'gh84' do
      parent = Cypher.node('Parent').named(:parent)
      child = Cypher.node('Child').named(:child)
      statement = Cypher.call('apoc.create.relationship')
                        .with_args(parent.required_symbolic_name, Cypher.literal_of('ChildEdge'),
                                   Cypher.map_of('score', Cypher.literal_of(0.33), 'weight', Cypher.literal_of(1.7)),
                                   child.required_symbolic_name)
                        .yield(:rel)
                        .build
      expect(cypher_renderer.render(statement))
        .to eq("CALL apoc.create.relationship(parent, 'ChildEdge', {score: 0.33, weight: 1.7}, child) YIELD rel")
    end

    it 'aliases should be escaped if necessary' do # GH-106
      alias_name = Cypher.name(:n).as('das ist ein Alias')
      statement = Cypher.match(Cypher.any_node.named(:n)).with(alias_name).returning(alias_name).build

      expect(cypher_renderer.render(statement)).to eq('MATCH (n) WITH n AS `das ist ein Alias` RETURN `das ist ein Alias`')
    end

    it 'projected properties should be escaped if necessary' do # GH-106
      node = Cypher.any_node.named(:n)
      statement = Cypher.match(node).returning(node.project('property 1', 'property 2')).build

      expect(cypher_renderer.render(statement)).to eq('MATCH (n) RETURN n{.`property 1`, .`property 2`}')
    end
  end
end
