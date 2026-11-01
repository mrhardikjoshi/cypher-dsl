# frozen_string_literal: true

module CypherDSL
  class Renderer
    # Backtick escaping of schema names and identifiers, following the upstream
    # rules: the text ``` stands for a backtick, doubled backticks are
    # collapsed first, then every backtick is doubled and the name wrapped.
    module Escaper
      IDENTIFIER = /\A[\p{L}_][\p{L}\p{N}_]*\z/
      # Parameter names may be dotted (`$point.distance`) without escaping.
      PARAMETER_NAME = /\A[\p{L}_][\p{L}\p{N}_.]*\z/
      UNICODE_BACKTICK = "#{92.chr}u0060".freeze

      module_function

      # Always escapes.
      def escape(name)
        normalized = name.gsub(UNICODE_BACKTICK, '`').gsub('``', '`')
        "`#{normalized.gsub('`', '``')}`"
      end

      # Escapes only names that are not plain identifiers; `nil` stays `nil`.
      def escape_if_necessary(name)
        return nil if name.nil?

        IDENTIFIER.match?(name) ? name : escape(name)
      end

      def escape_parameter_name(name)
        PARAMETER_NAME.match?(name) ? name : escape(name)
      end
    end
  end
end
