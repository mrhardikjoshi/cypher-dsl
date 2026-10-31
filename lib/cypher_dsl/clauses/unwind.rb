# frozen_string_literal: true

module CypherDSL
  module Clauses
    # `UNWIND expression AS variable`.
    Unwind = Data.define(:expression, :variable)
  end
end
