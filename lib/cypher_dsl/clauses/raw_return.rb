# frozen_string_literal: true

module CypherDSL
  module Clauses
    # Items rendered without the RETURN keyword, for raw fragments that carry their own.
    RawReturn = Data.define(:items)
  end
end
