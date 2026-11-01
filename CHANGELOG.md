# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Planner hints: `using_index`, `using_index_seek`, `using_scan`, `using_join_on` (HintsIT).
- LOAD CSV: `with_field_terminator`, `Cypher.using_periodic_commit`, `linenumber()`, `file()`.
- All Java dialects including `NEO4J_5_26`, `NEO4J_5_CYPHER_5`, `NEO4J_5_CYPHER_25` with their
  `CYPHER 5` / `CYPHER 25` prefixes; `NEO4J_5_DEFAULT_CYPHER` is the default.
- Label expressions (`Labels.exactly/all/any`, `and`, `or`, `negate`, `conjunction_with`),
  dynamic labels `n:$($labels)` on Neo4j 5.26+, `disable_dynamic_labels`.
- Vector `SEARCH` clauses (`Cypher.search`) and `Cypher.vector` literals.
- Generated names (`with_generated_names`) and `StatementCatalog#renamed_parameters`.
- `Cypher.exists(property)` renders `exists()` on Neo4j 4 and `IS NOT NULL` afterwards;
  `shortestPath()` / `allShortestPaths()` on Neo4j 4 and 5.
- `StatementCatalog#identifiable_expressions`: the items of the final `RETURN` or `YIELD`
  (SubqueriesGQLIT).

### Fixed

- Node and relationship names that need quoting (e.g. containing a backtick) are now
  escaped inside patterns, not only where they are used as expressions.

### Changed

- The default dialect is `NEO4J_5_DEFAULT_CYPHER` (was `NEO4J_5_23`); the only difference
  is that dynamic label expressions render as such.

## [0.1.0.alpha.1] - 2026-10-31

First pre-release, reserving the gem name. A Ruby reimplementation of the design of
[Neo4j's Cypher-DSL for Java](https://github.com/neo4j/cypher-dsl), built test-first from
specs translated from its test suite (CypherIT, ProcedureCalls, Subqueries, parameter
collection, IssueRelatedIT, FunctionsIT).

### Added

- Immutable statement builder with MATCH/OPTIONAL MATCH, WHERE, WITH, RETURN, ORDER BY,
  SKIP/LIMIT, UNWIND, CREATE, MERGE (ON CREATE/ON MATCH), SET, REMOVE, DELETE, FOREACH,
  CALL procedures (YIELD, YIELD *), CALL subqueries (imports, IN TRANSACTIONS), LOAD CSV,
  USE, UNION/UNION ALL, FINISH, EXPLAIN/PROFILE.
- Patterns: nodes, relationships, chains, named paths, quantified path patterns,
  path selectors, label expressions.
- Expressions: literals, parameters, maps, lists, map projections, list and pattern
  comprehensions, list predicates, CASE, reduce(), EXISTS/COUNT/COLLECT subquery
  expressions, the built-in function catalogue.
- Renderer with dialects (Neo4j 4, 5, 5.23+), pretty printing, identifier escaping,
  parameter collection (`Statement#catalog`).

[Unreleased]: https://github.com/neo4jrb/cypher-dsl/compare/v0.1.0.alpha.1...HEAD
[0.1.0.alpha.1]: https://github.com/neo4jrb/cypher-dsl/releases/tag/v0.1.0.alpha.1
