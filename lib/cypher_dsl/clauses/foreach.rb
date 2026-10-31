# frozen_string_literal: true

module CypherDSL
  module Clauses
    # `FOREACH (variable IN list | updating clauses)`.
    Foreach = Data.define(:variable, :list, :clauses)
  end
end
