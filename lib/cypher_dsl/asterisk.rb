# frozen_string_literal: true

module CypherDSL
  # The `*` in `RETURN *`.
  class Asterisk
    include Expression

    INSTANCE = new.freeze
  end
end
