# frozen_string_literal: true

# Translated from ProcedureCallsIT.java.
#
# Adapted: assertions on `getCatalog().getIdentifiableExpressions()` are left out; the
# statement catalog is not implemented.
module CypherDSL
  RSpec.describe 'ProcedureCallsIT' do
    let(:renderer) { Renderer.default }

    it 'simple' do
      expected = 'CALL db.labels()'

      call = Cypher.call('db', 'labels').build
      expect(renderer.render(call)).to eq(expected)

      call = Cypher.call('db.labels').build
      expect(renderer.render(call)).to eq(expected)
    end

    it 'simple based on string collection' do
      call = Cypher.call(%w[db labels]).build
      expect(renderer.render(call)).to eq('CALL db.labels()')
    end

    it 'procedure names must be escaped' do
      expected = 'CALL `this is a`.`very odd`.`procedure!`()'
      expect(Cypher.call('this is a', 'very odd', 'procedure!').build.cypher).to eq(expected)
      expect(Cypher.call('this is a.very odd.procedure!').build.cypher).to eq(expected)
    end

    it 'generates statements of correct type' do
      call = Cypher.call('db', 'labels').build
      expect(call).to be_procedure_call
      expect(call).not_to be_result_statement

      call = Cypher.call('db', 'labels').yield('label').build
      expect(call).to be_procedure_call.and be_result_statement

      call = Cypher.call('db', 'labels').yield('label').returning('label').build
      expect(call).to be_single_query.and be_result_statement
    end

    it 'with args' do
      call = Cypher.call('dbms.security.createUser')
                   .with_args(Cypher.literal_of('johnsmith'), Cypher.literal_of('h6u4%kr'), Cypher.literal_false)
                   .build
      expect(renderer.render(call)).to eq("CALL dbms.security.createUser('johnsmith', 'h6u4%kr', false)")
    end

    it 'yield items' do
      expected = 'CALL dbms.procedures() YIELD name, signature'

      call = Cypher.call('dbms.procedures').yield('name', 'signature').build
      expect(renderer.render(call)).to eq(expected)

      call = Cypher.call('dbms.procedures').yield(Cypher.name(:name), Cypher.name(:signature)).build
      expect(renderer.render(call)).to eq(expected)
    end

    it 'yield items renamed' do
      call = Cypher.call('db.propertyKeys').yield(Cypher.name(:propertyKey).as(:prop)).build
      expect(renderer.render(call)).to eq('CALL db.propertyKeys() YIELD propertyKey AS prop')
    end

    it 'with args and yield' do
      call = Cypher.call('dbms.listConfig').with_args(Cypher.literal_of('browser')).yield('name').build
      expect(renderer.render(call)).to eq("CALL dbms.listConfig('browser') YIELD name")
    end

    it 'where' do
      name = Cypher.name(:name)
      call = Cypher.call('dbms.listConfig')
                   .with_args(Cypher.literal_of('browser'))
                   .yield(name)
                   .where(name.matches('browser\\.allow.*'))
                   .returning(Cypher.asterisk)
                   .build
      expect(renderer.render(call))
        .to eq("CALL dbms.listConfig('browser') YIELD name WHERE name =~ 'browser\\\\.allow.*' RETURN *")
    end

    it 'returning' do
      label = Cypher.name(:label)
      call = Cypher.call('db.labels').yield(label).returning(Cypher.count(label).as(:numLabels)).build
      expect(renderer.render(call)).to eq('CALL db.labels() YIELD label RETURN count(label) AS numLabels')
    end

    it 'with than returning' do
      label = Cypher.name(:label)
      call = Cypher.call('db.labels')
                   .yield(label)
                   .with(label)
                   .returning(Cypher.count(label).as(:numLabels))
                   .build
      expect(renderer.render(call)).to eq('CALL db.labels() YIELD label WITH label RETURN count(label) AS numLabels')
    end

    it 'with than returning in query' do
      label = Cypher.name(:label)
      call = Cypher.match(Cypher.any_node.named(:n))
                   .with('n')
                   .call('db.labels')
                   .yield(label)
                   .with(label)
                   .returning(Cypher.count(label).as(:numLabels))
                   .build
      expect(renderer.render(call))
        .to eq('MATCH (n) WITH n CALL db.labels() YIELD label WITH label RETURN count(label) AS numLabels')
    end

    it 'is usable as expression' do # GH-101
      p = Cypher.node('Person').named(:p)
      stmt = Cypher
             .merge(p.with_properties(Cypher.map_of('id', Cypher.call('apoc.create.uuid').as_function)))
             .set(p.property(:firstName).to(Cypher.literal_of('Michael')), p.property(:surname).to(Cypher.literal_of('Hunger')))
             .returning(p)
             .build
      expect(renderer.render(stmt)).to eq(
        "MERGE (p:`Person` {id: apoc.create.uuid()}) SET p.firstName = 'Michael', p.surname = 'Hunger' RETURN p"
      )
    end

    it 'dynamic distinct' do
      statement = Cypher.returning(Cypher.call('aVg').with_args(Cypher.literal_of(1)).as_function(true)).build
      expect(renderer.render(statement)).to eq('RETURN aVg(DISTINCT 1)')
    end

    it 'dynamic distinct unsupported' do
      expect { Cypher.call('foobar').with_args(Cypher.literal_of(1)).as_function(true) }
        .to raise_error(ArgumentError, 'The distinct operator can only be applied within aggregate functions.')
    end

    it 'is usable with parameters as expression' do # GH-101
      p = Cypher.node('Person').named(:p)
      stmt = Cypher
             .merge(p.with_properties(Cypher.map_of('id', Cypher.call('apoc.create.uuid').as_function)))
             .set(p.property(:surname).to(Cypher.literal_of('Simons')))
             .with(p)
             .call('apoc.create.setProperty')
             .with_args(p.required_symbolic_name,
                        Cypher.call('apoc.text.camelCase').with_args(Cypher.literal_of('first name')).as_function,
                        Cypher.literal_of('Michael'))
             .yield('node')
             .returning('node')
             .build
      expect(renderer.render(stmt)).to eq(
        "MERGE (p:`Person` {id: apoc.create.uuid()}) SET p.surname = 'Simons' WITH p CALL apoc.create.setProperty(p, apoc.text.camelCase('first name'), 'Michael') YIELD node RETURN node"
      )
    end

    describe 'MultipartQueries' do
      it 'unrelated' do
        name = Cypher.name(:name)
        call = Cypher.call('dbms.listConfig')
                     .with_args(Cypher.literal_of('browser'))
                     .yield(name)
                     .where(name.matches('browser\\.allow.*'))
                     .match(Cypher.any_node(:n))
                     .with(name)
                     .returning(Cypher.asterisk)
                     .build
        expect(renderer.render(call)).to eq(
          "CALL dbms.listConfig('browser') YIELD name WHERE name =~ 'browser\\\\.allow.*' MATCH (n) WITH name RETURN *"
        )
      end

      it 'related' do
        name = Cypher.name(:name)
        description = Cypher.name(:description)
        call = Cypher.call('dbms.listConfig')
                     .with_args(Cypher.literal_of('browser'))
                     .yield(name, description)
                     .where(name.matches('browser\\.allow.*'))
                     .with(Cypher.asterisk)
                     .create(Cypher.node('Config').with_properties('name', name, 'description', description).named(:n))
                     .returning(Cypher.name(:n))
                     .build
        expect(renderer.render(call)).to eq(
          "CALL dbms.listConfig('browser') YIELD name, description WHERE name =~ 'browser\\\\.allow.*' WITH * CREATE (n:`Config` {name: name, description: description}) RETURN n"
        )
      end

      it 'related inner' do
        name = Cypher.name(:name)
        parameters = Cypher.list_of(Cypher.literal_of('browser'), Cypher.literal_of('causal_clustering')).as(:parameters)
        call = Cypher.with(parameters)
                     .unwind(parameters)
                     .as(:p)
                     .call('dbms.listConfig')
                     .with_args(Cypher.name(:p))
                     .yield(name)
                     .where(name.matches('.*allow.*'))
                     .returning(name)
                     .build

        expect(renderer.render(call)).to eq(
          "WITH ['browser', 'causal_clustering'] AS parameters UNWIND parameters AS p CALL dbms.listConfig(p) YIELD name WHERE name =~ '.*allow.*' RETURN name"
        )
      end
    end
  end
end
