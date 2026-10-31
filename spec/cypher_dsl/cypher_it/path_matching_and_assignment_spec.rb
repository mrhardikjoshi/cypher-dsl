# frozen_string_literal: true

# Translated from CypherIT.java, nested class PathMatchingAndAssignment.
module CypherDSL
  RSpec.describe 'CypherIT / PathMatchingAndAssignment' do
    let(:renderer) { Renderer.get_renderer(Renderer::Configuration.new_config.always_escape_names(false).build) }

    let(:stations_pattern) do
      Cypher.node('Station')
            .named(:wos)
            .relationship_between(Cypher.node('Station').named(:bmv), 'LINK')
            .quantify_relationship(QuantifiedPathPattern.plus)
    end

    let(:stops) do
      Cypher.list_with(Cypher.name(:n))
            .in(Cypher.nodes(Cypher.path(:p).get))
            .returning(Cypher.property(:n, :name))
            .as(:stops)
    end

    it 'plain' do
      pattern = Cypher.node('Station').relationship_to(Cypher.node('Station').named(:b), 'LINK').named(:l)
      statement = Cypher.match(Cypher.path(:p).defined_by(pattern)).returning(Cypher.name(:p)).build
      expect(statement.cypher).to eq('MATCH p = (:`Station`)-[l:`LINK`]->(b:`Station`) RETURN p')
    end

    it 'deprecated shortest' do
      pattern = Cypher.node('Station').relationship_to(Cypher.node('Station').named(:b), 'LINK').named(:l)
      statement = Cypher.match(Cypher.any_shortest.named(:p).defined_by(pattern))
                        .returning(Cypher.name(:p))
                        .build
      expect(statement.cypher).to eq('MATCH p = ANY (:`Station`)-[l:`LINK`]->(b:`Station`) RETURN p')
    end

    [-1, 0, 1, 5].each do |k|
      it "shortest k(#{k})" do
        if k <= 0
          expect { Cypher.shortest_k(k) }.to raise_error(ArgumentError, 'The path count needs to be greater than 0.')
        else
          statement = Cypher.match(Cypher.shortest_k(k).named(:p).defined_by(stations_pattern))
                            .where(Cypher.property(:wos, :name).is_equal_to(Cypher.literal_of('Worcester Shrub Hill')))
                            .and(Cypher.property(:bmv, :name).is_equal_to(Cypher.literal_of('Bromsgrove')))
                            .returning(Cypher.length(Cypher.path(:p).get).as(:result))
                            .build
          expect(renderer.render(statement)).to eq(
            "MATCH p = SHORTEST #{k} (wos:Station)-[:LINK]-+(bmv:Station) WHERE (wos.name = 'Worcester Shrub Hill' AND bmv.name = 'Bromsgrove') RETURN length(p) AS result"
          )
        end
      end
    end

    [-1, 0, 1, 2].each do |k|
      it "shortest k groups(#{k})" do
        if k <= 0
          expect { Cypher.shortest_k(k) }.to raise_error(ArgumentError, 'The path count needs to be greater than 0.')
        else
          statement = Cypher.match(Cypher.shortest_k_groups(k).named(:p).defined_by(stations_pattern))
                            .where(Cypher.property(:wos, :name).is_equal_to(Cypher.literal_of('Worcester Shrub Hill')))
                            .and(Cypher.property(:bmv, :name).is_equal_to(Cypher.literal_of('Bromsgrove')))
                            .returning(stops, Cypher.length(Cypher.path(:p).get).as(:pathLength))
                            .build
          expect(renderer.render(statement)).to eq(
            "MATCH p = SHORTEST #{k} GROUPS (wos:Station)-[:LINK]-+(bmv:Station) WHERE (wos.name = 'Worcester Shrub Hill' AND bmv.name = 'Bromsgrove') RETURN [n IN nodes(p) | n.name] AS stops, length(p) AS pathLength"
          )
        end
      end
    end

    it 'all shortest' do
      statement = Cypher.match(Cypher.all_shortest.named(:p).defined_by(stations_pattern))
                        .where(Cypher.property(:wos, :name).is_equal_to(Cypher.literal_of('Worcester Shrub Hill')))
                        .and(Cypher.property(:bmv, :name).is_equal_to(Cypher.literal_of('Bromsgrove')))
                        .returning(stops)
                        .build
      expect(renderer.render(statement)).to eq(
        "MATCH p = ALL SHORTEST (wos:Station)-[:LINK]-+(bmv:Station) WHERE (wos.name = 'Worcester Shrub Hill' AND bmv.name = 'Bromsgrove') RETURN [n IN nodes(p) | n.name] AS stops"
      )
    end

    it 'any shortest' do
      pattern = Cypher.node('Station')
                      .with_properties('name', Cypher.literal_of('Pershore'))
                      .relationship_between(Cypher.node('Station').named(:b).with_properties('name', Cypher.literal_of('Bromsgrove')), 'LINK')
                      .named(:l)
                      .quantify_relationship(QuantifiedPathPattern.plus)
                      .where(Cypher.property(:l, :distance).lt(Cypher.literal_of(10)))

      distances = Cypher.list_with(Cypher.name(:r))
                        .in(Cypher.relationships(Cypher.path(:path).get))
                        .returning(Cypher.property(:r, :distance))
                        .as(:distances)

      statement = Cypher.match(Cypher.any_shortest.named(:path).defined_by(pattern))
                        .returning(distances)
                        .build

      expect(renderer.render(statement)).to eq(
        "MATCH path = ANY (:Station {name: 'Pershore'})-[l:LINK WHERE l.distance < 10]-+(b:Station {name: 'Bromsgrove'}) RETURN [r IN relationships(path) | r.distance] AS distances"
      )
    end
  end
end
