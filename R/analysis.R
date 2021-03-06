#' Run a Salary Analysis
#'
#' Runs a salary analysis according to the Swiss standard analysis model
#'
#' @param data a data.frame of employees as produced by \code{read_data}
#' @param reference_month an integer representing the reference month, i.e. the
#' month for which we analyze the salaries
#' @param reference_year an integer representing the reference year, i.e. the
#' year for which we analyze the salaries
#' @param female_spec an optional string or numeric representing the way women
#' are encoded in the \code{data}
#' @param male_spec an optional string or numeric representing the way men are
#' encoded in the \code{data}
#' @param age_spec an optional string to specify the way \code{age} is encoded
#' in the data (\code{NULL} will try to automatically infer the age format,
#' \code{"age"} implies that the \code{age} is specified as the age of a person,
#' \code{"birthyear"} implies that the \code{age} is specified as the year of
#' birth of a person, and \code{"birthdate"} implies that the \code{age} is
#' specified as the date of birth of a person)
#' @param entry_date_spec an optional string to specify the way
#' \code{entry_date} is encoded in the data (\code{NULL} will try to
#' automatically infer the format, \code{"years"} implies that the
#' \code{entry_date} is specified as the number of years for which the person
#' has been in the company, \code{"entry_year"} implies that the
#' \code{entry_date} is specified as the year of the entry date of the person,
#' \code{"entry_date"} implies that the age is specified as the date of entry
#' of the person)
#' @param ignore_plausibility_check a boolean indicating whether the
#' plausibility of the data should be checked or whether all correct data is
#' considered plausible
#' @param prompt_data_cleanup a boolean indicating whether a prompt will pop up
#' to enforce cleaning the data until all data is correct
#'
#' @return object of type \code{analysis_model} with the following
#' elements
#' \itemize{
#'    \item{\code{params}: }{The set of original parameters passed to the
#'    function}
#'    \item{\code{data_original}: }{The original data passed by the user in the
#'    \code{data} parameter}
#'    \item{\code{data_clean}: }{The cleaned up data which was used for the
#'    analysis}
#'    \item{\code{data_errors}: }{The list of errors which were found upon
#'    checking the data}
#'    \item{\code{results}: }{The result of the standard analysis model}
#'
#' }
#'
#' @examples
#' results <- analysis(data = datalist_imprimerie, reference_month = 1,
#'    reference_year = 2019, female_spec = 1, male_spec = 2)
#'
#' @export
analysis <- function(data, reference_month, reference_year, female_spec = "F",
                     male_spec = "M", age_spec = NULL, entry_date_spec = NULL,
                     ignore_plausibility_check = FALSE,
                     prompt_data_cleanup = FALSE) {
  params <- list(reference_month = reference_month,
                 reference_year = reference_year, female_spec = female_spec,
                 male_spec = male_spec, age_spec = age_spec,
                 entry_date_spec = entry_date_spec)
  data_original <- data
  data_prepared <- prepare_data(data, reference_month, reference_year,
                                female_spec, male_spec, age_spec,
                                entry_date_spec, ignore_plausibility_check,
                                prompt_data_cleanup)
  results <- run_standard_analysis_model(data_prepared$data)
  output <- list(params = params,
                 data_original = data_original,
                 data_clean = data_prepared$data,
                 data_errors = data_prepared$errors,
                 results = results)
  class(output) <- "analysis_model"
  output

}

#' Summary of the Salary Analysis
#'
#' Summary of an estimated salary analysis object of class
#' \code{analysis_model}
#'
#' \code{summary.analysis_model} provides a short summary of the wage
#' analysis according to the Standard Analysis Model. The summary describes the
#' number of records used for the analysis, the Kennedy estimate of the wage
#' difference under otherwise equal circumstances and the summary of the linear
#' regression.
#'
#' @param object estimated salary analysis object of class
#' \code{analysis_model}
#' @param ... further arguments passed to or from other methods
#'
#' @return Nothing
#'
#' @examples
#' # Estimate standard analysis model
#' results <- analysis(data = datalist_imprimerie, reference_month = 1,
#'    reference_year = 2019, female_spec = 1, male_spec = 2)
#'
#' # Show summary of the salary analysis
#' summary(results)
#'
#' @export
summary.analysis_model <- function(object, ...) {
  # Compute Kennedy estimate
  coef_sex_f <- object$results$coefficients[length(object$results$coefficients)]
  se_sex_f   <- summary(object$results)$coefficients[nrow(
    summary(object$results)$coefficients), 2]
  kennedy_estimate <- get_kennedy_estimator(coef_sex_f, se_sex_f^2)

  # Compute the number of employees total / valid for all, women and men only
  n_original <- nrow(object$data_original)
  n_f_original <- sum(object$data_original$sex == object$params$female_spec,
                      na.rm = TRUE)
  n_m_original <- sum(object$data_original$sex == object$params$male_spec,
                      na.rm = TRUE)
  n_clean <- nrow(object$data_clean)
  n_f_clean <- sum(object$data_clean$sex == "F")
  n_m_clean <- sum(object$data_clean$sex == "M")

  # Significance tests
  ratings <- c(
    paste0("The value is not statistically significant. The statistical ",
           "method does not allow a valid gender effect to be determined."),
    paste0("The value is statistically significant. The statistical method ",
           "allows a valid gender effect to be determined."),
    paste0("The value exceeds 5%, which is statistically significant. The ",
           "statistical method allows a major, valid gender effect to be ",
           "determined."))
  sig_level <- 0.05
  h0_threshold <- 0.05
  rating_level <- ifelse(
    2 * (1 - stats::pt(abs(coef_sex_f) / se_sex_f,
                df = object$results$df.residual)) > sig_level, 1,
    ifelse(
      1 - stats::pt((abs(coef_sex_f) - h0_threshold) / se_sex_f,
             df = object$results$df.residual) > sig_level, 2, 3))
  # Infer the print size for methodology metrics from the degrees of freedom
  np <- ceiling(log(object$results$df.residual, 10))


  # Print standard analysis output
  cat("\nSummary of the Standard Analysis Model:\n", sep = "")
  cat(rep("=", 80), "\n\n", sep = "")
  cat("Number of employees: ", n_original, " of which ", n_f_original,
      sprintf(" (%.1f%%)", 100 * n_f_original / n_original), " women and ",
      n_m_original, sprintf(" (%.1f%%)", 100 * n_m_original / n_original),
      " men.\n", sep = "")
  cat("Number of employees included in the analysis: ", n_clean, " of which ",
      n_f_clean, sprintf(" (%.1f%%)", 100 * n_f_clean / n_clean), " women and ",
      n_m_clean, sprintf(" (%.1f%%)", 100 * n_m_clean / n_clean), " men.\n",
      rep("-", 80), "\n", sep = "")
  cat("Under otherwise equal circumstances, women earn ",
      sprintf("%.1f%% ", abs(100 * kennedy_estimate)),
      ifelse(kennedy_estimate > 0, "more ", "less "),
      "than men.\n\n", ratings[rating_level], "\n\n", sep = "")
  cat(rep("-", 80), "\n\n", sep = "")
  # Print methodology metrics
  cat("Methodology Metrics:\n", sep = "")
  cat(rep("=", 80), "\n\n", sep = "")
  cat("Regression results\n", sep = "")
  cat(rep("-", 80), "\n", sep = "")
  cat(sprintf(paste0("%-48s: %", np + 4, ".3f\n"), "Gender coefficient",
                     coef_sex_f), sep = "")
  cat(sprintf(paste0("%-48s: %", np + 4, ".3f\n"),
                     "Standard error of the gender coefficient", se_sex_f),
              sep = "")
  cat(sprintf(paste0("%-48s: %", np, "d\n"), "Degrees of freedom",
              object$results$df.residual), sep = "")
  cat(sprintf(paste0("%-48s: %", np + 4, ".3f\n\n"), "R-squared",
              summary(object$results)$r.squared))
  cat(paste0("Test to see whether the wage difference differs significantly ",
             "from zero\n"), sep = "")
  cat(rep("-", 80), "\n", sep = "")
  cat("H0: Wage diff. = 0%; HA: Wage diff. <> 0%\n", sep = "")
  cat(sprintf(paste0("%-48s: %", np + 4, ".3f\n"), "Critical t-value",
              stats::qt(.975, object$results$df.residual)))
  cat("(Alpha = 5%, two-sided, N = degrees of freedom)\n", sep = "")
  cat(sprintf(paste0("%-48s: %", np + 4, ".3f\n"), "Test statistic t",
              stats::qt(stats::pt(abs(coef_sex_f) / se_sex_f,
                                  object$results$df.residual),
                        object$results$df.residual)), sep = "")
  cat(sprintf("%-48s: %s\n\n", "Significance", ifelse(rating_level == 1, "No",
                                                   "Yes")))
  cat(paste0("Test to see whether the wage difference significantly exceeds ",
             "the tolerance threshold\n"), sep = "")
  cat(rep("-", 80), "\n", sep = "")
  cat("H0: Wage diff. = 5%; HA: Wage diff. > 5%\n", sep = "")
  cat(sprintf(paste0("%-48s: %", np + 4, ".3f\n"), "Critical t-value",
              stats::qt(.95, object$results$df.residual)))
  cat("(Alpha = 5%, one-sided, N = degrees of freedom)\n", sep = "")
  cat(sprintf(paste0("%-48s: %", np + 4, ".3f\n"), "Test statistic t",
              stats::qt(stats::pt((abs(coef_sex_f) - h0_threshold) / se_sex_f,
                                  object$results$df.residual),
                        object$results$df.residual)), sep = "")
  cat(sprintf("%-48s: %s\n\n", "Significance", ifelse(rating_level == 3, "Yes",
                                                       "No")))
}
