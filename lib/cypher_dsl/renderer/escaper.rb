# frozen_string_literal: true

module CypherDSL
  class Renderer
    # Backtick escaping of schema names and identifiers.
    module Escaper
      IDENTIFIER = /\A[\p{L}_][\p{L}\p{N}_]*\z/
      ESCAPED = /\A`.*`\z/m

      module_function

      # Always escapes, unless the name already is.
      def escape(name)
        return name if ESCAPED.match?(name)

        "`#{name.gsub('`', '``')}`"
      end

      # Escapes only names that are not plain identifiers.
      def escape_if_necessary(name)
        IDENTIFIER.match?(name) ? name : escape(name)
      end
    end
  end
end
