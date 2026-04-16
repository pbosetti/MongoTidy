#' @keywords internal
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

#' @keywords internal
abort_unsupported <- function(context, expr = NULL, details = NULL) {
  label <- if (is.null(expr)) NULL else rlang::expr_label(expr)
  message <- paste0(context, " does not support ", label %||% "this expression")
  if (!is.null(details)) {
    message <- paste(message, details)
  }
  cli::cli_abort(message, class = "mongo_tidy_unsupported")
}

#' @keywords internal
abort_invalid <- function(context, message) {
  cli::cli_abort(paste(context, message), class = "mongo_tidy_invalid")
}

#' @keywords internal
as_named_character <- function(x) {
  stats::setNames(as.character(x), names(x))
}

#' @keywords internal
is_scalar_literal <- function(x) {
  is.null(x) || (is.atomic(x) && length(x) == 1)
}

#' @keywords internal
field_reference <- function(name) {
  paste0("$", name)
}

#' @keywords internal
expr_text <- function(x) {
  if (rlang::is_quosure(x)) {
    x <- rlang::get_expr(x)
  }
  rlang::expr_label(x)
}
