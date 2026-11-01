# frozen_string_literal: true

module CypherDSL
  module Clauses
    # A clause rendered verbatim from a {RawExpression}: the escape hatch for
    # Cypher the builder does not model (`raw_clause('CALL db.labels()')`).
    Raw = Data.define(:expression)
  end
end
