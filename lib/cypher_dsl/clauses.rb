# frozen_string_literal: true

module CypherDSL
  # Factory methods for clause objects, mirroring the Java `Clauses` class. Most
  # code goes through the {StatementBuilder}; these exist for building clause
  # lists by hand, e.g. the body of a FOREACH.
  module Clauses
    module_function

    def for_each(variable, list, clauses)
      Foreach.new(variable: SymbolicName.of(variable), list: Expression.coerce(list), clauses: clauses.freeze)
    end

    def merge(pattern_elements, actions = [])
      Merge.new(pattern_elements: pattern_elements.freeze, actions: actions.freeze)
    end

    def set(operations) = Set.new(operations: operations.freeze)
    def remove(items) = Remove.new(items: items.freeze)

    def delete(detach, expressions)
      Delete.new(detach:, expressions: expressions.map { |e| Expression.coerce(e) }.freeze)
    end
  end
end
