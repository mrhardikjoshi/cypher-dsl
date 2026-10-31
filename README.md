# cypher-dsl

A Ruby DSL (builder) for the [Cypher](https://neo4j.com/docs/cypher-manual/current/)
query language, modelled on the design of Neo4j's
[Cypher-DSL for Java](https://github.com/neo4j/cypher-dsl).

**Status: early development.** The API is being built test-first against
specifications translated from the Java project's test suite, so rendered
output is meant to match Cypher-DSL byte for byte.

## Design

- **Immutable AST.** Every builder call returns a new object; a built
  `Statement` is a frozen tree that can be rendered, inspected or transformed.
- **Part-aware builder.** Cypher is a linear sequence of parts chained by
  `WITH`, and clauses keep the order you wrote them. The builder's states
  mirror which clause may follow which, exactly as the Java `StatementBuilder`
  does.
- **Rendering is separate from the tree.** A `Renderer` turns a `Statement` into
  Cypher text and collects parameters; options such as identifier escaping and
  pretty printing live in a `Configuration`.
- **Names follow the Java API in snake_case**, so examples and tests from the
  Java project translate mechanically:

  ```ruby
  include CypherDSL

  statement = Cypher.match(Cypher.node('S1').named(:n))
    .where(Cypher.property(:n, :a).is_equal_to(Cypher.literal_of('A')))
    .with(:n)
    .match(Cypher.any_node(:n).relationship_to(Cypher.node('S2').named(:m), 'SOMEHOW_RELATED'))
    .returning(:n, :m)
    .build

  statement.cypher
  # => "MATCH (n:`S1`) WHERE n.a = 'A' WITH n MATCH (n)-[:`SOMEHOW_RELATED`]->(m:`S2`) RETURN n, m"
  ```

- **No ActiveSupport.** The only runtime dependency is Zeitwerk.

## Installation

```ruby
gem 'cypher-dsl'
```

Requires Ruby 3.4 or newer.

## Licence

The Ruby source is MIT licensed (see `LICENSE.txt`). The specifications are
translated from Cypher-DSL's Apache-2.0 test suite; see `NOTICE`.
