# Working conventions for cypher-dsl (Ruby)

## What this is

A Ruby implementation of the *design* of Neo4j's Cypher-DSL for Java, not a
line-by-line port. The reference source is a full clone of the Java project at
`~/projects/cypher-dsl` (module `neo4j-cypher-dsl`, package
`org.neo4j.cypherdsl.core`). Read it for semantics; write idiomatic Ruby.

## Method: tests first, translated from upstream

- Specs are translated from
  `neo4j-cypher-dsl/src/test/java/org/neo4j/cypherdsl/core/*.java`, feature
  group by feature group (the nested classes of `CypherIT.java` are the map).
  Keep the expected Cypher strings **verbatim**; they are the contract.
- One spec file per upstream test class or nested group, named after it
  (`CypherIT` → `spec/cypher_dsl/cypher_it/<nested_group>_spec.rb`).
- Record what was skipped and why at the top of each spec file (Java-only
  constructs, QueryDSL adapter, native tests, etc.).

## API rules

- Public names mirror the Java API in snake_case: `Cypher.node`, `.named`,
  `.relationship_to`, `.is_equal_to`, `.returning`, `.build`. Add Ruby sugar
  (`==`, `>`, `&`) only as aliases on top, never instead.
- Symbols and Strings are interchangeable for names; the renderer normalises.
- Everything is immutable: builder methods return new objects, `Statement`
  and all AST nodes are frozen.
- Rendering defaults match Cypher-DSL: identifiers are backtick-escaped
  (`(n:`Person`)`), literals render inline, parameters only when asked for.
  Both are `Renderer::Configuration` options.
- Runtime dependency is Zeitwerk only. No ActiveSupport.
- Zeitwerk one-class-per-file; constant `CypherDSL` is an inflection.

## Commits and releases

- Conventional Commits for every commit and PR title; PRs are squash-merged.
- `feat`/`fix`/`perf` appear in the changelog; `chore`, `docs`, `test`,
  `refactor`, `ci` do not.
- Never merge PRs; the maintainer merges.

## Licensing

Ruby code is MIT. Translated specs are a derivative of Apache-2.0 code: keep
`NOTICE` accurate and do not copy Java *implementation* code verbatim.
