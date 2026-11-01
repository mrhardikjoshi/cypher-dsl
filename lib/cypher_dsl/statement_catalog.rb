# frozen_string_literal: true

module CypherDSL
  # What a statement uses: its parameter names, the values of the parameters
  # that carry one, and the expressions it hands back. Built from a rendering pass.
  class StatementCatalog
    attr_reader :parameters, :parameter_names, :renamed_parameters, :identifiable_expressions

    # `uses` maps each parameter name to every value it was given, in render
    # order, with {Parameter::NO_VALUE} for unbound uses.
    def self.from_uses(uses, renamed_parameters = {}, statement: nil)
      conflicts = uses.filter_map { |name, values| [name, values.uniq.to_set] if values.uniq.size > 1 }.to_h
      raise ConflictingParametersException, conflicts unless conflicts.empty?

      bound = uses.filter_map { |name, values| [name, values.first] unless values.first.equal?(Parameter::NO_VALUE) }
      new(parameters: bound.to_h, parameter_names: uses.keys, renamed_parameters:,
          identifiable_expressions: identifiable_expressions_of(statement))
    end

    # The expressions a statement hands back to its caller: the items of its
    # final RETURN (names for aliased items and named entities), or the names a
    # bare procedure call yields. Empty for a statement without result.
    def self.identifiable_expressions_of(statement)
      case statement
      when UnionQuery then statement.statements.flat_map { |part| identifiable_expressions_of(part) }.uniq
      when Statement then result_items_of(statement.clauses.last).filter_map { |item| identifiable_expression(item) }
      else []
      end
    end

    def self.result_items_of(clause)
      case clause
      when Clauses::Return then clause.items
      when Clauses::Call then clause.yield_items
      else []
      end
    end
    private_class_method :result_items_of

    def self.identifiable_expression(item)
      case item
      when AliasedExpression then item.alias_name
      when Node, Relationship then item.symbolic_name
      when Asterisk then nil
      else item
      end
    end
    private_class_method :identifiable_expression

    # `renamed_parameters` maps original names to generated ones when the renderer rewrites them.
    def initialize(parameters:, parameter_names:, renamed_parameters: {}, identifiable_expressions: [])
      @parameters = parameters.freeze
      @parameter_names = parameter_names.freeze
      @renamed_parameters = renamed_parameters.freeze
      @identifiable_expressions = identifiable_expressions.freeze
      freeze
    end
  end
end
