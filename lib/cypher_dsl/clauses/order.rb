# frozen_string_literal: true

module CypherDSL
  module Clauses
    # `ORDER BY item, …`; attached to RETURN or WITH.
    Order = Data.define(:items)
  end
end
