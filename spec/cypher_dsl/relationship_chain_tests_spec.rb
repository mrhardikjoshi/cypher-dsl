# frozen_string_literal: true

# Translated from RelationshipChainTests.java.
module CypherDSL
  RSpec.describe 'RelationshipChainTests' do
    let(:s) { Cypher.node('Start').named(:s) }
    let(:e) { Cypher.node('End').named(:e) }
    let(:chain1) { s.relationship_to(Cypher.any_node).relationship_to(e) }

    it 'named should return new' do
      chain2 = chain1.named(:x)
      expect(chain2).not_to be(chain1)

      cypher1 = Cypher.match(chain1).returning(Cypher.asterisk).build.cypher
      expect(cypher1).to eq('MATCH (s:`Start`)-->()-->(e:`End`) RETURN *')

      cypher2 = Cypher.match(chain2).returning(Cypher.asterisk).build.cypher
      expect(cypher2).to eq('MATCH (s:`Start`)-->()-[x]->(e:`End`) RETURN *')
    end

    it 'unbounded should return new' do
      chain2 = chain1.unbounded
      expect(chain2).not_to be(chain1)

      cypher1 = Cypher.match(chain1).returning(Cypher.asterisk).build.cypher
      expect(cypher1).to eq('MATCH (s:`Start`)-->()-->(e:`End`) RETURN *')

      cypher2 = Cypher.match(chain2).returning(Cypher.asterisk).build.cypher
      expect(cypher2).to eq('MATCH (s:`Start`)-->()-[*]->(e:`End`) RETURN *')
    end
  end
end
