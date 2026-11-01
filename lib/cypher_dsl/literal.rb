# frozen_string_literal: true

require 'date'
require 'time'

module CypherDSL
  # A literal value rendered inline: strings, numbers, booleans, NULL, dates and
  # times. Hashes become a {MapExpression}, arrays a {ListExpression}; expressions
  # are returned unchanged.
  class Literal
    include Expression

    SUPPORTED_TYPES = [String, Numeric, TrueClass, FalseClass, NilClass, Date, Time].freeze

    attr_reader :value

    def self.of(value)
      case value
      when Expression then value
      when Hash then MapExpression.of(value)
      when Array then ListExpression.of(value)
      when true then Literal::TRUE
      when false then Literal::FALSE
      when nil then Literal::NULL
      else new(value)
      end
    end

    # `'…'`, with backslashes and quotes escaped; `nil` quotes to `''`.
    def self.quote(string) = "'#{escape_string(string)}'"

    # The content of a string literal: backslashes, single and double quotes get a backslash.
    def self.escape_string(string) = string&.gsub(/['"\\]/) { |character| "\\#{character}" }

    def initialize(value)
      unless SUPPORTED_TYPES.any? { |type| value.is_a?(type) }
        raise ArgumentError, "Unsupported literal type: #{value.class}"
      end

      @value = value.frozen? ? value : value.dup.freeze
      freeze
    end

    # The literal as Cypher, as the Java `Literal#asString`.
    def as_string = to_s

    TRUE = new(true)
    FALSE = new(false)
    NULL = new(nil)
  end
end
