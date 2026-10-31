# frozen_string_literal: true

# Translated from CypherIT.java, nested class SetClause.
module CypherDSL
  RSpec.describe 'CypherIT / SetClause' do
    let(:user_node) { Cypher.node('User').named(:u) }
    let(:renderer) { Renderer.default }

    it 'renders set after create' do
      statement = Cypher.create(user_node)
                        .set(user_node.property(:p).to(Cypher.literal_of('Hallo, Welt')))
                        .build

      expect(renderer.render(statement)).to eq("CREATE (u:`User`) SET u.p = 'Hallo, Welt'")
    end

    it 'renders set after merge' do
      statement = Cypher.merge(user_node)
                        .set(user_node.property(:p).to(Cypher.literal_of('Hallo, Welt')))
                        .build

      expect(renderer.render(statement)).to eq("MERGE (u:`User`) SET u.p = 'Hallo, Welt'")
    end

    it 'renders set after create and with' do
      statement = Cypher.create(user_node)
                        .with(user_node)
                        .set(user_node.property(:p).to(Cypher.literal_of('Hallo, Welt')))
                        .build

      expect(renderer.render(statement)).to eq("CREATE (u:`User`) WITH u SET u.p = 'Hallo, Welt'")
    end

    it 'renders set after merge and with' do
      statement = Cypher.merge(user_node)
                        .with(user_node)
                        .set(user_node.property(:p).to(Cypher.literal_of('Hallo, Welt')))
                        .build

      expect(renderer.render(statement)).to eq("MERGE (u:`User`) WITH u SET u.p = 'Hallo, Welt'")
    end

    it 'renders set' do
      statement = Cypher.match(user_node)
                        .set(user_node.property(:p).to(Cypher.literal_of('Hallo, Welt')))
                        .build

      expect(renderer.render(statement)).to eq("MATCH (u:`User`) SET u.p = 'Hallo, Welt'")

      statement = Cypher.match(user_node)
                        .set(user_node.property(:p).to(Cypher.literal_of('Hallo, Welt')))
                        .set(user_node.property(:a).to(Cypher.literal_of('Selber hallo.')))
                        .build

      expect(renderer.render(statement)).to eq("MATCH (u:`User`) SET u.p = 'Hallo, Welt' SET u.a = 'Selber hallo.'")

      statement = Cypher.match(user_node)
                        .set(user_node.property(:p).to(Cypher.literal_of('Hallo')),
                             user_node.property(:g).to(Cypher.literal_of('Welt')))
                        .build

      expect(renderer.render(statement)).to eq("MATCH (u:`User`) SET u.p = 'Hallo', u.g = 'Welt'")
    end

    it 'renders set on nodes' do
      statement = Cypher.match(user_node).set(user_node, 'A', 'B').returning(user_node).build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) SET u:`A`:`B` RETURN u')

      statement = Cypher.match(user_node)
                        .with(user_node)
                        .set(user_node, 'A', 'B')
                        .set(user_node, 'C', 'D')
                        .returning(user_node)
                        .build

      expect(renderer.render(statement)).to eq('MATCH (u:`User`) WITH u SET u:`A`:`B` SET u:`C`:`D` RETURN u')
    end

    it 'renders set from a list of expression' do
      statement = Cypher.match(user_node).set(user_node.property(:p), Cypher.literal_of('Hallo, Welt')).build

      expect(renderer.render(statement)).to eq("MATCH (u:`User`) SET u.p = 'Hallo, Welt'")

      statement = Cypher.match(user_node)
                        .set(user_node.property(:p), Cypher.literal_of('Hallo'), user_node.property(:g),
                             Cypher.literal_of('Welt'))
                        .build

      expect(renderer.render(statement)).to eq("MATCH (u:`User`) SET u.p = 'Hallo', u.g = 'Welt'")

      statement = Cypher.match(user_node)
                        .set(user_node.property(:p), Cypher.literal_of('Hallo, Welt'))
                        .set(user_node.property(:p), Cypher.literal_of('Hallo'), user_node.property(:g),
                             Cypher.literal_of('Welt'))
                        .build

      expect(renderer.render(statement))
        .to eq("MATCH (u:`User`) SET u.p = 'Hallo, Welt' SET u.p = 'Hallo', u.g = 'Welt'")

      expect { Cypher.match(user_node).set(user_node.property(:g)) }
        .to raise_error(ArgumentError, 'The list of expression to set must be even.')
    end

    it 'renders mixed set' do
      statement = Cypher.match(user_node)
                        .set(user_node.property(:p1), Cypher.literal_of('Two expressions'))
                        .set(user_node.property(:p2).to(Cypher.literal_of('A set expression')))
                        .set(user_node.property(:p3).to(Cypher.literal_of('One of two set expression')),
                             user_node.property(:p4).to(Cypher.literal_of('Two of two set expression')))
                        .set(user_node.property(:p5), Cypher.literal_of('Pair one of 2 expressions'),
                             user_node.property(:p6), Cypher.literal_of('Pair two of 4 expressions'))
                        .returning(Cypher.asterisk)
                        .build

      expect(renderer.render(statement)).to eq(
        "MATCH (u:`User`) SET u.p1 = 'Two expressions' SET u.p2 = 'A set expression' SET u.p3 = 'One of two set expression', u.p4 = 'Two of two set expression' SET u.p5 = 'Pair one of 2 expressions', u.p6 = 'Pair two of 4 expressions' RETURN *"
      )
    end
  end
end
