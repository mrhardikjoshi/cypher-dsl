# frozen_string_literal: true

# Translated from FunctionsIT.java.
#
# Adapted: the Java test drives the mathematical functions by reflection over the
# `MathematicalFunctions` enum; here the enum is spelled out as a table. `TimeZone` arguments
# become the `timezone:` keyword.
module CypherDSL
  RSpec.describe 'FunctionsIT' do
    let(:cypher_renderer) { Renderer.get_renderer(Renderer::Configuration.new_config.with_dialect(Renderer::Dialect::NEO4J_4).build) }

    let(:n) { Cypher.node('Node').named(:n) }
    let(:m) { Cypher.node('Node2').named(:m) }
    let(:r) { n.relationship_to(m).named(:r) }
    let(:e1) { Cypher.name(:e1) }
    let(:e2) { Cypher.name(:e2) }
    let(:p1) { Cypher.point(Cypher.map_of('latitude', Cypher.literal_of(1), 'longitude', Cypher.literal_of(2))) }
    let(:p2) { Cypher.point(Cypher.map_of('latitude', Cypher.literal_of(3), 'longitude', Cypher.literal_of(4))) }

    it 'properties invocation should be reusable' do
      source = Cypher.node('Movie', Cypher.map_of('title', Cypher.literal_of('The Matrix'))).named(:src)
      p = Cypher.properties(source)
      copy = Cypher.node('MovieCopy').named(:copy)

      query = cypher_renderer.render(Cypher.match(source).create(copy).set(copy, p).returning(copy).build)
      expect(query).to eq("MATCH (src:`Movie` {title: 'The Matrix'}) CREATE (copy:`MovieCopy`) SET copy = properties(src) RETURN copy")
    end

    describe 'math functions should be rendered as expected' do
      fixed_arity = {
        abs: 1, ceil: 1, floor: 1, rand: 0, sign: 1, e: 0, exp: 1, log: 1, log10: 1, sqrt: 1, acos: 1, asin: 1,
        atan: 1, atan2: 2, cos: 1, cot: 1, degrees: 1, haversin: 1, pi: 0, radians: 1, sin: 1, tan: 1
      }

      fixed_arity.each do |function, arity|
        it function.to_s do
          arguments = Array.new(arity) { |i| Cypher.literal_of(i) }
          f = Cypher.public_send(function, *arguments)
          expect("#{cypher_renderer.render(Cypher.returning(f).build)};").to eq("RETURN #{function}(#{(0...arity).to_a.join(', ')});")
        end
      end

      (0..2).each do |extra|
        it "round with #{extra} additional arguments" do
          arguments = Array.new(extra) { |i| Cypher.literal_of(i) }
          f = Cypher.round(Cypher.literal_of(1), *arguments)
          expect("#{cypher_renderer.render(Cypher.returning(f).build)};").to eq("RETURN round(#{[1, *0...extra].join(', ')});")
        end
      end

      it 'rejects more than three arguments for round' do
        expect { Cypher.round(1, 2, 3, 4) }.to raise_error(ArgumentError)
      end
    end

    describe 'function should be rendered as expected' do
      # NOTE: Not all of those return valid Cypher statements. They are used only for
      # integration testing the function calls so far.
      functions_to_test = [
        ['RETURN left(NULL, NULL)', -> { Cypher.left(nil, nil) }],
        ["RETURN left('hello', 3)", -> { Cypher.left(Cypher.literal_of('hello'), Cypher.literal_of(3)) }],
        ["RETURN ltrim('   hello')", -> { Cypher.ltrim(Cypher.literal_of('   hello')) }],
        ["RETURN replace('hello', 'l', 'w')", -> { Cypher.replace(Cypher.literal_of('hello'), Cypher.literal_of('l'), Cypher.literal_of('w')) }],
        ["RETURN reverse('hello')", -> { Cypher.reverse(Cypher.literal_of('hello')) }],
        ['RETURN right(NULL, NULL)', -> { Cypher.right(nil, nil) }],
        ["RETURN right('hello', 3)", -> { Cypher.right(Cypher.literal_of('hello'), Cypher.literal_of(3)) }],
        ["RETURN rtrim('   hello  ')", -> { Cypher.rtrim(Cypher.literal_of('   hello  ')) }],
        ["RETURN substring('hello', 1, 3)", -> { Cypher.substring(Cypher.literal_of('hello'), Cypher.literal_of(1), Cypher.literal_of(3)) }],
        ["RETURN substring('hello', 2)", -> { Cypher.substring(Cypher.literal_of('hello'), Cypher.literal_of(2), nil) }],
        ["RETURN toStringOrNull('hello')", -> { Cypher.to_string_or_null(Cypher.literal_of('hello')) }],
        ['RETURN id(r)', -> { Cypher.id(r) }],
        ['RETURN toString(id(n))', -> { Cypher.element_id(n) }],
        ['RETURN toString(id(r))', -> { Cypher.element_id(r) }],
        ['RETURN keys(n)', -> { Cypher.keys(n) }],
        ['RETURN keys(r)', -> { Cypher.keys(r) }],
        ['RETURN keys(e1)', -> { Cypher.keys(e1) }],
        ['RETURN labels(n)', -> { Cypher.labels(n) }],
        ['RETURN type(r)', -> { Cypher.type(r) }],
        ['RETURN count(n)', -> { Cypher.count(n) }],
        ['RETURN count(DISTINCT n)', -> { Cypher.count_distinct(n) }],
        ['RETURN count(e1)', -> { Cypher.count(e1) }],
        ['RETURN count(DISTINCT e1)', -> { Cypher.count_distinct(e1) }],
        ['RETURN coalesce(e1, e2)', -> { Cypher.coalesce(e1, e2) }],
        ['RETURN toLower(e1)', -> { Cypher.to_lower(e1) }],
        ['RETURN toUpper(e1)', -> { Cypher.to_upper(e1) }],
        ['RETURN trim(e1)', -> { Cypher.trim(e1) }],
        ["RETURN split(e1, ',')", -> { Cypher.split(e1, Cypher.literal_of(',')) }],
        ['RETURN size(e1)', -> { Cypher.size(e1) }],
        ['RETURN size((:`Node`)-[]->(:`Node2`))', -> { Cypher.size(r) }],
        ['RETURN exists(e1)', -> { Cypher.exists(e1) }],
        ['RETURN distance(point({latitude: 1, longitude: 2}), point({latitude: 3, longitude: 4}))', -> { Cypher.distance(p1, p2) }],
        ['RETURN avg(e1)', -> { Cypher.avg(e1) }],
        ['RETURN avg(DISTINCT e1)', -> { Cypher.avg_distinct(e1) }],
        ['RETURN collect(e1)', -> { Cypher.collect(e1) }],
        ['RETURN collect(DISTINCT e1)', -> { Cypher.collect_distinct(e1) }],
        ['RETURN collect(n)', -> { Cypher.collect(n) }],
        ['RETURN collect(DISTINCT n)', -> { Cypher.collect_distinct(n) }],
        ['RETURN max(e1)', -> { Cypher.max(e1) }],
        ['RETURN max(DISTINCT e1)', -> { Cypher.max_distinct(e1) }],
        ['RETURN min(e1)', -> { Cypher.min(e1) }],
        ['RETURN min(DISTINCT e1)', -> { Cypher.min_distinct(e1) }],
        ['RETURN percentileCont(e1, 0.4)', -> { Cypher.percentile_cont(e1, 0.4) }],
        ['RETURN percentileCont(DISTINCT e1, 0.4)', -> { Cypher.percentile_cont_distinct(e1, 0.4) }],
        ['RETURN percentileDisc(e1, 0.4)', -> { Cypher.percentile_disc(e1, 0.4) }],
        ['RETURN percentileDisc(DISTINCT e1, 0.4)', -> { Cypher.percentile_disc_distinct(e1, 0.4) }],
        ['RETURN stDev(e1)', -> { Cypher.st_dev(e1) }],
        ['RETURN stDev(DISTINCT e1)', -> { Cypher.st_dev_distinct(e1) }],
        ['RETURN stDevP(e1)', -> { Cypher.st_dev_p(e1) }],
        ['RETURN stDevP(DISTINCT e1)', -> { Cypher.st_dev_p_distinct(e1) }],
        ['RETURN sum(e1)', -> { Cypher.sum(e1) }],
        ['RETURN sum(DISTINCT e1)', -> { Cypher.sum_distinct(e1) }],
        ['RETURN range(1, 3)', -> { Cypher.range(Cypher.literal_of(1), Cypher.literal_of(3)) }],
        ['RETURN range(1, 3, 2)', -> { Cypher.range(Cypher.literal_of(1), Cypher.literal_of(3), Cypher.literal_of(2)) }],
        ['RETURN head(e1)', -> { Cypher.head(e1) }],
        ['RETURN last(e1)', -> { Cypher.last(e1) }],
        ['RETURN nodes(p)', -> { Cypher.nodes(Cypher.path(:p).defined_by(r)) }],
        ['RETURN length(p)', -> { Cypher.length(Cypher.path(:p).defined_by(r)) }],
        ['RETURN properties(n)', -> { Cypher.properties(n) }],
        ['RETURN properties(r)', -> { Cypher.properties(r) }],
        ["RETURN properties({a: 'b'})", -> { Cypher.properties(Cypher.map_of('a', Cypher.literal_of('b'))) }],
        ['RETURN relationships(p)', -> { Cypher.relationships(Cypher.path(:p).defined_by(r)) }],
        ['RETURN startNode(r)', -> { Cypher.start_node(r) }],
        ['RETURN endNode(r)', -> { Cypher.end_node(r) }],
        ['RETURN date()', -> { Cypher.date }],
        ['RETURN date({year: 2020, month: 9, day: 21})', -> { Cypher.calendar_date(2020, 9, 21) }],
        ['RETURN date({year: 1984, week: 10, dayOfWeek: 3})', -> { Cypher.week_date(1984, 10, 3) }],
        ['RETURN date({year: 1984, week: 10})', -> { Cypher.week_date(1984, 10, nil) }],
        ['RETURN date({year: 1984})', -> { Cypher.week_date(1984, nil, nil) }],
        ['RETURN date({year: 1984, quarter: 10, dayOfQuarter: 45})', -> { Cypher.quarter_date(1984, 10, 45) }],
        ['RETURN date({year: 1984, quarter: 10})', -> { Cypher.quarter_date(1984, 10, nil) }],
        ['RETURN date({year: 1984})', -> { Cypher.quarter_date(1984, nil, nil) }],
        ['RETURN date({year: 1984, ordinalDay: 202})', -> { Cypher.ordinal_date(1984, 202) }],
        ['RETURN date({year: 1984})', -> { Cypher.ordinal_date(1984, nil) }],
        ['RETURN date({year: 2020})', -> { Cypher.date(Cypher.map_of('year', Cypher.literal_of(2020))) }],
        ["RETURN date('2020-09-15')", -> { Cypher.date('2020-09-15') }],
        ['RETURN date($myDateParameter)', -> { Cypher.date(Cypher.parameter('$myDateParameter')) }],
        ['RETURN datetime()', -> { Cypher.datetime }],
        ["RETURN datetime({year: 1984, month: 10, day: 11, hour: 12, minute: 31, timezone: 'Europe/Stockholm'})",
         lambda {
           Cypher.datetime(Cypher.map_of('year', Cypher.literal_of(1984), 'month', Cypher.literal_of(10), 'day', Cypher.literal_of(11),
                                         'hour', Cypher.literal_of(12), 'minute', Cypher.literal_of(31), 'timezone', Cypher.literal_of('Europe/Stockholm')))
         }],
        ["RETURN datetime('2015-07-21T21:40:32.142+0100')", -> { Cypher.datetime('2015-07-21T21:40:32.142+0100') }],
        ['RETURN datetime($myDateParameter)', -> { Cypher.datetime(Cypher.parameter('$myDateParameter')) }],
        ["RETURN datetime({timezone: 'America/Los_Angeles'})", -> { Cypher.datetime(timezone: 'America/Los_Angeles') }],
        ['RETURN localdatetime()', -> { Cypher.localdatetime }],
        ['RETURN localdatetime({year: 1984, month: 10, day: 11, hour: 12, minute: 31, second: 14, millisecond: 123, microsecond: 456, nanosecond: 789})',
         lambda {
           Cypher.localdatetime(Cypher.map_of('year', Cypher.literal_of(1984), 'month', Cypher.literal_of(10), 'day', Cypher.literal_of(11),
                                              'hour', Cypher.literal_of(12), 'minute', Cypher.literal_of(31), 'second', Cypher.literal_of(14),
                                              'millisecond', Cypher.literal_of(123), 'microsecond', Cypher.literal_of(456), 'nanosecond', Cypher.literal_of(789)))
         }],
        ["RETURN localdatetime('2015-07-21T21:40:32.142')", -> { Cypher.localdatetime('2015-07-21T21:40:32.142') }],
        ['RETURN localdatetime($myDateParameter)', -> { Cypher.localdatetime(Cypher.parameter('$myDateParameter')) }],
        ["RETURN localdatetime({timezone: 'America/Los_Angeles'})", -> { Cypher.localdatetime(timezone: 'America/Los_Angeles') }],
        ['RETURN localtime()', -> { Cypher.localtime }],
        ['RETURN localtime({hour: 12, minute: 31, second: 14, millisecond: 123, microsecond: 456, nanosecond: 789})',
         lambda {
           Cypher.localtime(Cypher.map_of('hour', Cypher.literal_of(12), 'minute', Cypher.literal_of(31), 'second', Cypher.literal_of(14),
                                          'millisecond', Cypher.literal_of(123), 'microsecond', Cypher.literal_of(456), 'nanosecond', Cypher.literal_of(789)))
         }],
        ["RETURN localtime('21:40:32.142')", -> { Cypher.localtime('21:40:32.142') }],
        ['RETURN localtime($myDateParameter)', -> { Cypher.localtime(Cypher.parameter('$myDateParameter')) }],
        ["RETURN localtime({timezone: 'America/Los_Angeles'})", -> { Cypher.localtime(timezone: 'America/Los_Angeles') }],
        ['RETURN time()', -> { Cypher.time }],
        ['RETURN time({hour: 12, minute: 31, second: 14, millisecond: 123, microsecond: 456, nanosecond: 789})',
         lambda {
           Cypher.time(Cypher.map_of('hour', Cypher.literal_of(12), 'minute', Cypher.literal_of(31), 'second', Cypher.literal_of(14),
                                     'millisecond', Cypher.literal_of(123), 'microsecond', Cypher.literal_of(456), 'nanosecond', Cypher.literal_of(789)))
         }],
        ["RETURN time('21:40:32.142')", -> { Cypher.time('21:40:32.142') }],
        ['RETURN time($myDateParameter)', -> { Cypher.time(Cypher.parameter('$myDateParameter')) }],
        ["RETURN time({timezone: 'America/Los_Angeles'})", -> { Cypher.time(timezone: 'America/Los_Angeles') }],
        ['RETURN duration({days: 14, hours: 16, minutes: 12})',
         -> { Cypher.duration(Cypher.map_of('days', Cypher.literal_of(14), 'hours', Cypher.literal_of(16), 'minutes', Cypher.literal_of(12))) }],
        ["RETURN duration('P14DT16H12M')", -> { Cypher.duration('P14DT16H12M') }],
        ['RETURN duration($myDateParameter)', -> { Cypher.duration(Cypher.parameter('$myDateParameter')) }],
        ["RETURN toInteger('23')", -> { Cypher.to_integer(Cypher.literal_of('23')) }],
        ['RETURN toString(23)', -> { Cypher.to_string(Cypher.literal_of(23)) }],
        ["RETURN toFloat('23.42')", -> { Cypher.to_float(Cypher.literal_of('23.42')) }],
        ["RETURN toBoolean('false')", -> { Cypher.to_boolean(Cypher.literal_of('false')) }],
        ['RETURN randomUUID()', -> { Cypher.random_uuid }],
        ['RETURN point({x: 2.3, y: 4.5})', -> { Cypher.cartesian(2.3, 4.5) }],
        ['RETURN point({longitude: 56.7, latitude: 12.78})', -> { Cypher.coordinate(56.7, 12.78) }]
      ]

      functions_to_test.each_with_index do |(expected, function_invocation), index|
        it "#{index}: #{expected}" do
          expect(cypher_renderer.render(Cypher.returning(instance_exec(&function_invocation)).build)).to eq(expected)
        end
      end
    end

    describe 'neo5j specific functions should work' do
      let(:renderer) { Renderer.get_renderer(Renderer::Configuration.new_config.with_dialect(Renderer::Dialect::NEO4J_5).build) }

      it 'elementId(n)' do
        expect(renderer.render(Cypher.returning(Cypher.element_id(n)).build)).to eq('RETURN elementId(n)')
      end

      it 'elementId(r)' do
        expect(renderer.render(Cypher.returning(Cypher.element_id(r)).build)).to eq('RETURN elementId(r)')
      end
    end

    it 'assorted errors' do
      literal_expression = Cypher.literal_of('something')
      expect { Cypher.left(literal_expression, nil) }
        .to raise_error(ArgumentError, 'length might not be null when the expression is not null')
      expect { Cypher.right(literal_expression, nil) }
        .to raise_error(ArgumentError, 'length might not be null when the expression is not null')
      expect { Cypher.substring(literal_expression, nil, nil) }.to raise_error(ArgumentError, 'start is required')
    end

    it 'is empty should work' do # GH-777
      p = Cypher.node('Person').named(:p)
      stmt = Cypher.match(p)
                   .where(Cypher.not(Cypher.is_empty(p.property(:nationality))))
                   .returning(p.property(:name), p.property(:nationality))
                   .build
                   .cypher

      expect(stmt).to eq('MATCH (p:`Person`) WHERE NOT (isEmpty(p.nationality)) RETURN p.name, p.nationality')
    end

    describe 'Reduction' do
      it 'reduction of paths' do
        r = Cypher.node('Node').named(:n).relationship_to(Cypher.node('Node2').named(:m)).named(:r)
        named_path = Cypher.path(:patternPath).defined_by(r)

        x = Cypher.name(:x)
        empty_list = Cypher.list_of
        list_to_reduce = Cypher.relationships(named_path)
        n = Cypher.name(:n)
        statement = Cypher.returning(Cypher.reduce(n).in(list_to_reduce).map(x.add(n)).accumulate_on(x).with_initial_value_of(empty_list)).build

        expect(cypher_renderer.render(statement)).to eq('RETURN reduce(x = [], n IN relationships(patternPath) | (x + n))')
      end

      it 'manual' do
        a = Cypher.any_node.named(:a)
        b = Cypher.any_node.named(:b)
        c = Cypher.any_node.named(:c)
        p = Cypher.path(:p).defined_by(a.relationship_to(b).relationship_to(c))
        n = Cypher.name(:n)
        total_age = Cypher.name(:totalAge)
        statement = Cypher.match(p)
                          .where(a.property(:name).is_equal_to(Cypher.literal_of('Alice')))
                          .and(b.property(:name).is_equal_to(Cypher.literal_of('Bob')))
                          .and(c.property(:name).is_equal_to(Cypher.literal_of('Daniel')))
                          .returning(Cypher.reduce(n)
                                           .in(Cypher.nodes(p))
                                           .map(total_age.add(Cypher.property(n, 'age')))
                                           .accumulate_on(total_age)
                                           .with_initial_value_of(Cypher.literal_of(0))
                                           .as(:reduction))
                          .build
        expect(cypher_renderer.render(statement)).to eq(
          "MATCH p = (a)-->(b)-->(c) WHERE (a.name = 'Alice' AND b.name = 'Bob' AND c.name = 'Daniel') RETURN reduce(totalAge = 0, n IN nodes(p) | (totalAge + n.age)) AS reduction"
        )
      end

      it 'of list comprehension' do
        n = Cypher.name(:n)
        total_age = Cypher.name(:totalAge)
        x = Cypher.name(:x)
        statement = Cypher.returning(Cypher.reduce(n)
                                           .in(Cypher.list_with(x)
                                                     .in(Cypher.range(0, 10))
                                                     .where(x.remainder(Cypher.literal_of(2)).is_equal_to(Cypher.literal_of(0)))
                                                     .returning(x.pow(Cypher.literal_of(3))))
                                           .map(total_age.add(n))
                                           .accumulate_on(total_age)
                                           .with_initial_value_of(Cypher.literal_of(0.0))
                                           .as(:result))
                          .build

        expect(cypher_renderer.render(statement)).to eq(
          'RETURN reduce(totalAge = 0.0, n IN [x IN range(0, 10) WHERE (x % 2) = 0 | x^3] | (totalAge + n)) AS result'
        )
      end
    end

    describe 'Graphs' do # GH-728
      it 'names should work' do
        expect(Cypher.returning(Cypher.graph_names.as(:name)).build.cypher).to eq('RETURN graph.names() AS name')
      end

      it 'properties by name should work' do
        name = Cypher.name(:name)
        stmnt = Cypher.unwind(Cypher.graph_names)
                      .as(name)
                      .returning(name, Cypher.graph_properties_by_name(name).as(:props))
                      .build
        expect(stmnt.cypher).to eq('UNWIND graph.names() AS name RETURN name, graph.propertiesByName(name) AS props')
      end

      it 'by name should work' do
        name = Cypher.name(:graphName)
        stmnt = Cypher.unwind(Cypher.graph_names)
                      .as(name)
                      .call(Cypher.use(Cypher.graph_by_name(name), Cypher.match(Cypher.any_node(:n)).returning(Cypher.name(:n)).build))
                      .returning(Cypher.name(:n))
                      .build
        expect(stmnt.cypher).to eq('UNWIND graph.names() AS graphName CALL (*) {USE graph.byName(graphName) MATCH (n) RETURN n} RETURN n')
      end
    end
  end
end
