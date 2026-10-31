# frozen_string_literal: true

# Translated from IssueRelatedIT.java, fourth slice (GH-388 … GH-634).
#
# Adapted: `rerenderShouldYieldSameResultOnSameRenderer` reflects into the Java renderer cache; here it
# checks that repeated rendering is stable.
module CypherDSL
  RSpec.describe 'IssueRelatedIT (4)' do
    let(:pretty) { Renderer.get_renderer(Renderer::Configuration.pretty_printing) }
    let(:person) { Cypher.node('Person').named(:person) }

    def pretty_for(dialect)
      Renderer.get_renderer(Renderer::Configuration.new_config.with_dialect(dialect).with_pretty_print(true).build)
    end

    it 'provides set operations for parameter' do # GH-388
      node = Cypher.node('CordraObject').named(:existingNode).with_properties('_id', Cypher.literal_of('test/55de0539eb1e14f26a04'))
      this_changes_everything = node.set(Cypher.parameter(:aNewMap))
      statement = Cypher.merge(node).set(this_changes_everything).returning(node).build

      expect(pretty.render(statement)).to eq(<<~CYPHER.chomp)
        MERGE (existingNode:CordraObject {
          _id: 'test/55de0539eb1e14f26a04'
        })
        SET existingNode = $aNewMap
        RETURN existingNode
      CYPHER
    end

    it 'aliased elements should be carried forward with with too' do # GH-419
      object_instance_node = Cypher.node('ObjectInstance').named(:oi)
      attribute_type_node = Cypher.node('AttributeType').named(:att)
      attribute_node = Cypher.node('Attribute').named(:at)
      attribute_type_and_value = Cypher.name(:attributeTypeAndValue)
      collection = Cypher.name(:collection)

      oi = object_instance_node.required_symbolic_name
      statement = Cypher.match(object_instance_node)
                        .with(Cypher.map_of(oi.value, oi).as(collection))
                        .unwind(Cypher.parameter(:attributes))
                        .as(attribute_type_and_value)
                        .with(attribute_type_and_value, collection)
                        .match(attribute_type_node.with_properties('name', attribute_type_and_value.property(:name))
                                                  .relationship_from(attribute_node, 'OF_TYPE'))
                        .with(attribute_node, collection.property(:oi).as(oi))
                        .match(object_instance_node.relationship_to(attribute_node, 'IS_IDENTIFIED_BY'))
                        .returning(attribute_node)
                        .build

      renderer = Renderer.get_renderer(Renderer::Configuration.new_config.with_pretty_print(true).always_escape_names(true).build)
      expect(renderer.render(statement)).to eq(<<~CYPHER.chomp)
        MATCH (oi:`ObjectInstance`)
        WITH {
          oi: oi
        } AS collection
        UNWIND $attributes AS attributeTypeAndValue
        WITH attributeTypeAndValue, collection
        MATCH (att:`AttributeType` {
          name: attributeTypeAndValue.name
        })<-[:`OF_TYPE`]-(at:`Attribute`)
        WITH at, collection.oi AS oi
        MATCH (oi)-[:`IS_IDENTIFIED_BY`]->(at)
        RETURN at
      CYPHER
    end

    it 'bb box manual' do
      location = Cypher.node('Location').named(:loc)
      sw = Cypher.point(Cypher.map_of('longitude', Cypher.literal_of(2.592773), 'latitude', Cypher.literal_of(46.346928)))
      ne = Cypher.point(Cypher.map_of('longitude', Cypher.literal_of(18.654785), 'latitude', Cypher.literal_of(55.714735)))
      within_bbox = Cypher.call('point.withinBBox').with_args(location.property(:coordinates), sw, ne).as_function

      conditions = Cypher.no_condition
      conditions = conditions.and(within_bbox.as_condition)

      stmt = Cypher.match(location).where(conditions).returning(location).build.cypher
      expect(stmt).to eq(
        'MATCH (loc:`Location`) WHERE point.withinBBox(loc.coordinates, point({longitude: 2.592773, latitude: 46.346928}), point({longitude: 18.654785, latitude: 55.714735})) RETURN loc'
      )
    end

    it 'bb box' do
      location = Cypher.node('Location').named(:loc)
      sw = Cypher.coordinate(2.592773, 46.346928)
      ne = Cypher.coordinate(18.654785, 55.714735)
      within_bbox = Cypher.within_bbox(location.property(:coordinates), sw, ne)

      conditions = Cypher.no_condition
      conditions = conditions.and(within_bbox.as_condition)

      stmt = Cypher.match(location).where(conditions).returning(location).build.cypher
      expect(stmt).to eq(
        'MATCH (loc:`Location`) WHERE point.withinBBox(loc.coordinates, point({longitude: 2.592773, latitude: 46.346928}), point({longitude: 18.654785, latitude: 55.714735})) RETURN loc'
      )
    end

    it 'allows asterisk in yield' do # GH-490
      yield_statement = Cypher.call('db.info').yield(Cypher.asterisk).build
      expect(Renderer.default.render(yield_statement)).to eq('CALL db.info() YIELD *')
    end

    it 'allows asterisk in yield and args' do # GH-544
      yield_statement = Cypher.call('dbms.listConfig').with_args(Cypher.literal_of('port')).yield(Cypher.asterisk).build
      expect(Renderer.default.render(yield_statement)).to eq("CALL dbms.listConfig('port') YIELD *")
    end

    it 'test label removal' do # GH-505
      node = Cypher.node('Wine').named(:n)

      remove_op = Cypher.remove_label(node, 'Drink')
      ongoing_reading_with_where = Cypher.match(node).where(Cypher.id(node).is_equal_to(Cypher.literal_of(1)))

      expected_message = 'REMOVE operations are not supported in a SET clause'
      expect { ongoing_reading_with_where.set([remove_op]) }.to raise_error(ArgumentError, expected_message)
      expect { ongoing_reading_with_where.set(remove_op) }.to raise_error(ArgumentError, expected_message)
      expect { Cypher.match(node).set(remove_op) }.to raise_error(ArgumentError, expected_message)

      correct_query = ongoing_reading_with_where.remove(node, 'Drink').returning(Cypher.id(node).as(:id)).build.cypher
      expect(correct_query).to eq('MATCH (n:`Wine`) WHERE id(n) = 1 REMOVE n:`Drink` RETURN id(n) AS id')
    end

    it 'unwind without with' do # GH-524
      id = Cypher.name(:id)
      n = Cypher.node('Person').named(:n)
      renderer = Renderer.get_renderer(Renderer::Configuration.new_config.with_dialect(Renderer::Dialect::NEO4J_5).build)
      statement = Cypher.unwind(Cypher.parameter(:ids))
                        .as(id)
                        .match(n)
                        .where(n.element_id.is_equal_to(id))
                        .returning(n)
                        .build
      expect(renderer.render(statement)).to eq('UNWIND $ids AS id MATCH (n:`Person`) WHERE elementId(n) = id RETURN n')
    end

    it 'mixed bag of with' do # GH-547
      cypher = Cypher.match(person)
                     .with(person, Cypher.count(person.relationship_to(Cypher.any_node, 'ACTED_IN')).as(:actedInDegree))
                     .returning(Cypher.asterisk)
                     .build
                     .cypher
      expect(cypher).to eq('MATCH (person:`Person`) WITH person, COUNT { (person)-[:`ACTED_IN`]->() } AS actedInDegree RETURN *')
    end

    it 'allow covariant for making dynamic cypher creation easier' do # GH-553
      patterns = [Cypher.node('A').named(:a), Cypher.node('B').relationship_to(Cypher.node('C'), 'IS_RELATED').named(:r)]
      cypher = Cypher.match(patterns).returning(Cypher.asterisk).build.cypher
      expect(cypher).to eq('MATCH (a:`A`), (:`B`)-[r:`IS_RELATED`]->(:`C`) RETURN *')
    end

    it 'rerender should yield same result on same renderer' do # GH-585
      anonymous = Cypher.node('Person')
      statement = Cypher.match(anonymous).delete(anonymous).build
      s1 = statement.cypher
      s2 = statement.cypher
      s3 = Renderer.default.render(statement)
      s4 = Renderer.default.render(statement)
      expect(s1).to eq(s2)
      expect(s2).to eq(s3)
      expect(s3).to eq(s4)
    end

    it 'union must not destroy scope' do # GH-589
      actor = Cypher.node('Actor').named(:a)
      movie = Cypher.node('Movie').named(:m)
      serie = Cypher.node('Serie').named(:s)
      x = Cypher.name(:x)
      statement = Cypher.match(actor)
                        .call(Cypher.union(
                                Cypher.with(actor).match(actor.relationship_to(movie).named(:ACTED_IN)).returning(movie.as(x.value)).build,
                                Cypher.with(actor).match(actor.relationship_to(serie).named(:ACTED_IN)).returning(serie.as(x.value)).build
                              ))
                        .returning(x)
                        .build

      expect(pretty.render(statement)).to eq(<<~CYPHER.chomp)
        MATCH (a:Actor)
        CALL (*) {
          WITH a
          MATCH (a)-[ACTED_IN]->(m:Movie)
          RETURN m AS x UNION
          WITH a
          MATCH (a)-[ACTED_IN]->(s:Serie)
          RETURN s AS x
        }
        RETURN x
      CYPHER
    end

    describe 'call with must import into scope' do # GH-595
      let(:var) { Cypher.name(:var) }
      let(:movie) { Cypher.node('Movie').named(:m) }
      let(:actor) { Cypher.node('Actor').named(:a) }
      let(:actors) { Cypher.name(:actors) }
      let(:legacy_expected) do
        <<~CYPHER.chomp
          UNWIND $x AS var
          CALL {
            WITH var
            CREATE (m:Movie)
            RETURN m
          }
          CALL {
            WITH m
            MATCH (m)<-[:ACTED_IN]-(a:Actor)
            RETURN collect(a) AS actors
          }
          RETURN m {
            .title,
            actors: actors
          }
        CYPHER
      end
      let(:expected) do
        <<~CYPHER.chomp
          UNWIND $x AS var
          CALL (var) {
            CREATE (m:Movie)
            RETURN m
          }
          CALL (m) {
            MATCH (m)<-[:ACTED_IN]-(a:Actor)
            RETURN collect(a) AS actors
          }
          RETURN m {
            .title,
            actors: actors
          }
        CYPHER
      end

      it 'with a leading WITH' do
        statement = Cypher.unwind(Cypher.parameter(:x))
                          .as(var)
                          .call(Cypher.with(var).create(movie).returning(movie).build)
                          .call(Cypher.with(movie).match(movie.relationship_from(actor, 'ACTED_IN')).returning(Cypher.collect(actor).as(actors)).build)
                          .returning(movie.project(movie.property(:title), 'actors', actors))
                          .build
        expect(pretty_for(Renderer::Dialect::NEO4J_4).render(statement)).to eq(legacy_expected)
        expect(pretty.render(statement)).to eq(expected)
      end

      it 'with proper imports' do
        statement = Cypher.unwind(Cypher.parameter(:x))
                          .as(var)
                          .call(Cypher.create(movie).returning(movie).build, var)
                          .call(Cypher.match(movie.relationship_from(actor, 'ACTED_IN')).returning(Cypher.collect(actor).as(actors)).build, movie)
                          .returning(movie.project(movie.property(:title), 'actors', actors))
                          .build
        expect(pretty_for(Renderer::Dialect::NEO4J_4).render(statement)).to eq(legacy_expected)
        expect(pretty.render(statement)).to eq(expected)
      end
    end

    {
      'RETURN 1, true' => -> { Cypher.returning(Cypher.literal_of(1), Cypher.literal_true.as_condition).build },
      'RETURN 1, (true AND false)' => -> { Cypher.returning(Cypher.literal_of(1), Cypher.literal_true.as_condition.and(Cypher.literal_false.as_condition)).build },
      'RETURN 1, (true OR false)' => -> { Cypher.returning(Cypher.literal_of(1), Cypher.literal_true.as_condition.or(Cypher.literal_false.as_condition)).build }
    }.each do |expected, statement|
      it "condition expression should work in return: #{expected}" do # GH-605
        expect(statement.call.cypher).to eq(expected)
      end
    end

    it 'manipulating list expressions should be possible' do
      n = Cypher.node('Person').named(:n)
      x = Cypher.name(:x)
      roles_to_add = Cypher.parameter(:rolesToAdd)
      roles_to_remove = Cypher.parameter(:rolesToRemove)
      cypher = Cypher.match(n)
                     .returning(Cypher.list_with(x)
                                      .in(n.property(:roles))
                                      .where(x.in(roles_to_add).and(Cypher.not(x.in(roles_to_remove))))
                                      .returning
                                      .add(roles_to_add))
                     .build
                     .cypher
      expect(cypher).to eq('MATCH (n:`Person`) RETURN ([x IN n.roles WHERE (x IN $rolesToAdd AND NOT (x IN $rolesToRemove))] + $rolesToAdd)')
    end

    it 'types of should work' do # GH-630
      p = Cypher.path(:p).defined_by(Cypher.node('Movie').relationship_from(Cypher.any_node).named(:r))
      x = Cypher.name(:x)
      relation_type_cast = Cypher.list_with(x).in(Cypher.relationships(p)).returning(Cypher.type(x))

      expect(Cypher.match(p).returning(relation_type_cast).build.cypher).to eq('MATCH p = (:`Movie`)<-[r]-() RETURN [x IN relationships(p) | type(x)]')

      # Current workaround
      relation_type_cast2 = Cypher.list_with(x).in(Cypher.relationships(p)).returning(Cypher.call('type').with_args(x).as_function)
      expect(Cypher.match(p).returning(relation_type_cast2).build.cypher).to eq('MATCH p = (:`Movie`)<-[r]-() RETURN [x IN relationships(p) | type(x)]')
    end

    it 'labels of should work' do # GH-630
      p = Cypher.path(:p).defined_by(Cypher.node('Movie').relationship_from(Cypher.any_node).named(:r))

      nodes = Cypher.name(:nodes)
      node = Cypher.name(:node)
      labels = Cypher.name(:labels)
      label = Cypher.name(:label)

      # The worst query ever to retrieve those labels. Don't do this at home.
      expect(Cypher.match(p)
                   .with(Cypher.nodes(p).as(nodes))
                   .unwind(nodes)
                   .as(node)
                   .with(Cypher.labels(node).as(labels))
                   .unwind(labels)
                   .as(label)
                   .returning_distinct(label)
                   .build
                   .cypher).to eq(
                     'MATCH p = (:`Movie`)<-[r]-() WITH nodes(p) AS nodes UNWIND nodes AS node WITH labels(node) AS labels UNWIND labels AS label RETURN DISTINCT label'
                   )
    end

    it 'with all should work' do # GH-634
      this0 = Cypher.node('User').named(:this)
      x = Cypher.name(:x)
      stmt = Cypher.match(this0)
                   .call(Cypher.with(Cypher.asterisk).with(this0.as(:x)).returning(Cypher.count(Cypher.asterisk).as(x)).build)
                   .returning(x, Cypher.count(Cypher.asterisk))
                   .build

      expect(stmt.cypher).to eq('MATCH (this:`User`) CALL (*) {WITH this AS x RETURN count(*) AS x} RETURN x, count(*)')
      expect(Renderer.get_renderer(Renderer::Configuration.new_config.with_dialect(Renderer::Dialect::NEO4J_4).build).render(stmt))
        .to eq('MATCH (this:`User`) CALL {WITH * WITH this AS x RETURN count(*) AS x} RETURN x, count(*)')
    end
  end
end
