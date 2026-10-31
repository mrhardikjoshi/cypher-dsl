# frozen_string_literal: true

module CypherDSL
  # Builds a {Statement} clause by clause. Every method returns a new builder;
  # the last clause stays open for refinement (WHERE on MATCH/WITH, ORDER BY,
  # SKIP and LIMIT on RETURN/WITH) until the next clause is added.
  #
  # `and` is overloaded as in the Java API: after `where` it extends the
  # condition, after `order_by` it adds another sort item.
  class StatementBuilder
    def initialize(clauses = [], mode = nil)
      @clauses = clauses.freeze
      @mode = mode
      freeze
    end

    # --- reading ---------------------------------------------------------

    # `match(pattern, …)` or, as in Java, `match(optional, pattern, …)` with a leading flag.
    def match(*pattern_elements)
      optional = [true, false].include?(pattern_elements.first) ? pattern_elements.shift : false
      append(Clauses::Match.new(optional:, pattern_elements: pattern_elements.flatten.freeze, where: nil), :condition)
    end

    def optional_match(*pattern_elements) = match(true, *pattern_elements)

    def where(condition)
      if @clauses.last.is_a?(Clauses::CallSubquery)
        raise ArgumentError, 'A CALL{} clause requires to WITH before you can add further conditions'
      end

      update_last(:condition) { |clause| clause.with(where: Condition.coerce(condition)) }
    end

    def and(argument)
      case @mode
      when :order then add_sort_item(argument)
      when :condition then update_last(:condition) { |clause| clause.with(where: clause.where.and(argument)) }
      else raise ArgumentError, '`and` needs a preceding WHERE or ORDER BY.'
      end
    end

    def or(condition) = update_last(:condition) { |clause| clause.with(where: clause.where.or(condition)) }
    def xor(condition) = update_last(:condition) { |clause| clause.with(where: clause.where.xor(condition)) }

    # --- projecting ------------------------------------------------------

    def returning(*expressions) = append(return_clause(false, expressions), :projection)
    def returning_distinct(*expressions) = append(return_clause(true, expressions), :projection)

    # A projection rendered without the RETURN keyword, for raw fragments that carry their own.
    def returning_raw(*expressions) = append(Clauses::RawReturn.new(items: coerce_items(expressions)), :projection)

    def with(*expressions)
      append(Clauses::With.new(distinct: false, items: coerce_items(expressions), order: nil, skip: nil, limit: nil,
                               where: nil), :condition)
    end

    def with_distinct(*expressions)
      append(Clauses::With.new(distinct: true, items: coerce_items(expressions), order: nil, skip: nil, limit: nil,
                               where: nil), :condition)
    end

    def order_by(*sort_items)
      update_last(:order) { |clause| clause.with(order: Clauses::Order.new(items: coerce_sort_items(sort_items))) }
    end

    def ascending = update_last_sort_item(&:ascending)
    def descending = update_last_sort_item(&:descending)

    def skip(amount) = update_last(@mode) { |clause| clause.with(skip: optional_expression(amount)) }
    def limit(amount) = update_last(@mode) { |clause| clause.with(limit: optional_expression(amount)) }
    alias take limit # Arel spelling

    # `unwind(list).as(:item)`; `as` completes the clause. Several arguments, or
    # an array, form a list literal.
    def unwind(*expressions)
      single = expressions.size == 1 && !expressions.first.is_a?(Array)
      OngoingUnwind.new(self, single ? coerce_items(expressions).first : ListExpression.of(expressions.flatten))
    end

    # --- updating --------------------------------------------------------

    def create(*pattern_elements) = append(Clauses::Create.new(pattern_elements: pattern_elements.flatten.freeze), nil)

    def merge(*pattern_elements)
      append(Clauses::Merge.new(pattern_elements: pattern_elements.flatten.freeze, actions: [].freeze), nil)
    end

    # `on_match.set(…)` / `on_create.mutate(…)` after a MERGE.
    def on_match = MergeActionBuilder.new(self, :on_match)
    def on_create = MergeActionBuilder.new(self, :on_create)

    # Accepts operations (`n.p.to(x)`, `n.mutate(map)`), a node followed by
    # labels (`set(n, 'A', 'B')`), or an even list of target/value pairs.
    def set(*arguments) = append(Clauses::Set.new(operations: operations_for_set(arguments)), nil)

    # `SET target += expression`.
    def mutate(target, expression) = set(Operation.new(target, '+=', Expression.coerce(expression)))

    # Accepts properties, or a node followed by labels (`remove(n, 'A', 'B')`).
    def remove(*arguments)
      arguments = arguments.flatten
      items = label_operation?(arguments) ? [LabelOperation.new(arguments.first, arguments.drop(1))] : arguments
      append(Clauses::Remove.new(items: items.freeze), nil)
    end

    def delete(*expressions) = append(Clauses::Delete.new(detach: false, expressions: coerce_items(expressions)), nil)

    def detach_delete(*expressions)
      append(Clauses::Delete.new(detach: true, expressions: coerce_items(expressions)), nil)
    end

    # `foreach(:i).in(list).apply(clause, …)`.
    def foreach(variable) = OngoingForeach.new(self, SymbolicName.of(variable))

    # `call('db.labels').with_args(…).yield(…)` for a procedure, or
    # `call(statement, imports…)` for a `CALL { subquery }`.
    def call(*arguments)
      return StandaloneCall.new(arguments, builder: self) unless arguments.first.is_a?(Statement)

      statement, *imports = arguments
      append(subquery_clause(statement, imports, in_transactions: false, rows: nil), nil)
    end

    # `CALL { subquery } IN TRANSACTIONS [OF n ROWS]`; `call_in_transactions(statement, [rows], imports…)`.
    def call_in_transactions(statement, *arguments)
      rows = arguments.first.is_a?(Integer) ? arguments.shift : nil
      append(subquery_clause(statement, arguments, in_transactions: true, rows:), nil)
    end

    # `CALL (*) { raw cypher }`.
    def call_raw_cypher(cypher)
      body = RawExpression.new(cypher)
      append(Clauses::CallSubquery.new(body:, imports: [], in_transactions: false, rows: nil), nil)
    end

    # `load_csv('file:///x.csv').as(:line)`.
    def load_csv(uri, with_headers: false) = OngoingLoadCsv.new(self, uri.to_s, with_headers)

    # The statement built so far as an `EXISTS { … }` condition.
    def as_condition = ExistsCondition.new(build)

    # --- finishing -------------------------------------------------------

    # Continues with the clauses of another statement, e.g. after a `CALL … YIELD`.
    def and_then(statement) = StatementBuilder.new(@clauses + statement.clauses, nil)

    def finish = append(Clauses::Finish.new, nil)

    def build = Statement.new(@clauses)
    def explain = Statement.new(@clauses, prefix: 'EXPLAIN')
    def profile = Statement.new(@clauses, prefix: 'PROFILE')

    # Intermediate state of `unwind(expression)` waiting for `as(variable)`.
    class OngoingUnwind
      def initialize(builder, expression)
        @builder = builder
        @expression = expression
        freeze
      end

      def as(variable)
        @builder.send(:append, Clauses::Unwind.new(expression: @expression, variable: SymbolicName.of(variable)), nil)
      end
    end

    # Intermediate states of `foreach(variable)`: `in(list)` then `apply(clauses…)`.
    class OngoingForeach
      def initialize(builder, variable, list = nil)
        @builder = builder
        @variable = variable
        @list = list
        freeze
      end

      def in(list) = OngoingForeach.new(@builder, @variable, Expression.coerce(list))

      def apply(*clauses)
        foreach = Clauses::Foreach.new(variable: @variable, list: @list, clauses: clauses.flatten.freeze)
        @builder.send(:append, foreach, nil)
      end
    end

    # Intermediate state of `load_csv(uri)` waiting for `as(alias)`.
    class OngoingLoadCsv
      def initialize(builder, uri, with_headers)
        @builder = builder
        @uri = uri
        @with_headers = with_headers
        freeze
      end

      def as(alias_name)
        clause = Clauses::LoadCsv.new(uri: @uri, with_headers: @with_headers, alias_name: SymbolicName.of(alias_name))
        @builder.send(:append, clause, nil)
      end
    end

    # Intermediate state after `on_match` / `on_create`, waiting for `set` or `mutate`.
    class MergeActionBuilder
      def initialize(builder, type)
        @builder = builder
        @type = type
        freeze
      end

      def set(*arguments) = @builder.send(:add_merge_action, @type, @builder.send(:operations_for_set, arguments))

      def mutate(target, expression) = set(Operation.new(target, '+=', Expression.coerce(expression)))
    end

    private

    attr_reader :clauses

    def append(clause, mode) = StatementBuilder.new(@clauses + [clause], mode)

    def subquery_clause(statement, imports, in_transactions:, rows:)
      Clauses::CallSubquery.new(body: statement, imports: coerce_items(imports), in_transactions:, rows:)
    end

    def add_merge_action(type, operations)
      update_last(nil) do |clause|
        raise ArgumentError, 'ON CREATE / ON MATCH need a preceding MERGE.' unless clause.is_a?(Clauses::Merge)

        clause.with(actions: clause.actions + [MergeAction.new(type:, operations:)])
      end
    end

    def operations_for_set(arguments)
      arguments = arguments.flatten
      if arguments.any? { |argument| argument.is_a?(LabelOperation) && argument.remove? }
        raise ArgumentError, 'REMOVE operations are not supported in a SET clause'
      end
      return [LabelOperation.new(arguments.first, arguments.drop(1))].freeze if label_operation?(arguments)
      return arguments.freeze if arguments.all? { |argument| operation?(argument) }
      raise ArgumentError, 'The list of expression to set must be even.' if arguments.size.odd?

      arguments.each_slice(2).map { |target, value| Operation.new(target, '=', Expression.coerce(value)) }.freeze
    end

    def operation?(argument) = argument.is_a?(Operation) || argument.is_a?(LabelOperation)

    def label_operation?(arguments)
      arguments.size > 1 && arguments.first.is_a?(Node) &&
        arguments.drop(1).all? { |argument| argument.is_a?(String) || argument.is_a?(Symbol) }
    end

    def optional_expression(value) = value.nil? ? nil : Expression.coerce(value)

    def update_last(mode)
      raise ArgumentError, 'There is no clause to refine yet.' if @clauses.empty?

      StatementBuilder.new(@clauses[0...-1] + [yield(@clauses.last)], mode)
    end

    def return_clause(distinct, expressions)
      Clauses::Return.new(distinct:, items: coerce_items(expressions), order: nil, skip: nil, limit: nil)
    end

    def add_sort_item(expression)
      update_last(:order) do |clause|
        clause.with(order: Clauses::Order.new(items: clause.order.items + coerce_sort_items([expression])))
      end
    end

    def update_last_sort_item
      update_last(:order) do |clause|
        items = clause.order.items
        clause.with(order: Clauses::Order.new(items: items[0...-1] + [yield(items.last)]))
      end
    end

    # RETURN/WITH items: strings and symbols name variables, nodes and
    # relationships stand for their (possibly generated) names, everything else
    # is an expression.
    def coerce_items(expressions)
      expressions.flatten.map do |item|
        case item
        when String, Symbol then SymbolicName.of(item)
        when Node, Relationship then item.required_symbolic_name
        else Expression.coerce(item)
        end
      end.freeze
    end

    def coerce_sort_items(sort_items)
      sort_items.flatten.map do |item|
        item.is_a?(SortItem) ? item : SortItem.new(Expression.coerce(item), nil)
      end.freeze
    end
  end
end
