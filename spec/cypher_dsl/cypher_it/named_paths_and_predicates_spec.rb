# frozen_string_literal: true

# Translated from CypherIT.java, nested classes NamedPaths and Predicatez.
#
# Skipped on purpose:
# - selectorShouldBeSensible: exercises the Java-internal RendererBridge / PatternSelector API.
module CypherDSL
  RSpec.describe 'CypherIT / NamedPaths' do
    let(:renderer) { Renderer.default }

    it 'doc3148' do
      # See docs
      p = Cypher.path(:p)
                .defined_by(Cypher.any_node(:michael)
                                  .with_properties('name', Cypher.literal_of('Michael Douglas'))
                                  .relationship_to(Cypher.any_node))
      statement = Cypher.match(p).returning(p).build

      expect(renderer.render(statement)).to eq("MATCH p = (michael {name: 'Michael Douglas'})-->() RETURN p")
    end

    it 'works in list comprehensions' do
      p = Cypher.path(:p).defined_by(Cypher.any_node(:n).relationship_to(Cypher.any_node, 'LIKES', 'OWNS').unbounded)
      statement = Cypher.returning(Cypher.list_based_on(p).returning(p)).build

      expect(renderer.render(statement)).to eq('RETURN [p = (n)-[:`LIKES`|`OWNS`*]->() | p]')
    end

    it 'works with relationship patterns' do # GH-200
      relationship_pattern = Cypher.any_node(:n).relationship_to(Cypher.any_node(:m))
      p = Cypher.path(:p).defined_by(relationship_pattern)
      statement = Cypher.match(p).returning(p).build

      expect(renderer.render(statement)).to eq('MATCH p = (n)-->(m) RETURN p')
    end

    it 'works with nodes' do # GH-200
      p = Cypher.path(:p).defined_by(Cypher.any_node(:n))
      statement = Cypher.match(p).returning(p).build

      expect(renderer.render(statement)).to eq('MATCH p = (n) RETURN p')
    end

    it 'directlies use provided named paths' do # GH-200
      p = Cypher.path(:p).defined_by(Cypher.any_node(:n))
      x = Cypher.path(:x).defined_by(p)
      statement = Cypher.match(x).returning(p).build

      expect(renderer.render(statement)).to eq('MATCH p = (n) RETURN p')
    end
  end

  RSpec.describe 'CypherIT / Predicatez' do
    let(:renderer) { Renderer.default }

    it 'all should work' do
      p = Cypher.path(:p).defined_by(Cypher.any_node(:a).relationship_to(Cypher.any_node(:b)).min(1).max(3))
      statement = Cypher.match(p)
                        .where(Cypher.property(:a, :name).is_equal_to(Cypher.literal_of('Alice')))
                        .and(Cypher.property(:b, :name).is_equal_to(Cypher.literal_of('Daniel')))
                        .and(Cypher.all(:x).in(Cypher.nodes(p)).where(Cypher.property(:x, :age).gt(Cypher.literal_of(30))))
                        .returning(p)
                        .build

      expect(renderer.render(statement)).to eq(
        "MATCH p = (a)-[*1..3]->(b) WHERE (a.name = 'Alice' AND b.name = 'Daniel' AND all(x IN nodes(p) WHERE x.age > 30)) RETURN p"
      )
    end

    it 'any should work' do
      a = Cypher.any_node(:a)
      statement = Cypher.match(a)
                        .where(Cypher.property(:a, :name).is_equal_to(Cypher.literal_of('Eskil')))
                        .and(Cypher.any(:x).in(a.property(:array)).where(Cypher.name(:x).is_equal_to(Cypher.literal_of('one'))))
                        .returning(a.property(:name), a.property(:array))
                        .build

      expect(renderer.render(statement)).to eq(
        "MATCH (a) WHERE (a.name = 'Eskil' AND any(x IN a.array WHERE x = 'one')) RETURN a.name, a.array"
      )
    end

    it 'none should work' do
      p = Cypher.path(:p).defined_by(Cypher.any_node(:a).relationship_to(Cypher.any_node(:b)).min(1).max(3))
      statement = Cypher.match(p)
                        .where(Cypher.property(:a, :name).is_equal_to(Cypher.literal_of('Alice')))
                        .and(Cypher.none(:x)
                                   .in(Cypher.nodes(p))
                                   .where(Cypher.property(:x, :age).is_equal_to(Cypher.literal_of(25))))
                        .returning(p)
                        .build

      expect(renderer.render(statement)).to eq(
        "MATCH p = (a)-[*1..3]->(b) WHERE (a.name = 'Alice' AND none(x IN nodes(p) WHERE x.age = 25)) RETURN p"
      )
    end

    it 'single should work' do
      p = Cypher.path(:p).defined_by(Cypher.any_node(:n).relationship_to(Cypher.any_node(:b)))
      statement = Cypher.match(p)
                        .where(Cypher.property(:n, :name).is_equal_to(Cypher.literal_of('Alice')))
                        .and(Cypher.single(:var)
                                   .in(Cypher.nodes(p))
                                   .where(Cypher.property(:var, :eyes).is_equal_to(Cypher.literal_of('blue'))))
                        .returning(p)
                        .build

      expect(renderer.render(statement)).to eq(
        "MATCH p = (n)-->(b) WHERE (n.name = 'Alice' AND single(var IN nodes(p) WHERE var.eyes = 'blue')) RETURN p"
      )
    end
  end
end
