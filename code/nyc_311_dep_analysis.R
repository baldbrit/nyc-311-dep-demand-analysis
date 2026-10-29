# NYC 311 DEP phone-demand analysis
# Trevor Cudmore
#
# Run this script from the repository root. It reads the included daily
# aggregate, fits the regression and k-means models, saves result tables,
# and recreates the portfolio charts.

required_packages <- c("tidyverse", "lubridate")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0) {
  stop(
    "Install the missing packages first: ",
    paste(missing_packages, collapse = ", "),
    "\nExample: install.packages(c(\"tidyverse\", \"lubridate\"))"
  )
}

library(tidyverse)
library(lubridate)

data_file <- file.path("data", "nyc311_dep_phone_daily_2025.csv")
visual_dir <- "visuals"
result_dir <- "results"

dir.create(visual_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(result_dir, showWarnings = FALSE, recursive = TRUE)

# -----------------------------------------------------------------------------
# 1. Import and prepare the daily data
# -----------------------------------------------------------------------------

daily <- read_csv(data_file, show_col_types = FALSE) |>
  mutate(
    date = as_date(ymd_hms(request_date, quiet = TRUE)),
    requests = as.numeric(requests),
    day_of_week = wday(date, label = TRUE, abbr = FALSE, week_start = 1),
    day_of_year = yday(date),
    month = month(date, label = TRUE, abbr = FALSE),
    weekend = if_else(wday(date, week_start = 1) >= 6, 1, 0),
    annual_sine = sin(2 * pi * day_of_year / 365.25),
    annual_cosine = cos(2 * pi * day_of_year / 365.25)
  ) |>
  arrange(date)

if (nrow(daily) != 365) {
  stop("Expected 365 daily observations, but found ", nrow(daily), ".")
}

if (anyNA(daily$date) || anyNA(daily$requests)) {
  stop("The date or request-count column contains missing values.")
}

# -----------------------------------------------------------------------------
# 2. Descriptive statistics
# -----------------------------------------------------------------------------

summary_statistics <- tibble(
  observations = nrow(daily),
  total_requests = sum(daily$requests),
  mean = mean(daily$requests),
  standard_deviation = sd(daily$requests),
  minimum = min(daily$requests),
  percentile_25 = quantile(daily$requests, 0.25),
  median = median(daily$requests),
  percentile_75 = quantile(daily$requests, 0.75),
  maximum = max(daily$requests)
)

write_csv(summary_statistics, file.path(result_dir, "summary_statistics.csv"))

# -----------------------------------------------------------------------------
# 3. Linear regression with a chronological train/test split
# -----------------------------------------------------------------------------

train_rows <- 292
train <- daily[1:train_rows, ]
test <- daily[(train_rows + 1):nrow(daily), ]

regression_model <- lm(
  requests ~ day_of_week + annual_sine + annual_cosine,
  data = train
)

train <- train |>
  mutate(
    predicted = predict(regression_model, newdata = train),
    residual = requests - predicted
  )

test <- test |>
  mutate(predicted = predict(regression_model, newdata = test))

baseline_prediction <- mean(train$requests)

model_mae <- mean(abs(test$requests - test$predicted))
model_rmse <- sqrt(mean((test$requests - test$predicted)^2))
test_r_squared <- 1 - (
  sum((test$requests - test$predicted)^2) /
    sum((test$requests - mean(test$requests))^2)
)

baseline_mae <- mean(abs(test$requests - baseline_prediction))
baseline_rmse <- sqrt(mean((test$requests - baseline_prediction)^2))

durbin_watson <- sum(diff(train$residual)^2) / sum(train$residual^2)
lag_1_autocorrelation <- cor(
  train$residual[-nrow(train)],
  train$residual[-1]
)

model_metrics <- tibble(
  model = c("Linear regression", "Mean baseline"),
  mae = c(model_mae, baseline_mae),
  rmse = c(model_rmse, baseline_rmse),
  test_r_squared = c(test_r_squared, NA_real_)
)

write_csv(model_metrics, file.path(result_dir, "model_metrics.csv"))

# -----------------------------------------------------------------------------
# 4. K-means clustering
# -----------------------------------------------------------------------------

set.seed(42)
scaled_cluster_fields <- scale(daily |> dplyr::select(requests, weekend))
kmeans_model <- kmeans(scaled_cluster_fields, centers = 3, nstart = 25)

clustered <- daily |>
  mutate(cluster_id = kmeans_model$cluster)

raw_cluster_profile <- clustered |>
  group_by(cluster_id) |>
  summarise(
    days = n(),
    average_requests = mean(requests),
    weekend_share = mean(weekend),
    .groups = "drop"
  )

weekend_cluster <- raw_cluster_profile$cluster_id[
  which.max(raw_cluster_profile$weekend_share)
]
extreme_cluster <- raw_cluster_profile$cluster_id[
  which.max(raw_cluster_profile$average_requests)
]
typical_cluster <- setdiff(
  raw_cluster_profile$cluster_id,
  c(weekend_cluster, extreme_cluster)
)

cluster_labels <- tibble(
  cluster_id = c(weekend_cluster, typical_cluster, extreme_cluster),
  cluster = c(
    "Weekend days",
    "Typical weekdays",
    "Extreme-volume weekdays"
  )
)

clustered <- clustered |>
  left_join(cluster_labels, by = "cluster_id") |>
  mutate(
    cluster = factor(
      cluster,
      levels = c(
        "Weekend days",
        "Typical weekdays",
        "Extreme-volume weekdays"
      )
    )
  )

cluster_summary <- clustered |>
  group_by(cluster) |>
  summarise(
    days = n(),
    average_requests = mean(requests),
    minimum_requests = min(requests),
    maximum_requests = max(requests),
    .groups = "drop"
  )

write_csv(cluster_summary, file.path(result_dir, "cluster_summary.csv"))

# -----------------------------------------------------------------------------
# 5. Visualizations
# -----------------------------------------------------------------------------

portfolio_theme <- theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold"),
    panel.grid.minor = element_blank(),
    legend.position = "top"
  )

actual_vs_predicted <- ggplot(test, aes(x = date)) +
  geom_line(aes(y = requests, color = "Actual requests"), linewidth = 0.8) +
  geom_line(aes(y = predicted, color = "Predicted requests"), linewidth = 0.9) +
  scale_color_manual(values = c(
    "Actual requests" = "#1F4E79",
    "Predicted requests" = "#C55A11"
  )) +
  labs(
    title = "Actual and Predicted Daily DEP Phone Requests",
    x = "Date",
    y = "Daily requests",
    color = NULL
  ) +
  portfolio_theme

ggsave(
  file.path(visual_dir, "actual_vs_predicted.png"),
  actual_vs_predicted,
  width = 9.2,
  height = 4.8,
  dpi = 300
)

acf_values <- acf(train$residual, lag.max = 20, plot = FALSE)$acf[-1]
acf_table <- tibble(
  lag = seq_along(acf_values),
  autocorrelation = as.numeric(acf_values)
)
acf_bound <- 1.96 / sqrt(nrow(train))

residual_autocorrelation <- ggplot(
  acf_table,
  aes(x = lag, y = autocorrelation)
) +
  geom_col(fill = "#5B9BD5", width = 0.72) +
  geom_hline(yintercept = 0, color = "#595959") +
  geom_hline(
    yintercept = c(-acf_bound, acf_bound),
    color = "#C55A11",
    linetype = "dashed"
  ) +
  scale_x_continuous(breaks = 1:20) +
  labs(
    title = "Autocorrelation of Linear Regression Residuals",
    x = "Lag in days",
    y = "Autocorrelation"
  ) +
  portfolio_theme

ggsave(
  file.path(visual_dir, "residual_autocorrelation.png"),
  residual_autocorrelation,
  width = 9.2,
  height = 4.8,
  dpi = 300
)

cluster_colors <- c(
  "Weekend days" = "#70AD47",
  "Typical weekdays" = "#5B9BD5",
  "Extreme-volume weekdays" = "#C00000"
)

cluster_scatterplot <- ggplot(
  clustered,
  aes(x = date, y = requests, color = cluster)
) +
  geom_point(alpha = 0.8, size = 2) +
  scale_color_manual(values = cluster_colors) +
  labs(
    title = "K-Means Clusters of Daily DEP Phone Requests",
    x = "Date",
    y = "Daily requests",
    color = NULL
  ) +
  portfolio_theme

ggsave(
  file.path(visual_dir, "kmeans_clusters.png"),
  cluster_scatterplot,
  width = 9.2,
  height = 4.8,
  dpi = 300
)

cluster_average_chart <- ggplot(
  cluster_summary,
  aes(x = cluster, y = average_requests, fill = cluster)
) +
  geom_col(width = 0.62, show.legend = FALSE) +
  geom_text(
    aes(label = paste0(round(average_requests), "\n(", days, " days)")),
    vjust = -0.25,
    size = 3.7
  ) +
  scale_fill_manual(values = cluster_colors) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(
    title = "Average Daily Requests by K-Means Cluster",
    x = "Cluster",
    y = "Average daily requests"
  ) +
  portfolio_theme

ggsave(
  file.path(visual_dir, "cluster_averages.png"),
  cluster_average_chart,
  width = 8.2,
  height = 4.8,
  dpi = 300
)

# -----------------------------------------------------------------------------
# 6. Print the main results
# -----------------------------------------------------------------------------

cat("\nNYC 311 DEP phone-demand analysis\n")
cat("---------------------------------\n")
cat("Daily observations:", nrow(daily), "\n")
cat("Total requests:", format(sum(daily$requests), big.mark = ","), "\n")
cat("Highest day:", format(max(daily$requests), big.mark = ","), "requests\n\n")

print(model_metrics)
cat("\nLag-1 residual autocorrelation:", round(lag_1_autocorrelation, 3), "\n")
cat("Durbin-Watson statistic:", round(durbin_watson, 3), "\n\n")
print(cluster_summary)

