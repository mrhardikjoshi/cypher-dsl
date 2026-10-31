# frozen_string_literal: true

module CypherDSL
  # The label predicate `n:Label:Other`.
  class HasLabelCondition < Condition
    attr_reader :node, :labels

    def initialize(node, labels)
      super()
      @node = node
      @labels = labels.map(&:to_s).freeze
      freeze
    end
  end
end
