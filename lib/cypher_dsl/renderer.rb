# frozen_string_literal: true

module CypherDSL
  # Turns a {Statement} into Cypher text according to a {Renderer::Configuration}.
  class Renderer
    def self.default = @default ||= new(Configuration.default)

    # The default configuration without forced escaping; used by `to_s` on expressions and patterns.
    def self.plain = @plain ||= new(Configuration.new(always_escape_names: false))

    # Mirrors `Renderer.getRenderer(configuration)`.
    def self.get_renderer(configuration) = new(configuration)

    attr_reader :configuration

    def initialize(configuration)
      @configuration = configuration
      freeze
    end

    def render(statement) = "#{configuration.prefix}#{Visitor.new(configuration).render(statement)}"

    # Renders a part of a statement on its own: an expression, a pattern, a clause or a {Search}.
    def render_fragment(fragment) = Visitor.new(configuration).render_fragment(fragment)

    # The statement's parameters and identifiable expressions as a {StatementCatalog};
    # raises {ConflictingParametersException} when a name is bound inconsistently.
    def catalog(statement)
      visitor = Visitor.new(configuration)
      visitor.render(statement)
      visitor.catalog(statement)
    end
  end
end
