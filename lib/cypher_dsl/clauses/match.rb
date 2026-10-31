# frozen_string_literal: true

module CypherDSL
  module Clauses
    # `[OPTIONAL] MATCH pattern [USING hint …] [SEARCH …] [WHERE condition]`.
    Match = Data.define(:optional, :pattern_elements, :hints, :search, :where)
  end
end
