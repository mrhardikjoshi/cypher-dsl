# frozen_string_literal: true

module CypherDSL
  # Mixed into everything that can appear where Cypher expects an expression.
  # Provides the fluent condition, alias and sort helpers of the Java API.
  module Expression
    # Coerces a plain Ruby value into an expression; expressions pass through.
    def self.coerce(value)
      value.is_a?(Expression) ? value : Literal.of(value)
    end

    def as(alias_name) = AliasedExpression.new(self, alias_name)

    # A property of this expression's value, e.g. `$param.key` or `datetime().epochSeconds`.
    def property(*names) = Property.new(self, names)

    # This expression as a condition, e.g. a CASE expression in WHERE.
    def as_condition = ExpressionCondition.new(self)

    def ascending = SortItem.new(self, :asc)
    def descending = SortItem.new(self, :desc)

    def is_equal_to(other) = Comparison.new(self, '=', Expression.coerce(other))
    def is_not_equal_to(other) = Comparison.new(self, '<>', Expression.coerce(other))
    def lt(other) = Comparison.new(self, '<', Expression.coerce(other))
    def lte(other) = Comparison.new(self, '<=', Expression.coerce(other))
    def gt(other) = Comparison.new(self, '>', Expression.coerce(other))
    def gte(other) = Comparison.new(self, '>=', Expression.coerce(other))
    def matches(other) = Comparison.new(self, '=~', Expression.coerce(other))
    def starts_with(other) = Comparison.new(self, 'STARTS WITH', Expression.coerce(other))
    def ends_with(other) = Comparison.new(self, 'ENDS WITH', Expression.coerce(other))
    def contains(other) = Comparison.new(self, 'CONTAINS', Expression.coerce(other))
    def is_null = Comparison.new(self, 'IS NULL', nil)
    def is_not_null = Comparison.new(self, 'IS NOT NULL', nil)
    def is_true = Comparison.new(self, '=', Literal::TRUE)
    def is_false = Comparison.new(self, '=', Literal::FALSE)
    def in(haystack) = Comparison.new(self, 'IN', Expression.coerce(haystack))

    # `size(self)`, `size(self) = n` and `size(self) = 0`.
    def size = FunctionInvocation.new('size', [self])
    def has_size(expected) = size.is_equal_to(expected)
    def is_empty = size.is_equal_to(Literal.new(0))

    # `all(x IN list WHERE x IN self)` / `any(…)`: does this list contain all / any of the elements?
    def includes_all(list) = ListPredicate.new('all', :x, Expression.coerce(list), SymbolicName.of(:x).in(self))
    def includes_any(list) = ListPredicate.new('any', :x, Expression.coerce(list), SymbolicName.of(:x).in(self))

    # Arithmetic; rendered in parentheses, e.g. `(a + b)`.
    def add(other) = Operation.new(self, '+', Expression.coerce(other))
    def subtract(other) = Operation.new(self, '-', Expression.coerce(other))
    def multiply(other) = Operation.new(self, '*', Expression.coerce(other))
    def divide(other) = Operation.new(self, '/', Expression.coerce(other))
    def remainder(other) = Operation.new(self, '%', Expression.coerce(other))
    def pow(other) = Operation.new(self, '^', Expression.coerce(other))
    def concat(other) = Operation.new(self, '+', Expression.coerce(other))

    # Java short forms.
    alias eq is_equal_to
    alias ne is_not_equal_to

    # Arel spellings, each mapping to exactly one of the above.
    alias not_eq is_not_equal_to
    alias gteq gte
    alias lteq lte
    alias asc ascending
    alias desc descending
    def not_in(haystack) = self.in(haystack).not
  end
end
