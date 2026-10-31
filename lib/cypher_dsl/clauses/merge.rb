# frozen_string_literal: true

module CypherDSL
  module Clauses
    # `MERGE pattern [ON CREATE SET …] [ON MATCH SET …]`; actions keep call order.
    Merge = Data.define(:pattern_elements, :actions)
  end
end
