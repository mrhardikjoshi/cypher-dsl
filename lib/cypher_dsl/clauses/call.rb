# frozen_string_literal: true

module CypherDSL
  module Clauses
    # `CALL name.parts(arguments) [YIELD items] [WHERE condition]`.
    Call = Data.define(:name_parts, :arguments, :yield_items, :where)
  end
end
