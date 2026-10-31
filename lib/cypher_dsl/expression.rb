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

    alias eq is_equal_to
    alias ne is_not_equal_to
  end
end
