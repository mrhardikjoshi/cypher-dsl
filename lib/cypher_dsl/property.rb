# frozen_string_literal: true

module CypherDSL
  # A property lookup such as `n.name` or `n.address.city`.
  class Property
    include Expression

    attr_reader :container, :names

    def initialize(container, names)
      @container = container
      @names = names.map(&:to_s).freeze
      raise ArgumentError, 'A property needs at least one name.' if @names.empty?

      freeze
    end

    # `n.prop = value`, for use in SET.
    def to(expression) = Operation.new(self, '=', Expression.coerce(expression))
  end
end
