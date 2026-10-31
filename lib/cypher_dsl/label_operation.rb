# frozen_string_literal: true

module CypherDSL
  # `n:Label:Other` or `n:$($labels)` as the target of SET or REMOVE; `remove`
  # marks an operation built for REMOVE, which a SET clause rejects.
  class LabelOperation
    attr_reader :node, :labels, :remove

    def initialize(node, labels, remove: false)
      @node = node
      @labels = labels.map { |label| label.is_a?(Labels) ? updatable(label) : label.to_s }.freeze
      @remove = remove
      freeze
    end

    def remove? = remove

    private

    def updatable(labels)
      raise ArgumentError, Labels::UPDATE_MESSAGE unless labels.usable_in_update?

      labels
    end
  end
end
