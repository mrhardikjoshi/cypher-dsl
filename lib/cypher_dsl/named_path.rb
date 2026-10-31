# frozen_string_literal: true

module CypherDSL
  # A named path `p = (a)-[]->(b)`, optionally with a path selector such as
  # `p = ANY SHORTEST …`. Usable as a pattern element in MATCH and as an
  # expression (`p`) afterwards. Built with `Cypher.path(:p).defined_by(pattern)`
  # or `Cypher.any_shortest.named(:p).defined_by(pattern)`.
  class NamedPath
    include Expression

    attr_reader :symbolic_name, :pattern, :selector

    def initialize(symbolic_name, pattern, selector: nil)
      @symbolic_name = symbolic_name
      @pattern = pattern
      @selector = selector
      freeze
    end

    alias required_symbolic_name symbolic_name
    alias as_expression symbolic_name

    # `Cypher.path(:p)`: waiting for `defined_by`, or `get` for a bare reference to the name.
    class Ongoing
      def initialize(symbolic_name, selector: nil)
        @symbolic_name = symbolic_name
        @selector = selector
        freeze
      end

      # Defining a path by another named path reuses that path.
      def defined_by(pattern)
        return pattern if pattern.is_a?(NamedPath)

        NamedPath.new(@symbolic_name, pattern, selector: @selector)
      end

      def get = @symbolic_name
    end

    # `Cypher.any_shortest` and friends: a path selector waiting for `named`.
    class Selector
      # `legacy_function` is the pre-5.21 spelling (`shortestPath`, `allShortestPaths`), if any.
      attr_reader :keyword, :legacy_function

      def self.shortest_k(count, groups: false)
        raise ArgumentError, 'The path count needs to be greater than 0.' unless count.positive?

        legacy_function = count == 1 && !groups ? 'shortestPath' : nil
        new("SHORTEST #{count}#{' GROUPS' if groups}", legacy_function:)
      end

      def initialize(keyword, legacy_function: nil)
        @keyword = keyword
        @legacy_function = legacy_function
        freeze
      end

      def named(name) = Ongoing.new(SymbolicName.of(name), selector: self)
    end
  end
end
