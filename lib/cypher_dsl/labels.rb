# frozen_string_literal: true

module CypherDSL
  # A label expression as in `(n:A|B)`, `(n:(A|B)&!C)` or the dynamic `(n:$($labels))`.
  # Built from {Labels.exactly}, {Labels.all} and {Labels.any} and combined with
  # `and`, `or`, `negate`, `conjunction_with` (`:A:B`) and `disjunction_with`.
  class Labels
    # A single entry: a static label name, or an expression resolving to labels
    # matched with `$()` (all) or `$any()`.
    Value = Data.define(:modifier, :value)

    TYPES = %i[leaf colon_conjunction colon_disjunction conjunction disjunction].freeze
    OPERATORS = { conjunction: '&', disjunction: '|', colon_conjunction: ':', colon_disjunction: ':' }.freeze
    UPDATE_MESSAGE = 'Only a single dynamic label expression or a set of static labels might be used in an ' \
                     'updating clause'

    attr_reader :type, :values, :lhs, :rhs

    def self.exactly(label) = new(:leaf, values: [Value.new(:static, label.to_s)])
    def self.all(expression) = new(:leaf, values: [Value.new(:all, Expression.coerce(expression))])
    def self.any(expression) = new(:leaf, values: [Value.new(:any, Expression.coerce(expression))])

    def initialize(type, values: [], lhs: nil, rhs: nil, negated: false)
      raise ArgumentError, "Unknown label expression type #{type.inspect}" unless TYPES.include?(type)

      @type = type
      @values = values.freeze
      @lhs = lhs
      @rhs = rhs
      @negated = negated
      freeze
    end

    def negated? = @negated
    def leaf? = type == :leaf

    def and(other) = Labels.new(:conjunction, lhs: self, rhs: coerce(other))
    def or(other) = Labels.new(:disjunction, lhs: self, rhs: coerce(other))
    def negate = Labels.new(type, values:, lhs:, rhs:, negated: !negated?)
    alias not negate

    # `:A:B`, the form usable in SET and REMOVE.
    def conjunction_with(other) = Labels.new(:colon_conjunction, values: values + coerce(other).values)
    def disjunction_with(other) = Labels.new(:colon_disjunction, values: values + coerce(other).values)

    # SET and REMOVE take a single dynamic expression or a colon list starting with one.
    def usable_in_update?
      lhs.nil? && rhs.nil? && %i[leaf colon_conjunction].include?(type) && values.first&.modifier == :all
    end

    # True when nothing would be rendered, e.g. `$([])`.
    def empty?
      values_empty = if %i[conjunction disjunction].include?(type)
                       true
                     else
                       first = values.first&.value
                       first.is_a?(ListExpression) && first.elements.empty?
                     end
      values_empty && (lhs.nil? || lhs.empty?) && (rhs.nil? || rhs.empty?)
    end

    private

    def coerce(other) = other.is_a?(Labels) ? other : Labels.exactly(other)
  end
end
