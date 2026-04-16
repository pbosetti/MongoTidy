#' @importFrom dplyr arrange
#' @export
arrange.tbl_mongo <- function(.data, ..., .by_group = FALSE) {
  quos <- rlang::enquos(...)
  order <- list()

  if (isTRUE(.by_group) && length(.data$ir$groups) > 0) {
    for (group in .data$ir$groups) {
      order[[group]] <- 1L
    }
  }

  for (quo in quos) {
    expr <- rlang::get_expr(quo)
    direction <- 1L
    if (rlang::is_call(expr, "desc")) {
      direction <- -1L
      expr <- rlang::call_args(expr)[[1]]
    }
    if (!rlang::is_symbol(expr)) {
      abort_unsupported("arrange()", expr, "Only bare field names and desc(field) are supported.")
    }
    order[[rlang::as_string(expr)]] <- direction
  }

  update_ir(.data, order = order)
}

#' @importFrom dplyr slice_head
#' @export
slice_head.tbl_mongo <- function(.data, ..., n = NULL, prop = NULL, by = NULL) {
  if (!is.null(prop) || !is.null(by) || dots_n(...) > 0) {
    abort_unsupported("slice_head()", NULL, "Only slice_head(n = ...) is supported.")
  }
  limit <- if (is.null(n)) 6L else as.integer(n)
  update_ir(.data, limit = limit)
}

#' @keywords internal
dots_n <- function(...) {
  length(rlang::list2(...))
}

#' @export
head.tbl_mongo <- function(x, n = 6L, ...) {
  update_ir(x, limit = as.integer(n))
}
