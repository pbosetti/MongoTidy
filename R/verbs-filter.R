#' Filter a lazy Mongo query
#'
#' @param .data A `tbl_mongo` object.
#' @param ... Predicate expressions.
#' @param .by Unsupported.
#' @param .preserve Included for dplyr compatibility.
#'
#' @return A modified `tbl_mongo` object.
#' @rdname mongo_filter
#' @export
#' @exportS3Method dplyr::filter
filter.tbl_mongo <- function(.data, ..., .by = NULL, .preserve = FALSE) {
  if (!is.null(.by)) {
    abort_unsupported("filter()", .by, ".by is not supported.")
  }

  predicates <- rlang::enquos(...)
  translated <- lapply(predicates, translate_predicate)
  update_ir(.data, filters = c(.data$ir$filters, translated))
}
