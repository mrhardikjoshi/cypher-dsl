# frozen_string_literal: true

module CypherDSL
  # A variable name, such as the `n` in `MATCH (n)`.
  class SymbolicName
    include Expression

    attr_reader :value

    def self.of(value)
      value.is_a?(SymbolicName) ? value : new(value.to_s)
    end

    def initialize(value)
      raise ArgumentError, 'A symbolic name must not be empty.' if value.empty?

      @value = value
      freeze
    end

    # The map projection `name{…}`.
    def project(*entries) = MapProjection.new(self, entries.flatten)

    def property(*names) = Property.new(self, names)

    def ==(other) = other.is_a?(SymbolicName) && other.value == value
    alias eql? ==
    def hash = [self.class, value].hash
    def to_s = value
  end
end
