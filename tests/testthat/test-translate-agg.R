test_that("aggregate translation supports n and mean", {
  n_expr <- MongoTidy:::translate_agg(rlang::expr(n()))
  mean_expr <- MongoTidy:::translate_agg(rlang::expr(mean(x, na.rm = TRUE)))

  expect_equal(n_expr$fn, "n")
  expect_true(mean_expr$na_rm)
  expect_equal(MongoTidy:::compile_agg(mean_expr), list(`$avg` = "$x"))
})

test_that("unsupported aggregate calls fail clearly", {
  expect_error(MongoTidy:::translate_agg(rlang::expr(sd(x))), "Supported summaries")
})
