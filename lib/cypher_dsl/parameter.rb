# frozen_string_literal: true

module CypherDSL
  # A named query parameter, rendered as `$name`.
  class Parameter
    include Expression

    attr_reader :name

    def initialize(name)
      @name = name.to_s
      raise ArgumentError, 'A parameter name must not be empty.' if @name.empty?

      freeze
    end
  end
end
