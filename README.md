# mongo-tidy

A native tidy lazy backend for MongoDB in R.

## Overview

`mongo-tidy` is a proposed R package that provides a `dplyr`-style interface for analytical querying of MongoDB collections, using `mongolite` as the execution layer.

The package is inspired by the lazy-query model familiar from `dbplyr`, but it is **not** intended to extend `dbplyr`, emulate SQL, or force MongoDB into a relational abstraction. Instead, it aims to provide a MongoDB-native backend that translates a disciplined subset of `dplyr` pipelines into MongoDB aggregation pipelines.

The main purpose is to let users write code such as:

```r
tbl_mongo(conn, "collection") |>
  filter(x > 0, category != "A") |>
  mutate(z = x * 2) |>
  group_by(group) |>
  summarise(n = n(), avg_z = mean(z, na.rm = TRUE)) |>
  arrange(group) |>
  collect()
```

without manually building JSON queries.

---

## Project Goal

The package should provide:

- lazy query composition,
- tidy evaluation,
- translation of supported verbs into MongoDB aggregation stages,
- query inspection,
- explicit and predictable failure for unsupported operations.

The package should **not** aim to deliver full `dplyr` compatibility over arbitrary MongoDB collections.

---

## Design Position

This project should be framed as:

> a native tidy lazy analytical backend for MongoDB.

It should **not** be framed as:

> a complete `dbplyr` equivalent for MongoDB.

MongoDB documents are not rectangular SQL tables. Nested fields, arrays, missing keys, heterogeneous schemas, and document-oriented semantics require a backend that is native to MongoDB rather than adapted from SQL assumptions.

---

## MVP Scope

The first usable version should support a clear, documented subset of read-only analytical workflows.

### Core objects and terminal operations
- `tbl_mongo()`
- `collect()`
- `show_query()`

### Core verbs
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

### Initial expression support
- column references,
- literals,
- comparison operators,
- boolean operators,
- arithmetic operators,
- simple scalar numeric functions,
- `if_else()`,
- `case_when()`,
- `is.na()`,
- basic aggregation functions.

### Out of scope for MVP
- joins,
- window functions,
- rowwise operations,
- arbitrary list-column manipulation,
- tidyr-style reshaping,
- automatic unnesting,
- write/update/delete operations,
- DBI backend support,
- silent client-side fallback.

---

## Core Technical Principles

### 1. Native MongoDB translation
Do not generate SQL. Do not emulate SQL. Translate directly into MongoDB aggregation pipelines.

### 2. Internal intermediate representation
Introduce a package-specific internal query representation between the user API and the pipeline compiler.

This is a core design requirement. It allows:

- better testing,
- better diagnostics,
- cleaner compiler logic,
- easier future extension.

### 3. Lazy semantics
All supported verbs should update query state, not execute immediately.

Execution should occur only at terminal steps such as `collect()`.

### 4. Explicit failure
Unsupported operations should fail with precise diagnostics. The package should not silently pull data locally and continue computation unless that behavior is deliberately introduced later as an opt-in mode.

### 5. Conservative semantics
Ambiguous cases should be handled conservatively and documented explicitly, especially for:

- missing fields,
- `NULL` / `NA` behavior,
- heterogeneous field types,
- nested document paths,
- ordering assumptions.

---

## Architecture Summary

The recommended architecture has five layers.

### Layer 1: source and connection wrapper
Wrap `mongolite::mongo()` plus collection metadata.

### Layer 2: lazy query object
Represent the evolving query declaratively in a `tbl_mongo` object.

### Layer 3: expression translation
Translate quosures into MongoDB predicate and expression trees.

### Layer 4: pipeline compilation
Compile the internal representation into MongoDB aggregation pipeline stages.

### Layer 5: execution
Run the compiled pipeline through `mongolite` and return a tibble.

---

## Expected Translation Model

Typical verb mappings are:

- `filter()` -> `$match`
- `select()` -> `$project`
- `mutate()` -> `$addFields` or `$project`
- `arrange()` -> `$sort`
- `group_by()` + `summarise()` -> `$group`
- `slice_head()` / `head()` -> `$limit`

This mapping should be documented, inspectable, and testable.

---

## Development Milestones

### Milestone 0: technical spike
Demonstrate that a small hard-coded pipeline can be translated and executed correctly.

### Milestone 1: object model and internal IR
Implement `mongo_src`, `tbl_mongo`, printing, and declarative query state.

### Milestone 2: basic verb support
Implement filtering, projection, mutation, sorting, and limiting for flat collections.

### Milestone 3: grouping and summaries
Implement grouped aggregation with a small supported set of summary functions.

### Milestone 4: diagnostics and query inspection
Implement `show_query()` and high-quality unsupported-feature diagnostics.

### Milestone 5: schema awareness and nested fields
Add disciplined support for dot-path fields and schema sampling helpers.

### Milestone 6: stabilization
Document support matrix, examples, caveats, and release an experimental version.

---

## Testing Strategy

Testing should be divided into three categories:

### Translation unit tests
Verify that R expressions and verb state produce the expected internal representations or pipeline fragments.

### Golden pipeline tests
Verify that full pipelines compile into stable and expected stage sequences.

### Semantic tests
Verify that execution against fixture collections returns expected results.

Required fixtures should include:

- flat numeric collections,
- collections with missing fields,
- nested documents,
- date/time fields,
- heterogeneous-type fields.

Unsupported cases should also be tested to ensure they fail explicitly.

---

## Suggested Repository Layout

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

---

## Definition of Success

A first usable experimental release is complete when:

- users can create a `tbl_mongo` from a collection,
- common read-only analytical pipelines can be written without JSON,
- generated pipelines can be inspected,
- supported features and limitations are documented,
- unsupported features fail explicitly,
- tests cover both successful and failing cases.

---

## Status

This repository currently contains planning documents only. Implementation should follow the architecture and task decomposition described in `AGENTS.md`.
