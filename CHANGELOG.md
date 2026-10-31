# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
