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

    # True when the statement ends with RETURN, i.e. produces rows.
    def result_statement? = clauses.last.is_a?(Clauses::Return)

    # True when the statement contains no WITH, i.e. has a single query part.
    def single_query? = !multi_part_query?

    def multi_part_query? = clauses.any?(Clauses::With)

    def to_s = cypher
  end
end
