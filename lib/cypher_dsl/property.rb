# frozen_string_literal: true

module CypherDSL
  # A property lookup such as `n.name`, `n.address.city`, or the dynamic `n[$key]`.
  # Names are strings; an expression as a name renders as an index lookup.
  class Property
    include Expression

    attr_reader :container, :names

    def initialize(container, names)
      @container = container
      @names = names.map { |name| name.is_a?(Expression) ? name : name.to_s }.freeze
      raise ArgumentError, 'A property needs at least one name.' if @names.empty?

      freeze
    end

    def nested? = names.size > 1

    # `n.prop = value`, for use in SET.
    def to(expression) = Operation.new(self, '=', Expression.coerce(expression))
  end
end
