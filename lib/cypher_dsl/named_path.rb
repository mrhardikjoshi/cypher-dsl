# frozen_string_literal: true

module CypherDSL
  # A named path `p = (a)-[]->(b)`, usable as a pattern element in MATCH and as
  # an expression (`p`) afterwards. Built with `Cypher.path(:p).defined_by(pattern)`.
  class NamedPath
    include Expression

    attr_reader :symbolic_name, :pattern

    def initialize(symbolic_name, pattern)
      @symbolic_name = symbolic_name
      @pattern = pattern
      freeze
    end

    alias required_symbolic_name symbolic_name
    alias as_expression symbolic_name

    # `Cypher.path(:p)`: waiting for `defined_by`, or `get` for a bare reference to the name.
    class Ongoing
      def initialize(symbolic_name)
        @symbolic_name = symbolic_name
        freeze
      end

      # Defining a path by another named path reuses that path.
      def defined_by(pattern) = pattern.is_a?(NamedPath) ? pattern : NamedPath.new(@symbolic_name, pattern)

      def get = @symbolic_name
    end
  end
end
