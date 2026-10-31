# frozen_string_literal: true

module CypherDSL
  class Renderer
    # Rendering options. `always_escape_names` backtick-escapes labels and
    # relationship types even when they are plain identifiers, as the Java
    # default renderer does.
    class Configuration
      attr_reader :always_escape_names

      def initialize(always_escape_names: true)
        @always_escape_names = always_escape_names
        freeze
      end

      DEFAULT = new

      # Mirrors `Configuration.newConfig()…build()`.
      def self.new_config = Builder.new

      # Fluent builder; each setter returns the builder.
      class Builder
        def initialize
          @options = {}
        end

        def always_escape_names(value)
          @options[:always_escape_names] = value
          self
        end

        def build = Configuration.new(**@options)
      end
    end
  end
end
