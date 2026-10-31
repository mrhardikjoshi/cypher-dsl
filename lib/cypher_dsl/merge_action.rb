# frozen_string_literal: true

module CypherDSL
  # `ON CREATE SET …` / `ON MATCH SET …` attached to a MERGE.
  MergeAction = Data.define(:type, :operations)
end
