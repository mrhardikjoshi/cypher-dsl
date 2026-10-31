# frozen_string_literal: true

module CypherDSL
  module Clauses
    # `RETURN [DISTINCT] items [ORDER BY …] [SKIP …] [LIMIT …]`.
    Return = Data.define(:distinct, :items, :order, :skip, :limit)
  end
end
