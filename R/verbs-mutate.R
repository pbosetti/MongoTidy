#' @keywords internal
append_projection_fields <- function(projection, fields) {
  if (is.null(projection)) {
    return(NULL)
  }
  for (field in fields) {
    projection[[field]] <- field
  }
  as_named_character(projection)
}

#' @importFrom dplyr mutate
#' @export
mutate.tbl_mongo <- function(.data, ...) {
  quos <- rlang::enquos(...)
  if (!length(quos)) {
    return(.data)
  }

  names_in <- rlang::names2(quos)
  if (any(!nzchar(names_in))) {
    abort_invalid("mutate()", "requires named expressions.")
  }

  translated <- lapply(quos, translate_expr, context = "mutate()")
  names(translated) <- names_in
  projection <- append_projection_fields(.data$ir$projection, names_in)
  update_ir(.data, computed = c(.data$ir$computed, translated), projection = projection)
}

#' @importFrom dplyr transmute
#' @export
transmute.tbl_mongo <- function(.data, ...) {
  quos <- rlang::enquos(...)
  if (!length(quos)) {
    return(.data)
  }

  names_in <- rlang::names2(quos)
  if (any(!nzchar(names_in))) {
    abort_invalid("transmute()", "requires named expressions.")
  }

  translated <- lapply(quos, translate_expr, context = "transmute()")
  names(translated) <- names_in
  projection <- stats::setNames(names_in, names_in)
  update_ir(.data, computed = translated, projection = projection)
}
