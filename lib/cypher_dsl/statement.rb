# frozen_string_literal: true

module CypherDSL
  # A built, immutable statement: an ordered list of clauses. Rendering with the
  # default renderer is memoised, as in the Java `Statement#getCypher`.
  class Statement
    attr_reader :clauses, :prefix

    # An empty builder, as `Statement.builder()` in Java.
    def self.builder = StatementBuilder.new

    # A statement from a list of clause objects, as `Statement.of(clauses)` in Java.
    def self.of(clauses) = new(clauses)

    # `prefix` is `EXPLAIN` or `PROFILE` for the corresponding statement kinds.
    def initialize(clauses, prefix: nil)
      @clauses = clauses.freeze
      @prefix = prefix
      @cypher = nil
    end

    def cypher
      @cypher ||= Renderer.default.render(self).freeze
    end

    # Parameter names and bound values; raises {ConflictingParametersException}
    # when a name is bound inconsistently. Memoised, like `cypher`.
    def catalog
      @catalog ||= Renderer.default.catalog(self)
    end

    # `name => value` for every parameter that carries a value.
    def parameters = catalog.parameters

    # Every parameter name used, bound or not.
    def parameter_names = catalog.parameter_names

    # True when the statement produces rows: it ends with RETURN, or is a
    # procedure call with YIELD.
    def result_statement?
      last = clauses.last
      last.is_a?(Clauses::Return) || last.is_a?(Clauses::RawReturn) ||
        (last.is_a?(Clauses::Call) && !last.yield_items.empty?)
    end

    # True when the statement is a bare procedure call, with or without YIELD.
    def procedure_call? = clauses.size == 1 && clauses.first.is_a?(Clauses::Call)

    # True when the statement contains no WITH, i.e. has a single query part.
    def single_query? = !multi_part_query?

    def multi_part_query? = clauses.any?(Clauses::With)

    def to_s = cypher
  end
end
