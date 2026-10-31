# frozen_string_literal: true

# Translated from LoadCSVIT.java.
#
# Adapted: URIs are plain strings; `NullLiteral.INSTANCE` is `Cypher.literal_null`.
module CypherDSL
  RSpec.describe 'LoadCSVIT' do
    let(:l) { SymbolicName.of(:line) }
    let(:artist) do
      Cypher.node('Artist').with_properties('name', Cypher.value_at(l, 1), 'year', Cypher.to_integer(Cypher.value_at(l, 2)))
    end
    let(:row) { SymbolicName.of(:row) }
    let(:id) { row.property(:Id) }
    let(:email) { row.property(:Email) }

    it 'load and create should work' do
      statement = Cypher.load_csv('file:///artists.csv').as(l).create(artist).build

      expect(statement.cypher).to eq("LOAD CSV FROM 'file:///artists.csv' AS line CREATE (:`Artist` {name: line[1], year: toInteger(line[2])})")
    end

    it 'load and create with headers should work' do
      statement = Cypher.load_csv('file:///artists.csv', true).as(l).create(artist).build

      expect(statement.cypher).to eq("LOAD CSV WITH HEADERS FROM 'file:///artists.csv' AS line CREATE (:`Artist` {name: line[1], year: toInteger(line[2])})")
    end

    it 'load and create with field terminator should work' do
      statement = Cypher.load_csv('file:///artists.csv').as(l).with_field_terminator(';').create(artist).build

      expect(statement.cypher).to eq("LOAD CSV FROM 'file:///artists.csv' AS line FIELDTERMINATOR ';' CREATE (:`Artist` {name: line[1], year: toInteger(line[2])})")
    end

    it 'using period commit should work' do
      statement = Cypher.using_periodic_commit.load_csv('file:///artists.csv').as(l).create(artist).build

      expect(statement.cypher).to eq("USING PERIODIC COMMIT LOAD CSV FROM 'file:///artists.csv' AS line CREATE (:`Artist` {name: line[1], year: toInteger(line[2])})")
    end

    it 'using period commit with rate should work' do
      statement = Cypher.using_periodic_commit(500).load_csv('file:///artists.csv').as(l).create(artist).build

      expect(statement.cypher).to eq("USING PERIODIC COMMIT 500 LOAD CSV FROM 'file:///artists.csv' AS line CREATE (:`Artist` {name: line[1], year: toInteger(line[2])})")
    end

    it 'using linenumber should work' do
      statement = Cypher.load_csv('file:///artists.csv').as(l).returning(Cypher.linenumber.as(:number), l).build

      expect(statement.cypher).to eq("LOAD CSV FROM 'file:///artists.csv' AS line RETURN linenumber() AS number, line")
    end

    it 'using file should work' do
      statement = Cypher.load_csv('file:///artists.csv').as(l).returning(Cypher.file.as(:path)).build

      expect(statement.cypher).to eq("LOAD CSV FROM 'file:///artists.csv' AS line RETURN file() AS path")
    end

    it 'all options combined should work' do
      statement = Cypher.using_periodic_commit(42)
                        .load_csv('file:///artists.csv', true)
                        .as(l)
                        .with_field_terminator(';')
                        .create(Cypher.node('Artist').with_properties(
                                  'name', Cypher.value_at(l, 1), 'year', Cypher.to_integer(Cypher.value_at(l, 2)),
                                  'source', Cypher.file.concat(Cypher.literal_of('@')).concat(Cypher.linenumber)
                                ))
                        .build

      expect(statement.cypher).to eq(
        "USING PERIODIC COMMIT 42 LOAD CSV WITH HEADERS FROM 'file:///artists.csv' AS line FIELDTERMINATOR ';' " \
        "CREATE (:`Artist` {name: line[1], year: toInteger(line[2]), source: ((file() + '@') + linenumber())})"
      )
    end

    it 'dev guide example 1' do
      statement = Cypher.load_csv('file:///companies.csv', true)
                        .as(row)
                        .with(row)
                        .where(id.is_not_null)
                        .merge(Cypher.node('Company').named(:c).with_properties('companyId', id))
                        .build

      expect(statement.cypher).to eq("LOAD CSV WITH HEADERS FROM 'file:///companies.csv' AS row WITH row WHERE row.Id IS NOT NULL MERGE (c:`Company` {companyId: row.Id})")
    end

    it 'dev guide example 2' do
      statement = Cypher.load_csv('file:///companies.csv', true)
                        .as(row)
                        .merge(Cypher.node('Company').named(:c).with_properties('companyId', id, 'hqLocation', Cypher.coalesce(row.property(:Location), Cypher.literal_of('Unknown'))))
                        .build

      expect(statement.cypher).to eq(
        "LOAD CSV WITH HEADERS FROM 'file:///companies.csv' AS row MERGE (c:`Company` {companyId: row.Id, hqLocation: coalesce(row.Location, 'Unknown')})"
      )
    end

    it 'dev guide example 3' do
      node = Cypher.node('Company').named(:c).with_properties('companyId', id)

      statement = Cypher.load_csv('file:///companies.csv', true)
                        .as(row)
                        .merge(node)
                        .set(node.property(:emailAddress)
                                 .to(Cypher.case_expression(Cypher.trim(email))
                                           .when(Cypher.literal_of(''))
                                           .then(Cypher.literal_null)
                                           .else_default(email)))
                        .build

      expect(statement.cypher).to eq(
        "LOAD CSV WITH HEADERS FROM 'file:///companies.csv' AS row MERGE (c:`Company` {companyId: row.Id}) " \
        "SET c.emailAddress = CASE trim(row.Email) WHEN '' THEN NULL ELSE row.Email END"
      )
    end

    it 'dev guide example 4' do
      skill = Cypher.name(:skill)

      e = Cypher.node('Employee').named(:e).with_properties('employeeId', id, 'email', email)
      s = Cypher.node('Skill').named(:s).with_properties('name', skill)

      statement = Cypher.load_csv('file:///employees.csv', true)
                        .as(row)
                        .merge(e)
                        .with(e, row)
                        .unwind(Cypher.split(row.property(:Skills), Cypher.literal_of(':')))
                        .as(skill)
                        .merge(s)
                        .merge(e.relationship_to(s, 'HAS_EXPERIENCE').named(:r))
                        .build

      expect(statement.cypher).to eq(
        "LOAD CSV WITH HEADERS FROM 'file:///employees.csv' AS row MERGE (e:`Employee` {employeeId: row.Id, email: row.Email}) WITH e, row " \
        "UNWIND split(row.Skills, ':') AS skill MERGE (s:`Skill` {name: skill}) MERGE (e)-[r:`HAS_EXPERIENCE`]->(s)"
      )
    end

    it 'in query' do
      user_node = Cypher.node('User').named(:u).with_properties('name', Cypher.literal_of('Michael'))

      statement = Cypher.match(user_node)
                        .with(user_node)
                        .order_by(user_node.property(:name))
                        .ascending
                        .load_csv('file:///bikes.csv')
                        .as(row)
                        .merge(user_node.relationship_to(Cypher.node('Bike').with_properties('name', Cypher.value_at(row, 0)), 'OWNS'))
                        .build

      expect(statement.cypher).to eq(
        "MATCH (u:`User` {name: 'Michael'}) WITH u ORDER BY u.name ASC LOAD CSV FROM 'file:///bikes.csv' AS row MERGE (u)-[:`OWNS`]->(:`Bike` {name: row[0]})"
      )
    end

    it 'finish' do
      user_node = Cypher.node('User').named(:u).with_properties('name', Cypher.literal_of('Michael'))

      statement = Cypher.match(user_node)
                        .with(user_node)
                        .order_by(user_node.property(:name))
                        .ascending
                        .load_csv('file:///bikes.csv')
                        .as(row)
                        .finish
                        .build

      expect(statement.cypher).to eq("MATCH (u:`User` {name: 'Michael'}) WITH u ORDER BY u.name ASC LOAD CSV FROM 'file:///bikes.csv' AS row FINISH")
    end
  end
end
