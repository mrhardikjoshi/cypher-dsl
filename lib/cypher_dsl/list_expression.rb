# frozen_string_literal: true

module CypherDSL
  # A list literal `[a, b, c]` of expressions.
  class ListExpression
    include Expression

    attr_reader :elements

    def self.of(*elements) = new(elements.flatten.map { |element| Expression.coerce(element) })

    def initialize(elements)
      @elements = elements.freeze
      freeze
    end
  end
end
