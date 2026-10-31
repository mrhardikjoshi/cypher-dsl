# frozen_string_literal: true

module CypherDSL
  # A map projection `n{.name, .age, total: count(x), .*}`.
  class MapProjection
    include Expression

    attr_reader :subject, :entries

    def initialize(subject, entries)
      @subject = subject
      @entries = entries.freeze
      freeze
    end

    def and(*more_entries) = MapProjection.new(subject, entries + more_entries.flatten)
  end
end
