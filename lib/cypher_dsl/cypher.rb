# frozen_string_literal: true

module CypherDSL
  # The main entry point of the DSL. Mirrors the static factory methods of the
  # Java `org.neo4j.cypherdsl.core.Cypher` class in snake_case.
  module Cypher
    module_function

    # --- pattern elements ------------------------------------------------

    # A node with one primary label and optional additional labels.
    def node(primary_label, *additional_labels)
      Node.new(labels: [primary_label, *additional_labels].map(&:to_s))
    end

    # A node without labels, optionally named.
    def any_node(name = nil)
      node = Node.new(labels: [])
      name ? node.named(name) : node
    end

    # --- names, properties, parameters -----------------------------------

    def name(value) = SymbolicName.of(value)

    # `Cypher.property(:n, :name)` → `n.name`; the container may also be an expression.
    def property(container, *names)
      container = SymbolicName.of(container) unless container.is_a?(Expression)
      Property.new(container, names.map(&:to_s))
    end

    def parameter(name) = Parameter.new(name)

    # --- literals --------------------------------------------------------

    # Wraps a Ruby value as a literal; expressions pass through unchanged.
    def literal_of(value) = Literal.of(value)

    def literal_true = Literal::TRUE
    def literal_false = Literal::FALSE
    def literal_null = Literal::NULL

    def map_of(*keys_and_values) = MapExpression.of(*keys_and_values)

    def asterisk = Asterisk::INSTANCE

    # --- sorting and functions --------------------------------------------

    def sort(expression) = SortItem.new(Expression.coerce(expression), nil)

    def size(expression_or_pattern) = FunctionInvocation.new('size', [expression_or_pattern])

    # --- statement builders -----------------------------------------------

    def match(*pattern_elements) = StatementBuilder.new.match(*pattern_elements)
    def optional_match(*pattern_elements) = StatementBuilder.new.optional_match(*pattern_elements)
    def returning(*expressions) = StatementBuilder.new.returning(*expressions)
    def returning_distinct(*expressions) = StatementBuilder.new.returning_distinct(*expressions)
  end
end
