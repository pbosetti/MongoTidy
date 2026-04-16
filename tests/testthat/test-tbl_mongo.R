test_that("tbl_mongo initializes inspectable IR", {
  tbl <- mock_tbl(tibble::tibble(x = 1:3, y = 4:6))

  expect_s3_class(tbl, "tbl_mongo")
  expect_equal(tbl$ir$filters, list())
  expect_null(tbl$ir$projection)
  expect_equal(schema_fields(tbl), c("x", "y"))
})

test_that("rename requires known fields", {
  collection <- mock_collection(tibble::tibble(x = 1:3))
  tbl <- tbl_mongo(collection, executor = function(pipeline, ...) run_pipeline(collection$data, pipeline))

  expect_error(dplyr::rename(tbl, z = x), "requires known fields")
})
