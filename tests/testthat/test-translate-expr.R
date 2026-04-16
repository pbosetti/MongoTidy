test_that("expression translation covers scalar operators", {
  expr <- MongoTidy:::translate_expr(rlang::expr(round(abs(x) / 2, 1)))

  expect_equal(expr$type, "round")
  expect_equal(expr$digits, 1L)
  expect_equal(expr$arg$type, "call")
})

test_that("case_when translation yields stable structure", {
  expr <- MongoTidy:::translate_expr(rlang::expr(case_when(x > 1 ~ "big", TRUE ~ "small")))

  expect_equal(expr$type, "case_when")
  expect_length(expr$cases, 1)
  expect_equal(expr$default$type, "literal")
})
