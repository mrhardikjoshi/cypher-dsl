# frozen_string_literal: true

module CypherDSL
  module Clauses
    # `LOAD CSV [WITH HEADERS] FROM 'uri' AS alias`.
    LoadCsv = Data.define(:uri, :with_headers, :alias_name)
  end
end
