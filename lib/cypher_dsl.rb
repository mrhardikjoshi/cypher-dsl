# frozen_string_literal: true

require 'zeitwerk'

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect('cypher_dsl' => 'CypherDSL')
loader.setup

# A Ruby DSL for building Cypher statements.
#
# The entry point is {CypherDSL::Cypher}; everything else is reached from there.
module CypherDSL
end
