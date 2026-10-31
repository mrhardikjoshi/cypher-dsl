# frozen_string_literal: true

module CypherDSL
  module Clauses
    # `CALL (imports) { body }`; the body is a statement or a raw Cypher fragment.
    CallSubquery = Data.define(:body, :imports)
  end
end
