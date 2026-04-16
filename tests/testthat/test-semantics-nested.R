test_that("backticked dot-path fields can be selected and filtered", {
  tbl <- mock_tbl(tibble::tibble(`user.age` = c(20, 30, 40), score = c(1, 2, 3)))

  result <- tbl |>
    dplyr::filter(`user.age` >= 30) |>
    dplyr::select(`user.age`, score) |>
    collect()

  expect_equal(result$`user.age`, c(30, 40))
  expect_equal(names(result), c("user.age", "score"))
})

test_that("show_query renders stable JSON", {
  tbl <- mock_tbl(tibble::tibble(x = 1:2, y = 3:4)) |>
    dplyr::mutate(z = x + y) |>
    dplyr::select(z)

  rendered <- show_query(tbl)

  expect_match(rendered, '\$addFields')
  expect_match(rendered, '\$project')
})
