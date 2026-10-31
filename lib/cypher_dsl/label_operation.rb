# frozen_string_literal: true

module CypherDSL
  # `n:Label:Other` as the target of SET or REMOVE.
  class LabelOperation
    attr_reader :node, :labels

    def initialize(node, labels)
      @node = node
      @labels = labels.map(&:to_s).freeze
      freeze
    end
  end
end
