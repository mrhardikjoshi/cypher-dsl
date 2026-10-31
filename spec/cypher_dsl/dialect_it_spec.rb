# frozen_string_literal: true

# Translated from DialectIT.java.
#
# Adapted: `Cypher.parameter('foo', List.of("k", "l"))` is a parameter with a Ruby array value.
module CypherDSL
  RSpec.describe 'DialectIT' do
    def renderer_for(dialect, disable_dynamic_labels: false)
      config = Renderer::Configuration.new_config.with_dialect(dialect).disable_dynamic_labels(disable_dynamic_labels).build
      Renderer.get_renderer(config)
    end

    [
      [Renderer::Dialect::NEO4J_4, false, 'MATCH (n:`Movie`) WHERE exists(n.title) RETURN n'],
      [Renderer::Dialect::NEO4J_4, true, 'MATCH (n:`Movie`) WHERE NOT (exists(n.title)) RETURN n'],
      [Renderer::Dialect::NEO4J_5, false, 'MATCH (n:`Movie`) WHERE n.title IS NOT NULL RETURN n'],
      [Renderer::Dialect::NEO4J_5, true, 'MATCH (n:`Movie`) WHERE n.title IS NULL RETURN n']
    ].each do |dialect, negate, expected|
      it "n prop exists (#{dialect}, negate: #{negate})" do
        n = Cypher.node('Movie').named(:n)
        condition = Cypher.exists(n.property(:title))
        condition = condition.not if negate
        cypher = renderer_for(dialect).render(Cypher.match(n).where(condition).returning(n).build)
        expect(cypher).to eq(expected)
      end
    end

    {
      Renderer::Dialect::NEO4J_4 => 'MATCH (n) RETURN distance(n.a, n.b)',
      Renderer::Dialect::NEO4J_5 => 'MATCH (n) RETURN point.distance(n.a, n.b)'
    }.each do |dialect, expected|
      it "distance function (#{dialect})" do
        n = Cypher.any_node(:n)
        cypher = renderer_for(dialect).render(Cypher.match(n).returning(Cypher.distance(n.property(:a), n.property(:b))).build)
        expect(cypher).to eq(expected)
      end
    end

    {
      Renderer::Dialect::NEO4J_4 => 'MATCH (n) RETURN toString(id(n))',
      Renderer::Dialect::NEO4J_5 => 'MATCH (n) RETURN elementId(n)'
    }.each do |dialect, expected|
      it "element id (#{dialect})" do
        n = Cypher.any_node(:n)
        cypher = renderer_for(dialect).render(Cypher.match(n).returning(n.element_id).build)
        expect(cypher).to eq(expected)
      end
    end

    {
      Renderer::Dialect::NEO4J_4 => 'MATCH p = shortestPath((wos:`Station`)-[:`LINK`]->(bmv:`Station`)) RETURN p',
      Renderer::Dialect::NEO4J_5 => 'MATCH p = shortestPath((wos:`Station`)-[:`LINK`]->(bmv:`Station`)) RETURN p',
      Renderer::Dialect::NEO4J_5_23 => 'MATCH p = SHORTEST 1 (wos:`Station`)-[:`LINK`]->(bmv:`Station`) RETURN p',
      Renderer::Dialect::NEO4J_5_26 => 'CYPHER 5 MATCH p = SHORTEST 1 (wos:`Station`)-[:`LINK`]->(bmv:`Station`) RETURN p',
      Renderer::Dialect::NEO4J_5_DEFAULT_CYPHER => 'MATCH p = SHORTEST 1 (wos:`Station`)-[:`LINK`]->(bmv:`Station`) RETURN p',
      Renderer::Dialect::NEO4J_5_CYPHER_5 => 'CYPHER 5 MATCH p = SHORTEST 1 (wos:`Station`)-[:`LINK`]->(bmv:`Station`) RETURN p',
      Renderer::Dialect::NEO4J_5_CYPHER_25 => 'CYPHER 25 MATCH p = SHORTEST 1 (wos:`Station`)-[:`LINK`]->(bmv:`Station`) RETURN p'
    }.each do |dialect, expected|
      it "shortest path (#{dialect})" do
        stmt = Cypher.match(Cypher.shortest_k(1)
                                  .named(:p)
                                  .defined_by(Cypher.node('Station').named(:wos).relationship_to(Cypher.node('Station').named(:bmv), 'LINK')))
                     .returning(Cypher.name(:p))
                     .build
        expect(renderer_for(dialect).render(stmt)).to eq(expected)
      end
    end

    {
      Renderer::Dialect::NEO4J_4 => 'MATCH p = allShortestPaths((wos:`Station`)-[:`LINK`]->(bmv:`Station`)) RETURN p',
      Renderer::Dialect::NEO4J_5 => 'MATCH p = allShortestPaths((wos:`Station`)-[:`LINK`]->(bmv:`Station`)) RETURN p',
      Renderer::Dialect::NEO4J_5_23 => 'MATCH p = ALL SHORTEST (wos:`Station`)-[:`LINK`]->(bmv:`Station`) RETURN p',
      Renderer::Dialect::NEO4J_5_26 => 'CYPHER 5 MATCH p = ALL SHORTEST (wos:`Station`)-[:`LINK`]->(bmv:`Station`) RETURN p',
      Renderer::Dialect::NEO4J_5_DEFAULT_CYPHER => 'MATCH p = ALL SHORTEST (wos:`Station`)-[:`LINK`]->(bmv:`Station`) RETURN p',
      Renderer::Dialect::NEO4J_5_CYPHER_5 => 'CYPHER 5 MATCH p = ALL SHORTEST (wos:`Station`)-[:`LINK`]->(bmv:`Station`) RETURN p',
      Renderer::Dialect::NEO4J_5_CYPHER_25 => 'CYPHER 25 MATCH p = ALL SHORTEST (wos:`Station`)-[:`LINK`]->(bmv:`Station`) RETURN p'
    }.each do |dialect, expected|
      it "all shortest path (#{dialect})" do
        stmt = Cypher.match(Cypher.all_shortest
                                  .named(:p)
                                  .defined_by(Cypher.node('Station').named(:wos).relationship_to(Cypher.node('Station').named(:bmv), 'LINK')))
                     .returning(Cypher.name(:p))
                     .build
        expect(renderer_for(dialect).render(stmt)).to eq(expected)
      end
    end

    describe 'label rendering should work' do
      static = 'MATCH (m:`Movie`) SET m:`a`:`b`:`c`:`d`:`e`:`f`:`g`:`h`:`i`:`j`:`k`:`l`:`m` RETURN *'
      dynamic = "MATCH (m:`Movie`) SET m:$($x):$($y):$($z):$(['f', 'g']):$('h'):$(['i', 'j']):$($foo):$($bar) RETURN *"

      [
        [false, Renderer::Dialect::NEO4J_4, static],
        [false, Renderer::Dialect::NEO4J_5, static],
        [false, Renderer::Dialect::NEO4J_5_23, static],
        [false, Renderer::Dialect::NEO4J_5_26, "CYPHER 5 #{dynamic}"],
        [false, Renderer::Dialect::NEO4J_5_CYPHER_5, "CYPHER 5 #{dynamic}"],
        [false, Renderer::Dialect::NEO4J_5_DEFAULT_CYPHER, dynamic],
        [false, Renderer::Dialect::NEO4J_5_CYPHER_25, "CYPHER 25 #{dynamic}"],
        [true, Renderer::Dialect::NEO4J_4, static],
        [true, Renderer::Dialect::NEO4J_5, static],
        [true, Renderer::Dialect::NEO4J_5_23, static],
        [true, Renderer::Dialect::NEO4J_5_26, "CYPHER 5 #{static}"],
        [true, Renderer::Dialect::NEO4J_5_CYPHER_5, "CYPHER 5 #{static}"],
        [true, Renderer::Dialect::NEO4J_5_DEFAULT_CYPHER, static],
        [true, Renderer::Dialect::NEO4J_5_CYPHER_25, "CYPHER 25 #{static}"]
      ].each do |disable_dynamic_labels, dialect, expected|
        it "#{dialect}, dynamic labels disabled: #{disable_dynamic_labels}" do
          m = Cypher.node(Cypher.exactly_label('Movie')).named(:m)
          parameter_with_list_of_strings = Cypher.parameter(:x, Cypher.list_of(Cypher.literal_of('a'), Cypher.literal_of('b')))
          parameter_with_a_single_string = Cypher.parameter(:y, Cypher.literal_of('c'))
          parameter_with_list_literal = Cypher.parameter(:z, Cypher.literal_of([Cypher.literal_of('d'), Cypher.literal_of('e')]))
          parameter_with_a_list_of_ruby_strings = Cypher.parameter(:foo, %w[k l])

          stmt = Cypher.match(m)
                       .set(m, Labels.all(parameter_with_list_of_strings)
                                     .conjunction_with(Labels.all(parameter_with_a_single_string))
                                     .conjunction_with(Labels.all(parameter_with_list_literal))
                                     .conjunction_with(Labels.all(Cypher.list_of(Cypher.literal_of('f'), Cypher.literal_of('g'))))
                                     .conjunction_with(Labels.all(Cypher.literal_of('h')))
                                     .conjunction_with(Labels.all(Cypher.literal_of([Cypher.literal_of('i'), Cypher.literal_of('j')])))
                                     .conjunction_with(Labels.all(parameter_with_a_list_of_ruby_strings))
                                     .conjunction_with(Labels.all(Cypher.parameter(:bar, 'm'))))
                       .returning(Cypher.asterisk)
                       .build

          expect(renderer_for(dialect, disable_dynamic_labels:).render(stmt)).to eq(expected)
        end
      end
    end

    it 'expressions might not be rendered in labels' do
      m = Cypher.node('Movie').named(:m)
      stmt = Cypher.match(m).set(m, Labels.all(m.property(:x))).returning(Cypher.asterisk).build

      renderer = renderer_for(Renderer::Dialect::NEO4J_4)
      expect { renderer.render(stmt) }.to raise_error(ArgumentError, 'Cannot render the given Labels in a Cypher pre 5.26 compatible way')
    end

    it 'renders element id' do # GH-539
      screen = Cypher.node('ScreenStateNode').named(:screen)
      id = Cypher.literal_of('4:d32903f5-48ef-40fb-9ce5-9a3039852c46:2')
      statement = Cypher.match(screen)
                        .where(Cypher.element_id(screen).eq(id))
                        .returning(Cypher.element_id(screen))
                        .build
      # Config and renderer are immutable, you can store them somewhere global
      renderer_config = Renderer::Configuration.new_config.with_dialect(Renderer::Dialect::NEO4J_5).build
      renderer = Renderer.get_renderer(renderer_config)
      cypher = renderer.render(statement)
      expect(cypher).to eq("MATCH (screen:`ScreenStateNode`) WHERE elementId(screen) = '4:d32903f5-48ef-40fb-9ce5-9a3039852c46:2' RETURN elementId(screen)")
    end
  end
end
