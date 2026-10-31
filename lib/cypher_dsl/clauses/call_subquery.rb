# frozen_string_literal: true

module CypherDSL
  module Clauses
    # `CALL (imports) { body } [IN TRANSACTIONS [OF n ROWS]]`; the body is a
    # statement or a raw Cypher fragment, `imports` a list of names or the asterisk.
    CallSubquery = Data.define(:body, :imports, :in_transactions, :rows)
  end
end
