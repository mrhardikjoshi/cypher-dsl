# frozen_string_literal: true

module CypherDSL
  # A literal value rendered inline: strings, numbers, booleans, NULL and lists.
  # Hashes become a {MapExpression}; expressions are returned unchanged.
  class Literal
    include Expression

    attr_reader :value

    def self.of(value)
      case value
      when Expression then value
      when Hash then MapExpression.of(value)
      when Array then ListExpression.of(value)
      else new(value)
      end
    end

    def initialize(value)
      @value = value.frozen? ? value : value.dup.freeze
      freeze
    end

    TRUE = new(true)
    FALSE = new(false)
    NULL = new(nil)
  end
end
