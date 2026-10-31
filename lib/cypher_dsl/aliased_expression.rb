# frozen_string_literal: true

module CypherDSL
  # `expression AS alias`.
  class AliasedExpression
    include Expression

    attr_reader :delegate, :alias_name

    def initialize(delegate, alias_name)
      @delegate = delegate
      @alias_name = SymbolicName.of(alias_name)
      freeze
    end
  end
end
