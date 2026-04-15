# Development Plan for an R Package Providing a Tidy Lazy Backend for MongoDB

## 1. Purpose

This document describes a development plan for an R package that provides a `dplyr`-style, lazy analytical interface for MongoDB collections, using `mongolite` as the execution layer.

The goal is not to extend or integrate with `dbplyr` directly. `dbplyr` is used only as architectural inspiration: a lazy pipeline representation, delayed execution, query inspection, and predictable verb translation. The package should instead implement a native MongoDB-oriented backend that translates a disciplined subset of `dplyr` pipelines into MongoDB aggregation pipelines.

The intended outcome is a package that allows users to write idiomatic analytical code such as:

```r
tbl_mongo(conn, "collection") |>
  filter(x > 0, category != "A") |>
  mutate(z = x * 2) |>
  group_by(group) |>
  summarise(n = n(), avg_z = mean(z, na.rm = TRUE)) |>
  arrange(group) |>
  collect()
```

without manually constructing JSON queries.

---

## 2. Strategic Assessment

## 2.1 Feasibility

The package is feasible.

MongoDB's aggregation framework is expressive enough to support a useful analytical subset of `dplyr`, especially for read-only workflows over flat or moderately structured collections. The main value of the package would be to replace manual JSON construction with:

- lazy query composition,
- tidy evaluation,
- predictable translation,
- query introspection,
- explicit constraints and failure modes.

## 2.2 Why This Is Not a Full `dbplyr` Equivalent

A MongoDB backend cannot realistically reproduce the full semantics of SQL-oriented backends.

The key reasons are:

- MongoDB stores documents rather than rectangular tables.
- Schemas may be heterogeneous across documents.
- Nested objects and arrays are normal rather than exceptional.
- Some relational semantics do not map cleanly, or do so only with substantial complexity.
- Expression translation is nontrivial and requires a compiler from R expressions to MongoDB aggregation expressions.

Therefore, the realistic and useful goal is:

> a native tidy lazy backend for a clearly defined analytical subset of MongoDB collections and `dplyr` verbs.

## 2.3 Product Positioning

The package should target analysts and R developers who:

- already use MongoDB,
- already use `mongolite`,
- want a tidy, lazy interface for analytical querying,
- accept a documented supported subset rather than full compatibility.

The package should **not** initially target:

- write/update/delete workflows,
- general ODM-style object mapping,
- arbitrary schema normalization,
- full support for nested arrays and deeply irregular documents,
- automatic support for all `dplyr` verbs.

---

## 3. Product Definition

## 3.1 Core Objective

Provide a lazy tibble-like object backed by a MongoDB collection, with execution deferred until `collect()`, `compute()`, `count()`, or equivalent terminal operations.

## 3.2 Initial Scope

Version 0.1 should support a narrowly defined MVP:

- `tbl_mongo()`
- `collect()`
- `show_query()`
- `filter()`
- `select()`
- `rename()`
- `mutate()`
- `transmute()`
- `arrange()`
- `group_by()`
- `summarise()`
- `slice_head()` or equivalent limit support
- `head()`

Supported expression families should include:

- column references,
- literals,
- comparison operators,
- boolean operators,
- arithmetic operators,
- a small set of scalar numeric functions,
- `if_else()`,
- `case_when()`,
- `is.na()`,
- common aggregate functions.

## 3.3 Explicit Non-Goals for MVP

The package should explicitly exclude the following in the initial release:

- joins,
- window functions,
- rowwise operations,
- `across()` support,
- tidyr-style reshaping,
- automatic unnesting of arrays,
- writes and updates,
- DBI backend compatibility,
- automatic client-side fallback for unsupported operations.

---

## 4. Technical Principles

## 4.1 Native Backend, Not SQL Emulation

The package should not emulate SQL or generate SQL-like intermediate representations.

Instead, it should:

1. capture `dplyr` operations lazily,
2. translate them into an internal query representation,
3. compile that representation into MongoDB aggregation pipeline stages,
4. execute via `mongolite`.

## 4.2 Internal Intermediate Representation

A dedicated internal IR should be introduced between the user-facing API and the MongoDB pipeline compiler.

This is critical.

Directly translating each verb into raw MongoDB JSON or lists will quickly become difficult to test and maintain. An IR makes it easier to:

- validate semantics,
- reorder or merge stages when appropriate,
- optimize compilation,
- test translation independently of execution,
- extend support incrementally.

## 4.3 Strict Failure Rather Than Silent Fallback

Unsupported operations should fail with clear diagnostic messages.

Example principle:

- If an expression cannot be translated to MongoDB, error explicitly.
- Do not silently `collect()` and continue locally unless the user has explicitly requested such behavior.

This is important for correctness, performance, and predictability.

## 4.4 Conservative Semantics

The package should adopt conservative semantics in ambiguous cases.

Examples:

- require explicit handling of nested or missing fields,
- document differences in `NA`/`NULL` behavior,
- document ordering assumptions,
- avoid implicit coercions where possible.

---

## 5. Proposed Architecture

## 5.1 Layer 1: Connection and Source Objects

This layer wraps `mongolite::mongo()` and collection metadata.

Suggested responsibilities:

- hold connection object,
- hold collection name,
- optionally infer schema from samples,
- expose source metadata,
- track package options such as schema sampling size or translation strictness.

Suggested object model:

- `mongo_src`: source-level metadata and connection wrapper,
- `tbl_mongo`: lazy query object presented to users.

## 5.2 Layer 2: Lazy Query Object

A `tbl_mongo` object should store:

- source collection,
- selected fields,
- computed expressions,
- filter predicates,
- grouping variables,
- summary expressions,
- sort specification,
- limit/skip,
- projection requirements,
- pipeline cache if needed.

This object should remain purely declarative until execution.

## 5.3 Layer 3: Expression Translator

A recursive translator should convert R quosures into MongoDB expression trees.

This translator will be the core compiler component.

It should support two broad translation modes:

- predicate translation for `$match`,
- expression translation for `$project`, `$addFields`, `$group`, and related stages.

## 5.4 Layer 4: Pipeline Compiler

The compiler should transform the internal IR into a MongoDB aggregation pipeline, represented as R lists suitable for `mongolite`.

Typical stage mapping:

- `filter()` -> `$match`
- `select()` -> `$project`
- `mutate()` -> `$addFields` or `$project`
- `arrange()` -> `$sort`
- `group_by()` + `summarise()` -> `$group`
- `slice_head()` / `head()` -> `$limit`

## 5.5 Layer 5: Execution Layer

This layer should:

- serialize the compiled pipeline,
- execute it through `mongolite`,
- return a tibble,
- optionally provide diagnostics or explain plans.

---

## 6. Recommended Package Structure

A reasonable package structure is:

```text
R/
  tbl_mongo.R
  mongo_src.R
  verbs-filter.R
  verbs-select.R
  verbs-mutate.R
  verbs-group-summarise.R
  verbs-arrange.R
  collect.R
  show_query.R
  translate-expr.R
  translate-predicate.R
  translate-agg.R
  compile-pipeline.R
  schema.R
  utils.R

tests/testthat/
  test-tbl_mongo.R
  test-translate-predicate.R
  test-translate-expr.R
  test-translate-agg.R
  test-compile-pipeline.R
  test-semantics-flat.R
  test-semantics-missing-fields.R
  test-semantics-nested.R

inst/
  schemas/
  examples/
```

---

## 7. Supported Semantics Matrix

A support matrix should be maintained from the beginning.

Example categories:

### Fully supported in MVP
- `filter()`
- `select()`
- `rename()`
- `mutate()` with simple scalar expressions
- `arrange()`
- `group_by()`
- `summarise()` with basic aggregates
- `collect()`
- `show_query()`

### Supported with caveats
- missing fields,
- dot-notation access,
- date handling,
- string predicates,
- `case_when()`,
- `if_else()`.

### Not supported in MVP
- joins,
- window functions,
- arbitrary list-column operations,
- reshaping,
- rowwise computation,
- `nest()` / `unnest()`,
- `across()`.

This matrix should be part of the package documentation and enforced in tests.

---

## 8. Agentic Development Plan

The project is well suited to agentic development if the work is decomposed into small, testable tasks with explicit interfaces and acceptance criteria.

The recommended model is:

- one agent responsible for architecture and coordination,
- one or more implementation agents,
- one testing/verification agent,
- optional documentation agent.

## 8.1 Global Rules for Agents

All agents should follow these rules:

1. Do not broaden scope beyond the current milestone.
2. Prefer explicit errors over speculative support.
3. Add or update tests for every semantic addition.
4. Preserve lazy semantics.
5. Avoid introducing client-side fallback.
6. Keep translation logic separate from execution.
7. Keep expression translation pure and testable.

## 8.2 Agent Roles

### Agent A: Architecture and API
Responsibilities:
- define object model,
- define public constructor and core methods,
- maintain internal IR contract,
- review semantic consistency.

Deliverables:
- `tbl_mongo()` API,
- IR specification,
- package-level design notes.

### Agent B: Verb Translation
Responsibilities:
- implement verb capture and IR updates,
- maintain verb-specific files,
- ensure translation remains lazy.

Deliverables:
- `filter.tbl_mongo`
- `select.tbl_mongo`
- `mutate.tbl_mongo`
- `arrange.tbl_mongo`
- `group_by.tbl_mongo`
- `summarise.tbl_mongo`

### Agent C: Expression Compiler
Responsibilities:
- recursive quosure translation,
- predicate translation,
- aggregate translation,
- unsupported-expression diagnostics.

Deliverables:
- translator modules,
- scalar function mapping,
- aggregate function mapping,
- detailed error messages.

### Agent D: Pipeline Compiler and Execution
Responsibilities:
- convert IR to Mongo pipeline,
- execute through `mongolite`,
- implement `collect()` and `show_query()`.

Deliverables:
- `compile_pipeline()`
- `collect.tbl_mongo()`
- `show_query.tbl_mongo()`

### Agent E: Testing and Validation
Responsibilities:
- translation unit tests,
- semantic regression tests,
- edge-case fixtures,
- test coverage monitoring.

Deliverables:
- test suite,
- golden pipeline snapshots,
- semantic comparisons versus local data frames where applicable.

### Agent F: Documentation
Responsibilities:
- supported semantics matrix,
- package vignettes,
- examples,
- failure-mode documentation.

Deliverables:
- README,
- introductory vignette,
- translation reference,
- limitations guide.

---

## 9. Milestone Plan

## Milestone 0: Technical Spike

### Objective
Demonstrate that a simple end-to-end translation is viable.

### Required output
A prototype that converts a hard-coded `dplyr`-like sequence into a MongoDB aggregation pipeline and runs it.

### Example target
Translate a pipeline equivalent to:

```r
filter(x > 0) |>
mutate(z = x * 2) |>
group_by(g) |>
summarise(n = n(), mx = max(z))
```

### Acceptance criteria
- pipeline compiles successfully,
- pipeline executes via `mongolite`,
- output matches expectations on a known fixture,
- unsupported constructs fail explicitly.

### Assigned agents
- Agent A
- Agent C
- Agent D

---

## Milestone 1: Core Object Model and Query IR

### Objective
Build the foundational lazy object system.

### Tasks
- define `mongo_src`,
- define `tbl_mongo`,
- define print methods,
- define IR structure,
- define update rules for verbs.

### Acceptance criteria
- `tbl_mongo()` creates a valid lazy object,
- object stores source and query state cleanly,
- object can be printed and inspected,
- IR remains stable across chained operations.

### Risks
- overfitting IR to current verbs,
- leaking Mongo-specific details too early into verb APIs.

---

## Milestone 2: Basic Verb Support

### Objective
Support the most common projection, filtering, sorting, and limiting operations.

### Tasks
- implement `filter()`,
- implement `select()`,
- implement `rename()`,
- implement `mutate()` for simple scalar expressions,
- implement `arrange()`,
- implement limit/head support.

### Acceptance criteria
- pipelines remain lazy,
- compiled Mongo stages are correct,
- `collect()` returns a tibble,
- unit tests cover common cases.

### Notes
This milestone should work on flat collections only.

---

## Milestone 3: Grouping and Aggregation

### Objective
Support grouped summaries.

### Tasks
- implement `group_by()`,
- implement `summarise()`,
- support aggregate translators:
  - `n()`
  - `sum()`
  - `mean()`
  - `min()`
  - `max()`

### Acceptance criteria
- grouping metadata stored correctly,
- `$group` compilation correct,
- aggregation results match reference outputs,
- unsupported summaries error clearly.

### Risks
- handling `na.rm`,
- mixed-type fields,
- ambiguity around missing fields.

---

## Milestone 4: Query Introspection and Diagnostics

### Objective
Make the backend inspectable and debuggable.

### Tasks
- implement `show_query()`,
- pretty-print pipeline stages,
- improve error messages,
- optionally add `explain()` support.

### Acceptance criteria
- users can inspect generated pipelines,
- diagnostics identify unsupported expressions precisely,
- failures are actionable.

---

## Milestone 5: Schema Awareness and Nested Field Support

### Objective
Add disciplined support for simple nested documents.

### Tasks
- add schema sampling helpers,
- support dot-path field references,
- document nested-field semantics,
- test missing-field behavior carefully.

### Acceptance criteria
- nested scalar fields can be projected and filtered,
- documentation explains caveats,
- tests cover heterogeneous documents.

### Risks
- ambiguous field existence semantics,
- inconsistent behavior across collections.

---

## Milestone 6: Stabilization and Documentation

### Objective
Prepare for a public alpha or experimental release.

### Tasks
- finalize support matrix,
- add vignettes,
- audit error messages,
- run broader compatibility tests,
- document limitations prominently.

### Acceptance criteria
- package is usable for documented workflows,
- failures are predictable,
- examples run end-to-end,
- package can be evaluated by early adopters.

---

## 10. Detailed Work Breakdown

## 10.1 Public API Tasks

### Task API-001
Create `tbl_mongo()` constructor.

#### Inputs
- `mongolite` connection or source wrapper,
- collection name if needed,
- optional schema options.

#### Outputs
- valid `tbl_mongo` object.

#### Acceptance criteria
- constructor validates inputs,
- source metadata is stored,
- print method is informative.

### Task API-002
Create `collect.tbl_mongo()`.

#### Acceptance criteria
- compiles current IR,
- executes through `mongolite`,
- returns tibble,
- propagates clear errors.

### Task API-003
Create `show_query.tbl_mongo()`.

#### Acceptance criteria
- displays current pipeline,
- does not execute query,
- stable textual representation suitable for tests.

## 10.2 Translation Tasks

### Task TR-001
Implement symbol translation.

#### Acceptance criteria
- column names map correctly to Mongo field references,
- invalid references error clearly.

### Task TR-002
Implement literal translation.

#### Acceptance criteria
- numeric, character, logical, and date-like literals are supported where intended.

### Task TR-003
Implement predicate translation.

#### Scope
- `==`, `!=`, `<`, `<=`, `>`, `>=`, `&`, `|`, `!`.

### Task TR-004
Implement scalar expression translation.

#### Scope
- `+`, `-`, `*`, `/`,
- `abs`, `sqrt`, `log`, `exp`, `round`,
- `if_else`,
- `case_when`.

### Task TR-005
Implement aggregate translation.

#### Scope
- `n`,
- `sum`,
- `mean`,
- `min`,
- `max`.

### Task TR-006
Implement diagnostics for unsupported expressions.

#### Acceptance criteria
- error identifies offending call,
- error indicates whether unsupported in expression or aggregation context.

## 10.3 Compiler Tasks

### Task CMP-001
Compile filter IR into `$match`.

### Task CMP-002
Compile projection/mutation IR into `$project` and/or `$addFields`.

### Task CMP-003
Compile sort IR into `$sort`.

### Task CMP-004
Compile group/summarise IR into `$group`.

### Task CMP-005
Compile limit/head IR into `$limit`.

### Task CMP-006
Assemble full pipeline in valid stage order.

---

## 11. Testing Strategy

Testing should be treated as a first-class deliverable.

## 11.1 Test Categories

### Translation unit tests
Input: R expression or verb state.  
Expected output: internal translated form or pipeline stage.

Purpose:
- validate compiler behavior precisely,
- isolate bugs early.

### Golden pipeline tests
Input: user pipeline.  
Expected output: stable pipeline representation.

Purpose:
- detect regressions in compilation,
- verify stage ordering and expression forms.

### Semantic tests
Input: fixture collection plus query.  
Expected output: data frame result.

Purpose:
- verify that actual execution matches intended semantics.

## 11.2 Required Fixtures

At minimum, include:

- flat numeric fixture,
- character and factor-like fixture,
- fixture with missing fields,
- fixture with explicit `NULL` values if possible,
- nested document fixture,
- date/time fixture,
- heterogeneous-type fixture.

## 11.3 Testing Principles

- every new supported verb or function requires unit tests,
- every bug fix should add a regression test,
- semantic tests should compare only on documented supported cases,
- unsupported cases should also be tested to ensure explicit failure.

---

## 12. Risk Register

## 12.1 Semantic Risk

### Risk
Users assume full `dplyr` support.

### Mitigation
- publish support matrix,
- document limitations prominently,
- fail explicitly on unsupported features.

## 12.2 Translation Complexity Risk

### Risk
Expression translation becomes a large, fragile compiler.

### Mitigation
- keep supported function set small initially,
- use IR,
- add exhaustive translator tests,
- separate scalar and aggregate translation.

## 12.3 Schema Irregularity Risk

### Risk
Collections contain inconsistent document structures.

### Mitigation
- target flat collections first,
- add schema sampling tools,
- document caveats for missing/nested fields.

## 12.4 Performance Risk

### Risk
Generated pipelines are correct but inefficient.

### Mitigation
- allow query inspection,
- consider `explain()` support,
- keep compilation conservative,
- optimize only after semantic correctness is established.

## 12.5 Scope Creep Risk

### Risk
Early addition of joins, arrays, or client-side fallback complicates design.

### Mitigation
- maintain explicit non-goals,
- gate advanced features behind later milestones,
- require acceptance criteria before expanding scope.

---

## 13. Recommended Implementation Order

The implementation order should be:

1. hard-coded technical spike,
2. lazy object model,
3. filter/select/mutate/arrange/limit,
4. collect/show_query,
5. group_by/summarise,
6. diagnostics,
7. schema helpers,
8. nested field support,
9. documentation and release stabilization.

This order minimizes wasted effort and validates the riskiest compiler steps early.

---

## 14. Suggested Repository Standards

The repository should adopt:

- `testthat` for tests,
- `roxygen2` for documentation,
- `lintr`,
- `styler`,
- GitHub Actions for CI,
- snapshot tests where useful for query rendering,
- minimal reproducible example fixtures.

Suggested CI stages:

- R CMD check,
- lint,
- unit tests,
- snapshot tests,
- optional integration tests against a test MongoDB container.

If integration tests are added, isolate them from normal fast CI unless a MongoDB service is available.

---

## 15. Definition of Done for the First Usable Release

A first usable experimental release is complete when all of the following are true:

- users can create a `tbl_mongo` from a collection,
- common analytical read-only pipelines can be written without JSON,
- generated pipelines can be inspected,
- supported subset is documented,
- unsupported operations fail explicitly,
- tests cover both successful and failing cases,
- example workflows are reproducible.

---

## 16. Final Recommendation

This package is a sound and realistic project, provided the goal remains constrained.

The correct framing is not:

> reproduce `dbplyr` for MongoDB.

The correct framing is:

> build a native tidy lazy analytical backend for MongoDB, focused on a documented subset of `dplyr` verbs and flat-to-moderately-structured collections.

For agentic development, the project is especially suitable because:

- the work decomposes into well-bounded compiler and API tasks,
- each task has clear acceptance criteria,
- semantic regressions can be captured in tests,
- the architecture benefits from explicit contracts between agents.

The most important design decision is to introduce an internal query representation and keep translation, compilation, and execution strictly separated.

That choice will do more than any other to make the package maintainable, testable, and extensible.
