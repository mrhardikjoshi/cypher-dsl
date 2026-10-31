# frozen_string_literal: true

module CypherDSL
  module Clauses
    # `[DETACH] DELETE expression, …`.
    Delete = Data.define(:detach, :expressions)
  end
end
