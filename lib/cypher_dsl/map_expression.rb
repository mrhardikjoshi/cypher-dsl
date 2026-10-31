# frozen_string_literal: true

module CypherDSL
  # A map literal such as `{name: 'Alice', age: $age}`. Keys are strings,
  # values are expressions.
  class MapExpression
    include Expression

    attr_reader :entries

    # Accepts a single Hash or alternating keys and values, as `Cypher.map_of` does.
    def self.of(*keys_and_values)
      return keys_and_values.first if keys_and_values.size == 1 && keys_and_values.first.is_a?(MapExpression)

      pairs = if keys_and_values.size == 1 && keys_and_values.first.is_a?(Hash)
                keys_and_values.first.to_a
              else
                raise ArgumentError, 'map_of needs an even number of arguments' if keys_and_values.size.odd?

                keys_and_values.each_slice(2).to_a
              end
      new(pairs.map { |key, value| [key.to_s, Expression.coerce(value)] })
    end

    def initialize(entries)
      @entries = entries.map(&:freeze).freeze
      freeze
    end

    def empty? = entries.empty?
  end
end
