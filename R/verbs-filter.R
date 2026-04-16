#' @importFrom dplyr filter
#' @export
filter.tbl_mongo <- function(.data, ..., .by = NULL, .preserve = FALSE) {
  if (!is.null(.by)) {
    abort_unsupported("filter()", .by, ".by is not supported.")
  }

  predicates <- rlang::enquos(...)
  translated <- lapply(predicates, translate_predicate)
  update_ir(.data, filters = c(.data$ir$filters, translated))
}
