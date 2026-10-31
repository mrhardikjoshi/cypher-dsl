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

    def where(condition) = update_last(:condition) { |clause| clause.with(where: Condition.coerce(condition)) }

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

    # `unwind(list).as(:item)`; `as` completes the clause.
    def unwind(expression)
      OngoingUnwind.new(self, coerce_items([expression]).first)
    end

    # --- updating --------------------------------------------------------

    def create(*pattern_elements) = append(Clauses::Create.new(pattern_elements: pattern_elements.flatten.freeze), nil)

    def merge(*pattern_elements)
      append(Clauses::Merge.new(pattern_elements: pattern_elements.flatten.freeze, on_create: nil, on_match: nil), nil)
    end

    def set(*operations) = append(Clauses::Set.new(operations: operations.flatten.freeze), nil)

    def delete(*expressions) = append(Clauses::Delete.new(detach: false, expressions: coerce_items(expressions)), nil)

    def detach_delete(*expressions)
      append(Clauses::Delete.new(detach: true, expressions: coerce_items(expressions)), nil)
    end

    # --- finishing -------------------------------------------------------

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

    private

    def append(clause, mode) = StatementBuilder.new(@clauses + [clause], mode)

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

    # RETURN/WITH items: strings and symbols name variables, everything else is an expression.
    def coerce_items(expressions)
      expressions.flatten.map do |item|
        case item
        when String, Symbol then SymbolicName.of(item)
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
