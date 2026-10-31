# frozen_string_literal: true

module CypherDSL
  module Clauses
    # `REMOVE n.prop, n:Label`.
    Remove = Data.define(:items)
  end
end
