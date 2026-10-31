# frozen_string_literal: true

module CypherDSL
  module Clauses
    # `FINISH`: terminates a query without returning rows (Neo4j 5.19+).
    Finish = Data.define
  end
end
