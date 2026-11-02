# Working conventions for cypher-dsl (Ruby)

## What this is

A Ruby implementation of the *design* of Neo4j's Cypher-DSL for Java, not a
line-by-line port. The reference source is a full clone of the Java project at
`~/projects/cypher-dsl-java` (module `neo4j-cypher-dsl`, package
`org.neo4j.cypherdsl.core`). Read it for semantics; write idiomatic Ruby.

## Method: tests first, translated from upstream

- Specs are translated from
  `neo4j-cypher-dsl/src/test/java/org/neo4j/cypherdsl/core/*.java`, feature
  group by feature group (the nested classes of `CypherIT.java` are the map).
  Keep the expected Cypher strings **verbatim**; they are the contract.
- One spec file per upstream test class or nested group, named after it
  (`CypherIT` → `spec/cypher_dsl/cypher_it/<nested_group>_spec.rb`). The
  `describe` string keeps the upstream class names (`'CypherIT / Conditions'`).
- Example names are the upstream test method names split into lowercase
  words, with a leading "should" dropped as RSpec style wants:
  `shouldRenderMergeWithoutReturn` → `it 'renders merge without return'`,
  `unrelatedNodes` → `it 'unrelated nodes'`. That reads like RSpec and still
  maps one to one onto the Java test.
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

## Releasing (pre-releases on rubygems.org)

Work happens directly on `main`. For a release:

1. Bump `lib/cypher_dsl/version.rb` and the install line in `README.md`.
2. Move the `[Unreleased]` entries of `CHANGELOG.md` into a dated version
   section and update the compare links at the bottom.
3. `bundle install` (the lockfile is gitignored), `bundle exec rspec`,
   `gem build cypher-dsl.gemspec`.
4. Commit as `chore(release): vX.Y.Z`, push `main`, push an annotated tag
   `vX.Y.Z`, wait for CI.
5. The maintainer pushes the `.gem` to rubygems.org themselves (MFA). Never
   run `gem push`.

## Status and roadmap

- Translated and green: `CypherIT` (all nested groups), `ProcedureCalls`,
  `Subqueries` (+ GQL), `ParameterIT`, `IssueRelatedIT` 1–6, `FunctionsIT`,
  `HintsIT`, `LoadCSVIT`, `DialectIT`, `UseIT`, `ExpressionsIT`,
  `IdentifiableExpressionsIT`, `Cypher5IT`, `LabelsTests`, `SearchTests`,
  `VectorTests`, `ConfigurableRendererTests` and the small unit-test classes
  (literals, escaping, preconditions, `to_s`, visitors).
- Deliberately not ported: `DurationLiteralTests` (no Ruby duration type),
  `TreeNode`, `BuiltInFunctions`, `PackageAndAPIStructure`,
  `ReflectiveVisitor`, `ForeignAdapter` and the QueryDSL adapter. The
  `StatementCatalog` exposes only parameters and identifiable expressions
  (no labels/properties/filters/relations/literals catalog).
- Design choice that differs from Java: `nil` arguments coerce to the `NULL`
  literal instead of raising.
- Ruby-only additions exist for host DSLs that still build strings:
  `Cypher.raw` as pattern element / condition / SET operation,
  `StatementBuilder#raw_clause`, `Renderer#render_fragment`,
  `ConflictingParametersException` carrying `{name => Set[values]}`.
- Main consumer: [activegraph](https://github.com/neo4jrb/activegraph)
  (`ActiveGraph::Core::Query`, `QueryProxy`, association patterns) since its
  PR #1753, requiring `>= 0.1.0.alpha.3`. Keep those entry points stable.
- Open follow-ups activegraph needs before it can drop its last string
  templates:
  - a whole-map parameter as pattern properties, `CREATE (n:Label $props)`
    (`MapExpression.of` rejects a lone `Parameter`, as Java does; needs a
    deliberate extension);
  - AST-level renaming of parameters so union / `CALL {}` branches built
    independently can be merged without text substitution;
  - schema DDL (constraints, indexes) has no model at all.

## Licensing

Ruby code is MIT. Translated specs are a derivative of Apache-2.0 code: keep
`NOTICE` accurate and do not copy Java *implementation* code verbatim.
