# frozen_string_literal: true

module CypherDSL
  module Clauses
    # `CREATE pattern, …`.
    Create = Data.define(:pattern_elements)
  end
end
