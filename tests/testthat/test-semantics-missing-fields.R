test_that("is.na predicates work against missing values", {
  tbl <- mock_tbl(tibble::tibble(x = c(1, NA, 3), y = c("a", "b", NA)))

  result <- tbl |>
    dplyr::filter(is.na(y) | x > 2) |>
    collect()

  expect_equal(result$x, 3)
})
