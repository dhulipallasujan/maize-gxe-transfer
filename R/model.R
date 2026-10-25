# Cross-environment transfer models for aggregated G2F hybrid observations.

TRANSFER_COVARS <- c("TT_EnJFlo", "TT_FlaFlw", "TT_FlwStG", "SW_EnGMat")

ridge_environment_effect <- function(train_env, target_env, lambda = 1) {
  keep <- complete.cases(train_env[, c("env_mean", TRANSFER_COVARS)])
  train_env <- train_env[keep, , drop = FALSE]
  target_x <- as.numeric(target_env[1, TRANSFER_COVARS, drop = TRUE])
  if (nrow(train_env) < 8 || any(!is.finite(target_x))) return(NA_real_)

  x <- as.matrix(train_env[, TRANSFER_COVARS, drop = FALSE])
  center <- colMeans(x)
  spread <- apply(x, 2, stats::sd)
  usable <- is.finite(spread) & spread > 1e-8
  if (!any(usable)) return(NA_real_)

  x <- scale(x[, usable, drop = FALSE], center = center[usable], scale = spread[usable])
  target_scaled <- (target_x[usable] - center[usable]) / spread[usable]
  design <- cbind(1, x)
  penalty <- diag(c(0, rep(lambda, ncol(x))))
  coefficients <- tryCatch(
    solve(crossprod(design) + penalty, crossprod(design, train_env$env_mean)),
    error = function(e) NULL
  )
  if (is.null(coefficients)) return(NA_real_)
  as.numeric(c(1, target_scaled) %*% coefficients)
}

predict_held_environment <- function(data, target_env, lambda = 1) {
  target <- data[data$year_loc == target_env, , drop = FALSE]
  train <- data[data$year_loc != target_env, , drop = FALSE]
  train <- train[is.finite(train$yield_mean) & complete.cases(train[, TRANSFER_COVARS]), , drop = FALSE]
  target <- target[is.finite(target$yield_mean) & complete.cases(target[, TRANSFER_COVARS]), , drop = FALSE]
  if (!nrow(target) || !nrow(train)) return(data.frame())

  env_input <- train[, c("yield_mean", TRANSFER_COVARS), drop = FALSE]
  env_train <- aggregate(env_input, by = list(year_loc = train$year_loc), FUN = mean, na.rm = TRUE)
  names(env_train)[names(env_train) == "yield_mean"] <- "env_mean"
  env_target <- unique(target[, c("year_loc", TRANSFER_COVARS), drop = FALSE])
  transfer_mean <- ridge_environment_effect(env_train, env_target, lambda)
  offset <- if (is.finite(transfer_mean)) transfer_mean - mean(env_train$env_mean) else 0

  genetic_baseline <- aggregate(yield_mean ~ genotype, train, mean, na.rm = TRUE)
  names(genetic_baseline)[2] <- "historical_mean_prediction"
  predictions <- merge(target[, c("year_loc", "year", "location", "region", "genotype", "yield_mean")],
                       genetic_baseline, by = "genotype", all = FALSE)
  predictions$environment_transfer_prediction <- predictions$historical_mean_prediction + offset
  predictions$predicted_environment_mean <- if (is.finite(transfer_mean)) transfer_mean else NA_real_
  predictions$observed_environment_mean <- mean(target$yield_mean)
  predictions$environment_effect_estimated <- is.finite(transfer_mean)
  predictions
}

regression_metrics <- function(observed, predicted) {
  good <- is.finite(observed) & is.finite(predicted)
  observed <- observed[good]
  predicted <- predicted[good]
  if (!length(observed)) return(data.frame(n = 0, RMSE = NA, MAE = NA, Bias = NA, Spearman = NA))
  rho <- if (length(unique(observed)) > 1 && length(unique(predicted)) > 1) {
    suppressWarnings(cor(observed, predicted, method = "spearman"))
  } else NA_real_
  data.frame(n = length(observed), RMSE = sqrt(mean((observed - predicted)^2)),
             MAE = mean(abs(observed - predicted)), Bias = mean(predicted - observed),
             Spearman = rho)
}

run_leave_environment_out <- function(data, lambda = 1, min_genotypes = 8) {
  environments <- unique(data$year_loc)
  results <- lapply(environments, function(env) {
    out <- predict_held_environment(data, env, lambda)
    if (nrow(out) < min_genotypes) return(NULL)
    out
  })
  predictions <- do.call(rbind, results[!vapply(results, is.null, logical(1))])
  if (is.null(predictions) || !nrow(predictions)) {
    return(list(predictions = data.frame(), metrics = data.frame(), by_environment = data.frame()))
  }

  baseline <- regression_metrics(predictions$yield_mean, predictions$historical_mean_prediction)
  transfer <- regression_metrics(predictions$yield_mean, predictions$environment_transfer_prediction)
  metrics <- rbind(transform(baseline, model = "Historical hybrid mean"),
                   transform(transfer, model = "Environment-aware transfer"))
  by_environment <- do.call(rbind, lapply(split(predictions, predictions$year_loc), function(x) {
    a <- regression_metrics(x$yield_mean, x$historical_mean_prediction)
    b <- regression_metrics(x$yield_mean, x$environment_transfer_prediction)
    data.frame(year_loc = x$year_loc[1], year = x$year[1], location = x$location[1],
               n = a$n, RMSE_baseline = a$RMSE, RMSE_transfer = b$RMSE,
               Spearman_baseline = a$Spearman, Spearman_transfer = b$Spearman)
  }))
  list(predictions = predictions, metrics = metrics, by_environment = by_environment)
}

selection_table <- function(data, target_env, lambda = 1, min_envs = 3) {
  target_features <- unique(data[data$year_loc == target_env, c("year_loc", TRANSFER_COVARS), drop = FALSE])
  train <- data[data$year_loc != target_env, , drop = FALSE]
  train <- train[complete.cases(train[, TRANSFER_COVARS]) & is.finite(train$yield_mean), , drop = FALSE]
  if (!nrow(train) || !nrow(target_features)) return(data.frame())

  env_input <- train[, c("yield_mean", TRANSFER_COVARS), drop = FALSE]
  env_train <- aggregate(env_input, by = list(year_loc = train$year_loc), FUN = mean, na.rm = TRUE)
  names(env_train)[names(env_train) == "yield_mean"] <- "env_mean"
  target_mean <- ridge_environment_effect(env_train, target_features, lambda)
  offset <- if (is.finite(target_mean)) target_mean - mean(env_train$env_mean) else 0
  means <- aggregate(yield_mean ~ genotype, train, mean)
  spreads <- aggregate(yield_mean ~ genotype, train, sd)
  counts <- aggregate(yield_mean ~ genotype, train, length)
  names(means)[2] <- "historical_mean"
  names(spreads)[2] <- "across_environment_sd"
  names(counts)[2] <- "n_training_environments"
  result <- Reduce(function(x, y) merge(x, y, by = "genotype"), list(means, spreads, counts))
  result$predicted_target_yield <- result$historical_mean + offset
  result$target_environment <- target_env
  result <- result[result$n_training_environments >= min_envs, , drop = FALSE]
  result[order(-result$predicted_target_yield, result$across_environment_sd), , drop = FALSE]
}
