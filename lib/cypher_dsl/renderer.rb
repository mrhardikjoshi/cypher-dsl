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

    def render(statement) = Visitor.new(configuration).render(statement)
  end
end
