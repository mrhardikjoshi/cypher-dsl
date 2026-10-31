# frozen_string_literal: true

module CypherDSL
  # The main entry point of the DSL. Mirrors the static factory methods of the
  # Java `org.neo4j.cypherdsl.core.Cypher` class in snake_case.
  module Cypher
    module_function

    # --- pattern elements ------------------------------------------------

    # A node with one primary label and optional additional labels; a trailing
    # map (`Cypher.node('Test', Cypher.map_of(…))`) sets its properties.
    def node(primary_label, *additional_labels)
      properties = additional_labels.pop if [MapExpression, Hash].any? { |type| additional_labels.last.is_a?(type) }
      node = Node.new(labels: [primary_label, *additional_labels].map(&:to_s))
      properties ? node.with_properties(properties) : node
    end

    # A node without labels, optionally named.
    def any_node(name = nil)
      node = Node.new(labels: [])
      name ? node.named(name) : node
    end

    # --- names, properties, parameters -----------------------------------

    def name(value) = SymbolicName.of(value)

    # `Cypher.property(:n, :name)` → `n.name`; the container may also be an expression,
    # and a name may be an expression for a dynamic lookup (`n[$prop]`).
    def property(container, *names)
      container = SymbolicName.of(container) unless container.is_a?(Expression)
      Property.new(container, names)
    end

    # `$name`, optionally with its value; see {Parameter}.
    def parameter(name, value = Parameter::NO_VALUE) = Parameter.new(name, value)

    # A parameter named by the renderer (`$pcdsl01`, …), carrying its value.
    def anon_parameter(value) = Parameter.anonymous(value)

    # --- literals --------------------------------------------------------

    # Wraps a Ruby value as a literal; expressions pass through unchanged.
    def literal_of(value) = Literal.of(value)

    def literal_true = Literal::TRUE
    def literal_false = Literal::FALSE
    def literal_null = Literal::NULL

    def map_of(*keys_and_values) = MapExpression.of(*keys_and_values)
    def list_of(*expressions) = ListExpression.of(*expressions)

    def asterisk = Asterisk::INSTANCE

    # --- conditions ------------------------------------------------------

    def is_true = ConstantCondition::TRUE
    def is_false = ConstantCondition::FALSE
    def no_condition = NoCondition::INSTANCE
    def not(condition_or_pattern) = Condition.coerce(condition_or_pattern).not
    def includes_all(list_expression, list) = Expression.coerce(list_expression).includes_all(list)
    def includes_any(list_expression, list) = Expression.coerce(list_expression).includes_any(list)

    # `[pattern WHERE … | …]`; continue with `where` and `returning`.
    def list_based_on(pattern) = PatternComprehension.new(pattern)

    # `[variable IN list WHERE … | …]`; continue with `in`, `where` and `returning`.
    def list_with(variable) = ListComprehension.new(variable)

    # `Cypher.path(:p).defined_by(pattern)` for `MATCH p = pattern`; `.get` for the bare name.
    def path(name) = NamedPath::Ongoing.new(SymbolicName.of(name))

    # Path selectors, `Cypher.any_shortest.named(:p).defined_by(pattern)` → `p = ANY pattern`.
    def any_shortest = NamedPath::Selector.new('ANY')
    def all_shortest = NamedPath::Selector.new('ALL SHORTEST')
    def shortest_k(count) = NamedPath::Selector.shortest_k(count)
    def shortest_k_groups(count) = NamedPath::Selector.shortest_k(count, groups: true)

    # `EXISTS { pattern }` / `EXISTS { [WITH imports] statement }`.
    def exists(pattern_or_statement, *imports)
      ExistsCondition.new(pattern_or_statement, imports.flatten.map { |import| Expression.coerce(import) })
    end

    # List predicates: `Cypher.all(:x).in(list).where(condition)`.
    def all(variable) = ListPredicate::Ongoing.new('all', variable)
    def any(variable) = ListPredicate::Ongoing.new('any', variable)
    def none(variable) = ListPredicate::Ongoing.new('none', variable)
    def single(variable) = ListPredicate::Ongoing.new('single', variable)

    def sub_list_until(list, end_index) = ListOperator.sublist(Expression.coerce(list), nil, end_index)
    def sub_list_from(list, start_index) = ListOperator.sublist(Expression.coerce(list), start_index, nil)
    def sub_list(list, start_index = nil, end_index = nil) = sublist(list, start_index, end_index)

    def range(start_value, end_value, step = nil) = function('range', *[start_value, end_value, step].compact)

    # --- operations ------------------------------------------------------

    def set(target, value) = Operation.new(target, '=', Expression.coerce(value))
    def set_label(node, *labels) = LabelOperation.new(node, labels)
    def mutate(target, expression) = Operation.new(target, '+=', Expression.coerce(expression))
    def minus(expression) = UnaryOperation.new('-', Expression.coerce(expression))
    def plus(expression) = UnaryOperation.new('+', Expression.coerce(expression))
    def value_at(list, index) = ListOperator.value_at(Expression.coerce(list), index)

    def sublist(list, start_index = nil, end_index = nil)
      ListOperator.sublist(Expression.coerce(list), start_index, end_index)
    end

    # `CASE … END`; `case_expression(subject)` for the simple form, no argument for the generic one.
    def case_expression(subject = nil) = CaseExpression.new(subject: subject && Expression.coerce(subject))

    # --- sorting and functions --------------------------------------------

    def point(expression) = FunctionInvocation.new('point', [Expression.coerce(expression)])
    def distance(point1, point2) = function('point.distance', point1, point2)

    # `collect(expression)`, or `COLLECT { statement }` when given a statement.
    def collect(expression_or_statement)
      return CollectExpression.new(expression_or_statement) if expression_or_statement.is_a?(Statement)

      function('collect', expression_or_statement)
    end

    def rand = function('rand')
    def to_integer(expression) = function('toInteger', expression)
    def to_float(expression) = function('toFloat', expression)
    def to_string(expression) = function('toString', expression)
    def to_boolean(expression) = function('toBoolean', expression)
    def sum(expression) = function('sum', expression)
    def avg(expression) = function('avg', expression)
    def min(expression) = function('min', expression)
    def max(expression) = function('max', expression)
    def nodes(path) = function('nodes', path.required_symbolic_name)
    def relationships(path) = function('relationships', path.required_symbolic_name)
    def length(path) = function('length', path.required_symbolic_name)
    def labels(node) = FunctionInvocation.new('labels', [node.required_symbolic_name])
    def element_id(element) = FunctionInvocation.new('elementId', [element.required_symbolic_name])

    # A call of any function with the given arguments, coerced to expressions.
    def function(name, *arguments) = FunctionInvocation.new(name, arguments.map { |a| Expression.coerce(a) })

    def sort(expression) = SortItem.new(Expression.coerce(expression), nil)

    def size(expression_or_pattern) = FunctionInvocation.new('size', [expression_or_pattern])
    def count(expression) = FunctionInvocation.new('count', [Expression.coerce(expression)])
    def count_distinct(expression) = FunctionInvocation.new('count', [Expression.coerce(expression)], distinct: true)
    def type(relationship) = FunctionInvocation.new('type', [relationship.required_symbolic_name])

    # `Cypher.call('db.labels')` / `Cypher.call('db', 'labels')`: a procedure call (see {StandaloneCall});
    # `Cypher.call(statement, imports…)`: a `CALL { subquery }`.
    def call(*arguments)
      return StatementBuilder.new.call(*arguments) if arguments.first.is_a?(Statement)

      StandaloneCall.new(arguments)
    end

    # `Cypher.use('graph', statement)`: the statement prefixed with `USE graph`.
    def use(graph, statement) = Statement.new([Clauses::Use.new(graph: graph.to_s)] + statement.clauses)

    # `Cypher.load_csv('file:///x.csv').as(:line)`.
    def load_csv(uri, with_headers: false) = StatementBuilder.new.load_csv(uri, with_headers:)

    # Imports for an EXISTS / COLLECT subquery: `Cypher.subquery_with(x).collect(statement)`.
    def subquery_with(*imports) = SubqueryWith.new(imports)

    # `CALL () { raw cypher }`; continues as a statement builder.
    def call_raw_cypher(cypher)
      clause = Clauses::CallSubquery.new(body: RawExpression.new(cypher), imports: [],
                                         in_transactions: false, rows: nil)
      StatementBuilder.new.send(:append, clause, nil)
    end

    # Verbatim Cypher, the escape hatch.
    def raw(cypher) = RawExpression.new(cypher)

    # Static comparison forms, `Cypher.gt(a, b)` etc.
    def eq(left, right) = Expression.coerce(left).is_equal_to(right)
    def ne(left, right) = Expression.coerce(left).is_not_equal_to(right)
    def gt(left, right) = Expression.coerce(left).gt(right)
    def gte(left, right) = Expression.coerce(left).gte(right)
    def lt(left, right) = Expression.coerce(left).lt(right)
    def lte(left, right) = Expression.coerce(left).lte(right)
    def coalesce(*expressions) = FunctionInvocation.new('coalesce', expressions.map { |e| Expression.coerce(e) })

    # --- statement builders -----------------------------------------------

    def match(*pattern_elements) = StatementBuilder.new.match(*pattern_elements)
    def optional_match(*pattern_elements) = StatementBuilder.new.optional_match(*pattern_elements)
    def create(*pattern_elements) = StatementBuilder.new.create(*pattern_elements)
    def merge(*pattern_elements) = StatementBuilder.new.merge(*pattern_elements)
    def with(*expressions) = StatementBuilder.new.with(*expressions)
    def unwind(*expressions) = StatementBuilder.new.unwind(*expressions)
    def returning(*expressions) = StatementBuilder.new.returning(*expressions)
    def returning_distinct(*expressions) = StatementBuilder.new.returning_distinct(*expressions)

    def union(*statements) = UnionQuery.create(statements, all: false)
    def union_all(*statements) = UnionQuery.create(statements, all: true)
  end
end
