# frozen_string_literal: true

module CypherDSL
  # `Cypher.call('db.labels')`: a procedure call being built. `with_args` adds
  # arguments, `yield` selects outputs and continues as a statement builder,
  # `build` finishes a bare call, `as_function` turns it into a function
  # invocation instead.
  class StandaloneCall
    AGGREGATES = %w[avg collect count max min percentilecont percentiledisc stdev stdevp sum].freeze

    attr_reader :name_parts, :arguments

    # `name_parts` as given to `Cypher.call`: strings, symbols or arrays, dotted names split.
    def initialize(name_parts, arguments: [], builder: nil)
      @name_parts = name_parts.flatten.flat_map { |part| part.to_s.split('.') }.freeze
      @arguments = arguments.freeze
      @builder = builder
      freeze
    end

    def procedure_name = name_parts.join('.')

    def with_args(*expressions)
      StandaloneCall.new(name_parts, arguments: expressions.flatten.map { |e| Expression.coerce(e) }, builder: @builder)
    end

    # `YIELD item, item AS alias, …`; continues as a statement builder.
    def yield(*items)
      yield_items = items.flatten.map { |item| yield_item(item) }
      (@builder || StatementBuilder.new).send(:append, clause(yield_items), :condition)
    end

    def build = Statement.new((@builder&.send(:clauses) || []) + [clause([])])

    # The procedure as a function invocation; `distinct` only for aggregates.
    def as_function(distinct = false) # rubocop:disable Style/OptionalBooleanParameter
      if distinct && !AGGREGATES.include?(procedure_name.downcase)
        raise ArgumentError, 'The distinct operator can only be applied within aggregate functions.'
      end

      FunctionInvocation.new(procedure_name, arguments, distinct:)
    end

    private

    def clause(yield_items)
      Clauses::Call.new(name_parts:, arguments:, yield_items: yield_items.freeze, where: nil)
    end

    def yield_item(item)
      case item
      when String, Symbol then SymbolicName.of(item)
      when SymbolicName, AliasedExpression then item
      else raise ArgumentError, "Cannot yield #{item.inspect}"
      end
    end
  end
end
