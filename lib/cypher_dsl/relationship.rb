# frozen_string_literal: true

module CypherDSL
  # A relationship pattern between two nodes, `(a)-[r:TYPE*1..3 {props}]->(b)`.
  # Used as an expression it stands for its symbolic name.
  class Relationship
    include Expression

    # Everything between the brackets plus the direction.
    Details = Data.define(:types, :symbolic_name, :properties, :min, :max, :unbounded) do
      def empty?
        symbolic_name.nil? && types.empty? && properties.nil? && !length?
      end

      def length? = unbounded || !min.nil? || !max.nil?
    end

    attr_reader :left, :right, :direction, :details

    def self.create(left, direction, right, types)
      details = Details.new(types: types.map(&:to_s).freeze, symbolic_name: nil, properties: nil,
                            min: nil, max: nil, unbounded: false)
      new(left, direction, right, details)
    end

    def initialize(left, direction, right, details)
      @left = left
      @direction = direction
      @right = right
      @details = details
      freeze
    end

    def symbolic_name = details.symbolic_name
    def named? = !symbolic_name.nil?

    def required_symbolic_name
      symbolic_name or raise ArgumentError, 'This relationship needs a symbolic name (use `named`) to be referenced.'
    end

    def named(name) = with_details(symbolic_name: SymbolicName.of(name))

    def with_properties(*keys_and_values) = with_details(properties: MapExpression.of(*keys_and_values))
    alias properties with_properties

    def min(minimum) = with_details(min: minimum)
    def max(maximum) = with_details(max: maximum)
    def length(minimum, maximum) = with_details(min: minimum, max: maximum)
    def unbounded = with_details(unbounded: true)

    def property(*names) = Property.new(required_symbolic_name, names)

    # `r += {…}`, for use in SET.
    def mutate(expression) = Operation.new(self, '+=', Expression.coerce(expression))

    # The map projection `r{…}`.
    def project(*entries) = MapProjection.new(self, entries.flatten)

    def relationship_to(other, *types) = RelationshipChain.new([self]).relationship_to(other, *types)
    def relationship_from(other, *types) = RelationshipChain.new([self]).relationship_from(other, *types)
    def relationship_between(other, *types) = RelationshipChain.new([self]).relationship_between(other, *types)

    private

    def with_details(**changes)
      Relationship.new(left, direction, right, details.with(**changes))
    end
  end
end
