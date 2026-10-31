# frozen_string_literal: true

module CypherDSL
  # `n:Label:Other` as the target of SET or REMOVE; `remove` marks an operation
  # built for REMOVE, which a SET clause rejects.
  class LabelOperation
    attr_reader :node, :labels, :remove

    def initialize(node, labels, remove: false)
      @node = node
      @labels = labels.map(&:to_s).freeze
      @remove = remove
      freeze
    end

    def remove? = remove
  end
end
