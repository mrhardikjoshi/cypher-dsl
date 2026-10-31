# frozen_string_literal: true

module CypherDSL
  class Renderer
    # Rendering options.
    #
    # - `always_escape_names`: backtick-escape labels and relationship types even
    #   when they are plain identifiers, as the Java default renderer does.
    # - `dialect`: one of {Dialect::ALL}.
    # - `pretty_print`: one clause per line, indented subqueries, conditions and maps.
    # - `indent_size` / `indent_style` (`:space` or `:tab`): the indentation unit.
    class Configuration
      attr_reader :always_escape_names, :dialect, :pretty_print, :indent_size, :indent_style

      # `always_escape_names` defaults to true, except when pretty printing, where
      # names are escaped only when necessary (as upstream does).
      def initialize(always_escape_names: nil, dialect: Dialect::NEO4J_5_23, pretty_print: false, indent_size: 2,
                     indent_style: :space)
        raise ArgumentError, "Unknown dialect #{dialect.inspect}" unless Dialect::ALL.include?(dialect)
        raise ArgumentError, "Unknown indent style #{indent_style.inspect}" unless %i[space tab].include?(indent_style)

        @always_escape_names = always_escape_names.nil? ? !pretty_print : always_escape_names
        @dialect = dialect
        @pretty_print = pretty_print
        @indent_size = indent_size
        @indent_style = indent_style
        freeze
      end

      DEFAULT = new

      # Mirrors `Configuration.newConfig()…build()`.
      def self.new_config = Builder.new

      # Mirrors `Configuration.prettyPrinting()`: pretty printed, names escaped only when needed.
      def self.pretty_printing = new(pretty_print: true)

      # `CALL { WITH imports … }` (older dialects) rather than `CALL (imports) { … }`.
      def legacy_subquery_syntax? = Dialect::LEGACY_SUBQUERY_SYNTAX.include?(dialect)

      def indent_unit = indent_style == :tab ? "\t" : ' ' * indent_size

      # Fluent builder; each setter returns the builder.
      class Builder
        def initialize
          @options = {}
        end

        def always_escape_names(value) = option(:always_escape_names, value)
        def with_dialect(dialect) = option(:dialect, dialect)
        def with_pretty_print(value) = option(:pretty_print, value)
        def with_indent_size(size) = option(:indent_size, size)
        def with_indent_style(style) = option(:indent_style, style)

        def build = Configuration.new(**@options)

        private

        def option(name, value)
          @options[name] = value
          self
        end
      end
    end
  end
end
