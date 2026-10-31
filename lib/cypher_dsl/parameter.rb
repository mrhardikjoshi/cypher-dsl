# frozen_string_literal: true

module CypherDSL
  # A named query parameter, rendered as `$name`, optionally carrying its value.
  class Parameter
    include Expression

    NO_VALUE = Object.new.freeze

    attr_reader :name, :value

    def initialize(name, value = NO_VALUE)
      @name = name.to_s
      raise ArgumentError, 'A parameter name must not be empty.' if @name.empty?

      @value = value
      freeze
    end

    def with_value(value) = Parameter.new(name, value)

    def value? = !value.equal?(NO_VALUE)
  end
end
