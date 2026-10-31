# frozen_string_literal: true

module CypherDSL
  module Clauses
    # `MERGE pattern`; `on_create` / `on_match` hold SET operations.
    Merge = Data.define(:pattern_elements, :on_create, :on_match)
  end
end
