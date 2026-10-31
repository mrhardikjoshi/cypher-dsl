# frozen_string_literal: true

module CypherDSL
  # What a statement uses: its parameter names, and the values of the
  # parameters that carry one. Built from a rendering pass.
  class StatementCatalog
    attr_reader :parameters, :parameter_names, :renamed_parameters

    # `uses` maps each parameter name to every value it was given, in render
    # order, with {Parameter::NO_VALUE} for unbound uses.
    def self.from_uses(uses, renamed_parameters = {})
      conflicts = uses.filter_map { |name, values| [name, values.uniq.to_set] if values.uniq.size > 1 }.to_h
      raise ConflictingParametersException, conflicts unless conflicts.empty?

      bound = uses.filter_map { |name, values| [name, values.first] unless values.first.equal?(Parameter::NO_VALUE) }
      new(parameters: bound.to_h, parameter_names: uses.keys, renamed_parameters:)
    end

    # `renamed_parameters` maps original names to generated ones when the renderer rewrites them.
    def initialize(parameters:, parameter_names:, renamed_parameters: {})
      @parameters = parameters.freeze
      @parameter_names = parameter_names.freeze
      @renamed_parameters = renamed_parameters.freeze
      freeze
    end
  end
end
