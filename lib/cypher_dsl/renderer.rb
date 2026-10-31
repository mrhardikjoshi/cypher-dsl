# frozen_string_literal: true

module CypherDSL
  # Turns a {Statement} into Cypher text according to a {Renderer::Configuration}.
  class Renderer
    def self.default = @default ||= new(Configuration::DEFAULT)

    # Mirrors `Renderer.getRenderer(configuration)`.
    def self.get_renderer(configuration) = new(configuration)

    attr_reader :configuration

    def initialize(configuration)
      @configuration = configuration
      freeze
    end

    def render(statement) = "#{configuration.prefix}#{Visitor.new(configuration).render(statement)}"

    # The statement's parameters as a {StatementCatalog}; raises
    # {ConflictingParametersException} when a name is bound inconsistently.
    def catalog(statement)
      visitor = Visitor.new(configuration)
      visitor.render(statement)
      visitor.catalog
    end
  end
end
