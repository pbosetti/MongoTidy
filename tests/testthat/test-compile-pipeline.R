test_that("compile_pipeline orders stages conservatively", {
  tbl <- mock_tbl(tibble::tibble(x = 1:5, grp = c("a", "a", "b", "b", "b"))) |>
    dplyr::filter(x > 1) |>
    dplyr::mutate(y = x * 2) |>
    dplyr::select(grp, y) |>
    dplyr::group_by(grp) |>
    dplyr::summarise(total = sum(y), n = n()) |>
    dplyr::arrange(dplyr::desc(total)) |>
    dplyr::slice_head(n = 1)

  pipeline <- compile_pipeline(tbl)
  stage_names <- vapply(pipeline, names, character(1))

  expect_equal(stage_names, c("$match", "$addFields", "$project", "$group", "$project", "$sort", "$limit"))
  expect_equal(pipeline[[4]]$`$group`$total, list(`$sum` = "$y"))
})
