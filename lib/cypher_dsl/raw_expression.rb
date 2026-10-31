# frozen_string_literal: true

module CypherDSL
  # A fragment of Cypher text rendered verbatim: the escape hatch, like `Arel.sql`.
  class RawExpression
    include Expression

    attr_reader :content

    def initialize(content)
      @content = content.to_s
      freeze
    end
  end
end
