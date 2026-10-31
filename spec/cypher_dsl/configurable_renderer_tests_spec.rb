# frozen_string_literal: true

# Translated from renderer/ConfigurableRendererTests.java.
#
# Adapted: Java's `isSameAs` on cached renderings is `equal?` on `Statement#cypher`; the
# renamed parameters are read from the catalog of the renderer that renamed them.
module CypherDSL
  RSpec.describe 'ConfigurableRendererTests' do
    it 'caches rendered statements' do
      statement = Cypher.match(Cypher.node('Movie').named(:n)).returning(Cypher.name(:n).property(:f)).build

      cypher1 = statement.cypher
      cypher2 = statement.cypher
      expect(cypher1).to equal(cypher2)

      statement2 = Cypher.match(Cypher.node('Movie').named(:n)).returning(Cypher.name(:n).property(:f)).build
      cypher3 = statement2.cypher
      expect(cypher2).not_to equal(cypher3)
      expect(cypher2).to eq(cypher3)
    end

    it 'generates constant names per schema' do # GH-596
      actor = Cypher.node('Actor').named(:a)
      cool = Cypher.parameter(:cool)
      statement = Cypher.with(Cypher.literal_of('The Matrix').as(Cypher.name(:title)))
                        .match(Cypher.node('Movie').named(:n).with_properties('foo', Cypher.literal_of('bazbar')).relationship_from(actor, 'ACTED_IN').named(:r))
                        .where(Cypher.name(:n).property(:title).eq(Cypher.name(:title)))
                        .and(Cypher.name(:a).property(:name).eq(Cypher.literal_of('Keanu Reeves')))
                        .and(actor.property(:born).is_equal_to(Cypher.parameter(:born)))
                        .and(actor.property(:cool).is_equal_to(cool))
                        .and(actor.property(:cool2).is_equal_to(cool))
                        .and(actor.property(:whatever).is_equal_to(Cypher.parameter(:born)))
                        .and(Cypher.name(:r).property(:x).is_equal_to(Cypher.anon_parameter('foo')))
                        .returning(Cypher.name(:n).property(:f))
                        .build

      renderer = Renderer.get_renderer(Renderer::Configuration.new_config.with_generated_names(true).build)
      cypher1 = renderer.render(statement)

      expected_generated_names = "WITH 'The Matrix' AS v0 " \
                                 "MATCH (v1:`Movie` {foo: 'bazbar'})<-[v2:`ACTED_IN`]-(v3:`Actor`) " \
                                 "WHERE (v1.title = v0 AND v3.name = 'Keanu Reeves' AND v3.born = $p0 AND " \
                                 'v3.cool = $p1 AND v3.cool2 = $p1 AND v3.whatever = $p0 AND v2.x = $pcdsl01) RETURN v1.f'

      expected_default = "WITH 'The Matrix' AS title " \
                         "MATCH (n:`Movie` {foo: 'bazbar'})<-[r:`ACTED_IN`]-(a:`Actor`) " \
                         "WHERE (n.title = title AND a.name = 'Keanu Reeves' AND a.born = $born AND " \
                         'a.cool = $cool AND a.cool2 = $cool AND a.whatever = $born AND r.x = $pcdsl01) RETURN n.f'

      expect(cypher1).to eq(expected_generated_names)
      expect(renderer.catalog(statement).renamed_parameters).to eq('born' => 'p0', 'cool' => 'p1')

      # Compare a second rendering
      cypher2 = Renderer.get_renderer(Renderer::Configuration.new_config.with_generated_names(true).build).render(statement)
      expect(cypher2).to eq(expected_generated_names)

      expect(statement.cypher).to eq(expected_default)
    end

    it 'exports symbolic names' do # GH-645
      stmnt = Cypher.match(Cypher.node('N').named(:n))
                    .call(Cypher.match(Cypher.any_node(:m)).returning(Cypher.name(:m)).build)
                    .returning(:n, :m)
                    .build
      config = Renderer::Configuration.new_config.with_generated_names(Renderer::Configuration::GENERATED_NAMES - [:entity_names]).build
      expect(Renderer.get_renderer(config).render(stmnt)).to eq('MATCH (n:`N`) CALL (*) {MATCH (m) RETURN m} RETURN n, m')
    end

    it 'exports named as symbolic names' do # GH-645
      m = Cypher.any_node(:m)
      stmnt = Cypher.match(Cypher.node('N').named(:n))
                    .call(Cypher.match(m).returning(m).build)
                    .returning(:n, :m)
                    .build
      config = Renderer::Configuration.new_config.with_generated_names(Renderer::Configuration::GENERATED_NAMES - [:entity_names]).build
      expect(Renderer.get_renderer(config).render(stmnt)).to eq('MATCH (n:`N`) CALL (*) {MATCH (m) RETURN m} RETURN n, m')
    end
  end
end
