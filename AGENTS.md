# AGENTS.md

## Purpose

This document defines how coding agents should implement the `mongo-tidy` project: an R package providing a native tidy lazy analytical backend for MongoDB using `mongolite`.

It is an execution-oriented specification. It complements the development-plan document and is intended to coordinate agentic implementation.

---

## Project Objective

Build a package that lets users write a disciplined subset of `dplyr` pipelines against MongoDB collections without manually authoring JSON queries.

The backend must:

- remain lazy,
- translate supported operations to MongoDB aggregation pipelines,
- execute through `mongolite`,
- expose generated queries for inspection,
- fail explicitly for unsupported semantics.

The backend must **not** attempt to reproduce full relational or SQL semantics.

---

## Non-Negotiable Constraints

All agents must follow these constraints.

### 1. Do not broaden scope
Do not add joins, window functions, writes, reshaping, automatic fallback, or broad nested-array support unless a milestone explicitly authorizes it.

### 2. Preserve lazy semantics
No supported verb should execute a query. Execution belongs only in terminal operations such as `collect()`.

### 3. Separate concerns
Keep these layers distinct:

- user-facing lazy object model,
- internal query representation,
- expression translation,
- pipeline compilation,
- execution.

### 4. Prefer explicit failure
If a construct cannot be translated safely, error clearly. Do not guess. Do not silently `collect()` and continue locally.

### 5. Keep translation testable
Expression translation functions should be as pure and isolated as practical.

### 6. Document semantic limits
Any newly supported feature must also update the support matrix or equivalent documentation.

### 7. Add tests with every feature
No feature is complete without tests. No bug fix is complete without a regression test.

---

## Canonical Product Scope

### MVP features
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

### MVP expression families
- symbol references,
- literals,
- comparison operators,
- boolean operators,
- arithmetic operators,
- selected scalar numeric functions,
- `if_else()`,
- `case_when()`,
- `is.na()`,
- basic aggregate functions.

### Explicitly out of scope
- joins,
- window functions,
- `across()`,
- rowwise workflows,
- tidyr reshaping,
- write/update/delete operations,
- DBI integration,
- automatic client-side fallback.

---

## Architecture Contract

### Required layers

#### Layer 1: source wrapper
Represents connection and collection metadata.

Suggested object:
- `mongo_src`

#### Layer 2: lazy table
User-facing lazy query object.

Suggested object:
- `tbl_mongo`

#### Layer 3: internal query representation
Stores declarative state for current query.

Must be independent of raw MongoDB JSON.

#### Layer 4: translators
Translate R expressions into internal or Mongo-oriented expression structures.

Separate:
- predicate translation,
- scalar expression translation,
- aggregate translation.

#### Layer 5: compiler
Assemble valid MongoDB aggregation pipeline stages in correct order.

#### Layer 6: execution
Run compiled pipeline through `mongolite` and return tibble results.

---

## Internal Query Representation Requirements

The IR must be stable, explicit, and easy to inspect in tests.

It should be capable of representing:

- source collection,
- filters,
- selected fields,
- computed fields,
- grouping variables,
- summary expressions,
- ordering,
- limit,
- optional schema metadata.

The IR must stay declarative. It must not store partially executed results.

---

## Expected Verb-to-Stage Mapping

Use these as default compilation targets unless there is a strong documented reason not to.

- `filter()` -> `$match`
- `select()` -> `$project`
- `mutate()` -> `$addFields` or `$project`
- `arrange()` -> `$sort`
- `group_by()` + `summarise()` -> `$group`
- `slice_head()` / `head()` -> `$limit`

---

## Required Repository Structure

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
```

Agents may add files if necessary, but should preserve this structure and naming logic.

---

## Agent Roles

### Agent A: Architecture and API
Responsibilities:
- define object model,
- define constructor and print methods,
- define IR contract,
- enforce layer separation.

Primary deliverables:
- `tbl_mongo()`
- source and lazy-object definitions
- design notes where needed

### Agent B: Verb implementation
Responsibilities:
- implement lazy verb methods,
- update IR for each supported verb,
- preserve non-executing behavior.

Primary deliverables:
- verb methods for MVP
- verb-specific tests

### Agent C: Expression translation
Responsibilities:
- translate symbols and literals,
- translate predicates,
- translate scalar expressions,
- translate aggregates,
- emit precise diagnostics.

Primary deliverables:
- translation modules
- translation tests
- unsupported-expression error paths

### Agent D: Pipeline compiler and execution
Responsibilities:
- compile IR into valid Mongo pipeline stage lists,
- implement `collect()` and `show_query()`,
- guarantee correct stage ordering.

Primary deliverables:
- `compile_pipeline()`
- execution methods
- pipeline rendering helpers

### Agent E: Testing and validation
Responsibilities:
- maintain fixtures,
- add semantic tests,
- add regression tests,
- monitor supported subset behavior.

Primary deliverables:
- comprehensive `testthat` coverage
- fixture setup
- snapshot/golden tests where appropriate

### Agent F: Documentation
Responsibilities:
- support matrix,
- README,
- limitations documentation,
- examples and vignette drafts.

Primary deliverables:
- user-facing docs
- explicit documentation of unsupported features

---

## Milestones and Task Gates

## Milestone 0: technical spike

### Goal
Verify the end-to-end feasibility of translation and execution.

### Required output
A prototype that translates a small hard-coded query sequence into a valid aggregation pipeline and runs it successfully.

### Acceptance criteria
- translation works for a simple fixture,
- execution via `mongolite` succeeds,
- results are correct,
- unsupported constructs fail explicitly.

### Exit condition
Proceed only after this spike demonstrates viability.

---

## Milestone 1: source object, lazy table, and IR

### Tasks
- define `mongo_src`,
- define `tbl_mongo`,
- define print methods,
- define IR schema,
- define helper constructors/updaters.

### Acceptance criteria
- valid lazy object can be created,
- chained operations preserve object integrity,
- query state is inspectable,
- no execution occurs during state updates.

### Prohibited changes
- no compiler shortcuts,
- no hidden execution,
- no raw JSON as the only state representation.

---

## Milestone 2: basic verbs on flat collections

### Tasks
- implement `filter()`,
- implement `select()`,
- implement `rename()`,
- implement `mutate()` for simple scalar expressions,
- implement `arrange()`,
- implement limit support.

### Acceptance criteria
- each verb updates IR correctly,
- compilation produces correct stage fragments,
- `collect()` returns tibble results for flat fixtures,
- unit tests and semantic tests pass.

### Scope guard
Flat collections only. Nested-field work belongs to a later milestone.

---

## Milestone 3: grouped summaries

### Tasks
- implement `group_by()`,
- implement `summarise()`,
- support aggregate translators for:
  - `n()`
  - `sum()`
  - `mean()`
  - `min()`
  - `max()`

### Acceptance criteria
- grouping metadata is correct,
- `$group` stage compiles correctly,
- results match reference expectations,
- unsupported summaries fail explicitly.

### Risk focus
Handle `na.rm`, missing fields, and mixed-type fields conservatively.

---

## Milestone 4: diagnostics and query inspection

### Tasks
- implement `show_query()`,
- add stable pipeline rendering,
- improve unsupported-expression errors,
- optionally add `explain()` only if simple and clean.

### Acceptance criteria
- pipelines can be inspected without execution,
- diagnostics identify the failing expression or verb,
- rendering is stable enough for snapshot testing.

---

## Milestone 5: schema helpers and nested fields

### Tasks
- add schema sampling helpers,
- support dot-path field references,
- document nested scalar semantics,
- expand tests for heterogeneous documents.

### Acceptance criteria
- nested scalar fields can be selected and filtered,
- caveats are documented,
- failing edge cases remain explicit.

### Scope guard
Do not add array unnesting or automatic restructuring.

---

## Milestone 6: stabilization and public alpha

### Tasks
- finalize support matrix,
- review diagnostics,
- refine README and examples,
- run broader CI,
- review package ergonomics.

### Acceptance criteria
- documented workflows run end-to-end,
- failures are predictable,
- examples are reproducible,
- support boundaries are visible.

---

## Detailed Task Inventory

## API tasks

### API-001
Implement `tbl_mongo()`.

#### Requirements
- validate source inputs,
- capture collection metadata,
- return a valid lazy object.

#### Tests
- constructor validation,
- print behavior,
- empty IR initialization.

### API-002
Implement `collect.tbl_mongo()`.

#### Requirements
- compile current IR,
- execute through `mongolite`,
- return tibble.

#### Tests
- successful execution on fixture,
- propagation of translation/compiler errors.

### API-003
Implement `show_query.tbl_mongo()`.

#### Requirements
- no execution,
- stable textual or structured pipeline rendering.

#### Tests
- snapshot or golden output,
- stability across identical IR.

---

## Translation tasks

### TR-001
Implement symbol translation.

#### Requirements
- field references map correctly,
- invalid symbols fail clearly.

### TR-002
Implement literal translation.

#### Requirements
- numeric, character, logical, and supported date-like literals translate correctly.

### TR-003
Implement predicate translation.

#### Scope
- `==`, `!=`, `<`, `<=`, `>`, `>=`, `&`, `|`, `!`

### TR-004
Implement scalar expression translation.

#### Scope
- `+`, `-`, `*`, `/`
- `abs`, `sqrt`, `log`, `exp`, `round`
- `if_else`
- `case_when`

### TR-005
Implement aggregate translation.

#### Scope
- `n`
- `sum`
- `mean`
- `min`
- `max`

### TR-006
Implement unsupported-expression diagnostics.

#### Requirements
- identify failing call,
- identify context,
- avoid vague generic errors.

---

## Compiler tasks

### CMP-001
Compile filters into `$match`.

### CMP-002
Compile projections and mutations into `$project` and/or `$addFields`.

### CMP-003
Compile ordering into `$sort`.

### CMP-004
Compile grouping and summaries into `$group`.

### CMP-005
Compile limits into `$limit`.

### CMP-006
Assemble full pipelines in valid stage order.

### CMP-007
Provide rendering helper for `show_query()`.

---

## Testing policy

### Required test categories
- translation unit tests,
- golden pipeline tests,
- semantic execution tests,
- explicit-failure tests.

### Required fixtures
- flat numeric fixture,
- missing-field fixture,
- nested-document fixture,
- date/time fixture,
- heterogeneous-type fixture.

### Mandatory rules
- every feature needs tests,
- every bug fix adds a regression test,
- unsupported behavior should be tested explicitly.

---

## Documentation policy

Every new supported semantic capability must update at least one of:

- support matrix,
- README examples,
- limitations documentation,
- translation reference notes.

Every deliberate non-support decision should be documented, not merely left unimplemented.

---

## Error-message policy

Error messages must be actionable.

A good error should communicate:

- which verb or expression failed,
- whether the issue is unsupported or invalid,
- whether the failure occurred in predicate, scalar, or aggregate translation,
- where practical, a suggestion to simplify or rewrite the expression.

Avoid generic messages such as:
- "translation failed"
- "unsupported expression"

without context.

---

## Change-control rules for agents

Before merging or finalizing a change, the responsible agent must confirm:

1. Does this preserve lazy execution?
2. Does this fit the current milestone?
3. Are tests added or updated?
4. Does this widen semantics accidentally?
5. Is unsupported behavior still explicit?
6. Does documentation need updating?

If the answer to any of these is unsatisfactory, revise before proceeding.

---

## Definition of Done

A unit of work is done only when:

- implementation is complete,
- tests pass,
- unsupported edge cases are handled explicitly,
- documentation is updated if semantics changed.

A milestone is done only when all listed acceptance criteria are satisfied.

---

## Final execution stance

The project should prioritize:

1. semantic clarity,
2. compiler correctness,
3. inspectability,
4. conservative scope,
5. testability.

Agents must resist pressure to simulate broad compatibility early. A smaller, correct, explicit backend is substantially better than a broader but ambiguous one.
