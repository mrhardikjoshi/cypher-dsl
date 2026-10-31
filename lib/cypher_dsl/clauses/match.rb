# frozen_string_literal: true

module CypherDSL
  module Clauses
    # `[OPTIONAL] MATCH pattern [WHERE condition]`.
    Match = Data.define(:optional, :pattern_elements, :where)
  end
end
