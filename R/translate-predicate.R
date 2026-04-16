#' @keywords internal
translate_predicate <- function(expr) {
  translated <- translate_expr(expr, context = "predicate")
  allowed <- c("comparison", "boolean", "not", "is_na", "literal", "field")
  if (!translated$type %in% allowed) {
    abort_unsupported("filter()", expr, "Predicates must evaluate to logical comparisons.")
  }
  translated
}
