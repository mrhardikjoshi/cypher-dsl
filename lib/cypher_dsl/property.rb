# frozen_string_literal: true

module CypherDSL
  # A property lookup such as `n.name`, `n.address.city`, or the dynamic `n[$key]`.
  # Names are strings; an expression as a name renders as an index lookup.
  class Property
    include Expression

    attr_reader :container, :names, :external_reference

    def initialize(container, names, external_reference: nil)
      @container = container
      @names = names.map { |name| name.is_a?(Expression) ? name : name.to_s }.freeze
      raise ArgumentError, 'A property needs at least one name.' if @names.empty?

      @external_reference = external_reference
      freeze
    end

    def nested? = names.size > 1

    # The dotted name (`address.city`), or the external reference if one was given.
    def name = external_reference || names.join('.')

    # The same property known under another name, e.g. the attribute it maps to.
    def referenced_as(reference) = Property.new(container, names, external_reference: reference.to_s)

    # `n.prop = value`, for use in SET.
    def to(expression) = Operation.new(self, '=', Expression.coerce(expression))
  end
end
