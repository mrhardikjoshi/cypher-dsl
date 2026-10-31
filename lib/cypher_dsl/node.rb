# frozen_string_literal: true

module CypherDSL
  # A node pattern `(name:Label {props})`. Used as an expression it stands for
  # its symbolic name.
  class Node
    include Expression

    attr_reader :labels, :symbolic_name, :properties

    def initialize(labels:, symbolic_name: nil, properties: nil)
      @labels = labels.freeze
      @symbolic_name = symbolic_name
      @properties = properties
      freeze
    end

    def named(name) = with(symbolic_name: SymbolicName.of(name))

    def with_properties(*keys_and_values) = with(properties: MapExpression.of(*keys_and_values))

    def named? = !symbolic_name.nil?

    def required_symbolic_name
      symbolic_name or raise ArgumentError, 'This node needs a symbolic name (use `named`) to be referenced.'
    end

    def property(*names) = Property.new(required_symbolic_name, names)

    # The condition `n:Label`, checking the node for the given labels.
    def has_labels(*labels) = HasLabelCondition.new(self, labels)

    def relationship_to(other, *types) = Relationship.create(self, :ltr, other, types)
    def relationship_from(other, *types) = Relationship.create(self, :rtl, other, types)
    def relationship_between(other, *types) = Relationship.create(self, :uni, other, types)

    private

    def with(**changes)
      Node.new(labels:, symbolic_name:, properties:, **changes)
    end
  end
end
