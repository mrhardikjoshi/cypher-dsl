# frozen_string_literal: true

module CypherDSL
  module Clauses
    # `WITH [DISTINCT] items [ORDER BY …] [SKIP …] [LIMIT …] [WHERE …]`; ends a query part.
    With = Data.define(:distinct, :items, :order, :skip, :limit, :where)
  end
end
