# frozen_string_literal: true

module CypherDSL
  # Raised when one parameter name is bound to different values within a
  # statement, or bound in one place and left unbound in another.
  class ConflictingParametersException < StandardError
    # `name => Set` of the conflicting values; an unbound use is {Parameter::NO_VALUE}.
    attr_reader :erroneous_parameters

    def initialize(erroneous_parameters)
      @erroneous_parameters = erroneous_parameters.freeze
      super("Conflicting parameter values for #{erroneous_parameters.keys.join(', ')}")
    end
  end
end
