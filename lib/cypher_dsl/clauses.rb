# frozen_string_literal: true

module CypherDSL
  # Factory methods for clause objects, mirroring the Java `Clauses` class. Most
  # code goes through the {StatementBuilder}; these exist for building clause
  # lists by hand, e.g. the body of a FOREACH.
  module Clauses
    UPDATING_MESSAGE = 'Only updating clauses SET, REMOVE, CREATE, MERGE, DELETE, and FOREACH are allowed as ' \
                       'clauses applied inside FOREACH.'

    # True for any clause object.
    def self.clause?(object) = constants.any? { |name| (type = const_get(name)).is_a?(Class) && object.is_a?(type) }

    # True for the clauses allowed inside FOREACH.
    def self.updating?(clause) = [Set, Remove, Create, Merge, Delete, Foreach].any? { |type| clause.is_a?(type) }

    module_function

    def for_each(variable, list, clauses)
      raise ArgumentError, UPDATING_MESSAGE unless clauses.all? { |clause| Clauses.updating?(clause) }

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
