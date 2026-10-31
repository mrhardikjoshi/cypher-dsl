# frozen_string_literal: true

module CypherDSL
  # A variable name, such as the `n` in `MATCH (n)`.
  #
  # An *unresolved* name has no value yet: it is handed out when an unnamed
  # node or relationship needs a name, and the renderer generates one for it.
  class SymbolicName
    include Expression

    attr_reader :value, :hint

    def self.of(value)
      value.is_a?(SymbolicName) ? value : new(value.to_s)
    end

    # A name to be generated at render time; `hint` seeds the generated name (letters only).
    def self.unresolved(hint) = new(nil, hint: hint.to_s.gsub(/[^a-zA-Z]/, ''))

    def initialize(value, hint: nil)
      raise ArgumentError, 'A symbolic name must not be empty.' if value && value.empty?

      @value = value
      @hint = hint
      freeze
    end

    def resolved? = !value.nil?

    # A name is its own name; lets names stand in for named elements (e.g. `nodes(p)`).
    def required_symbolic_name = self

    # The map projection `name{…}`.
    def project(*entries) = MapProjection.new(self, entries.flatten)

    def property(*names) = Property.new(self, names)

    # Resolved names are equal by value; unresolved ones only to themselves.
    def ==(other)
      return equal?(other) unless resolved?

      other.is_a?(SymbolicName) && other.value == value
    end
    alias eql? ==
    def hash = resolved? ? [self.class, value].hash : object_id.hash
    def to_s = value || 'Unresolved SymbolicName'
  end
end
