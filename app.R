library(shiny)
library(ggplot2)
library(DT)

source("R/model.R")

data_path <- file.path("data", "maize_g2f_environment_means.csv")
if (!file.exists(data_path)) {
  stop("Prepared G2F data are missing. Run source('scripts/prepare_g2f_data.R') first.")
}
trial_data <- read.csv(data_path, stringsAsFactors = FALSE, check.names = FALSE)
trial_data$year_loc <- as.character(trial_data$year_loc)
trial_data$genotype <- as.character(trial_data$genotype)
environments <- unique(trial_data[, c("year_loc", "year", "location", "region")])
environments <- environments[order(environments$year, environments$location), ]
environment_choices <- stats::setNames(
  environments$year_loc,
  paste0(environments$year_loc, " · ", environments$location, " · ", environments$region)
)

ui <- navbarPage(
  title = "Maize G×E Transfer Lab",
  id = "tabs",
  header = tags$head(tags$style(HTML("
    body { background:#f5f7fb; color:#17243a; }
    .navbar { background:#102b3f; border:0; }
    .navbar-default .navbar-brand, .navbar-default .navbar-nav>li>a { color:#f4f8fb; }
    .navbar-default .navbar-brand:hover, .navbar-default .navbar-nav>li>a:hover { color:#a8e2d4; }
    .hero { background:linear-gradient(115deg,#102b3f,#176b67); color:#fff; padding:24px 30px;
      border-radius:12px; margin:18px 0; box-shadow:0 8px 24px rgba(16,43,63,.12); }
    .hero h2 { margin-top:4px; font-weight:700; }
    .hero p { color:#d8e9eb; max-width:900px; font-size:15px; }
    .kpi { background:#fff; border:1px solid #e5eaf0; border-radius:10px; padding:16px 18px;
      min-height:105px; box-shadow:0 2px 8px rgba(16,43,63,.04); }
    .kpi-label { color:#627286; font-size:12px; text-transform:uppercase; letter-spacing:.07em; }
    .kpi-value { color:#102b3f; font-size:25px; font-weight:700; margin-top:7px; }
    .panel, .well { border-color:#e5eaf0; border-radius:10px; box-shadow:0 2px 8px rgba(16,43,63,.035); }
    .note { background:#edf7f5; border-left:4px solid #248276; padding:12px 15px; margin:14px 0;
      border-radius:3px; }
    .small-muted { color:#65778a; font-size:12px; }
    .btn-primary { background:#176b67; border-color:#176b67; }
    .btn-primary:hover { background:#125551; border-color:#125551; }
  "))),
  tabPanel("Decision dashboard",
    fluidPage(
      div(class = "hero",
        span("PUBLIC G2F TRIAL DATA · R SHINY · ENVIRONMENT-LEVEL VALIDATION"),
        h2("Can a hybrid's past performance travel to a new environment?"),
        p("Compare a historical hybrid-mean baseline with an environment-aware transfer adjustment. Every validation fold holds out a complete year-location trial, so plots from the target environment never leak into model fitting.")),
      fluidRow(
        column(3, div(class = "kpi", div(class = "kpi-label", "Trial environments"),
                      div(class = "kpi-value", textOutput("kpi_env", inline = TRUE)))),
        column(3, div(class = "kpi", div(class = "kpi-label", "Hybrid entries"),
                      div(class = "kpi-value", textOutput("kpi_hybrids", inline = TRUE)))),
        column(3, div(class = "kpi", div(class = "kpi-label", "Plot records summarized"),
                      div(class = "kpi-value", textOutput("kpi_plots", inline = TRUE)))),
        column(3, div(class = "kpi", div(class = "kpi-label", "Trial years"),
                      div(class = "kpi-value", textOutput("kpi_years", inline = TRUE))))),
      fluidRow(
        column(4,
          wellPanel(
            h4("Target environment"),
            p(class = "small-muted", "Its observed yield is withheld during prediction and used only for validation."),
            selectInput("target_env", "Year · location", choices = environment_choices,
                        selected = environments$year_loc[nrow(environments)]),
            sliderInput("min_envs", "Minimum prior environments per hybrid", min = 1, max = 10,
                        value = 3, step = 1),
            sliderInput("lambda", "Environmental ridge penalty", min = 0.1, max = 20,
                        value = 1, step = 0.1),
            actionButton("run_validation", "Run grouped leave-one-environment-out validation",
                         class = "btn-primary", width = "100%"),
            br(), br(), textOutput("validation_status"),
            div(class = "note", "Prediction scope: hybrids with prior trial history. This is environment-transfer validation, not prediction for never-tested genotypes."))),
        column(8,
          tabsetPanel(
            tabPanel("Shortlist", br(),
              p("Rank hybrids for the selected target environment using their historical mean plus an environmental adjustment learned without the target trial. The uncertainty proxy is across-environment SD."),
              plotOutput("shortlist_plot", height = 350),
              downloadButton("download_shortlist", "Download shortlist CSV"), br(), br(),
              DTOutput("shortlist_table")),
            tabPanel("Validation", br(),
              p("All year-location environments are held out in turn. Metrics pool hybrid-environment means for hybrids with prior observations."),
              fluidRow(column(6, selectInput("validation_model", "Prediction shown",
                choices = c("Environment-aware transfer", "Historical hybrid mean"))),
                column(6, uiOutput("validation_kpis"))),
              plotOutput("validation_scatter", height = 350),
              h4("Pooled validation metrics"), DTOutput("metrics_table"), br(),
              h4("Performance by held-out environment"), DTOutput("environment_table")),
            tabPanel("Environment profile", br(),
              p("Environmental covariates are stage-specific thermal time and soil-water summaries supplied with the G2F curated release."),
              plotOutput("environment_plot", height = 380),
              DTOutput("environment_covariates")))))
    )),
  tabPanel("Data & methods",
    fluidPage(
      h3("Data provenance"),
      p("Observed maize plot yields come from the curated Genomes-to-Fields (G2F) North American trials. Plot records are averaged within hybrid × year-location environment; four environment covariates are retained for the transfer model."),
      p("The source dataset is released under Creative Commons Attribution 4.0. The prepared CSV is a transformed subset of the source data. See data/README.md for citation, attribution, and the source license."),
      h3("Validation design"),
      tags$ol(
        tags$li("Aggregate plot-level yield to hybrid × year-location means. A fold holds out every hybrid observation from one entire year-location environment."),
        tags$li("Baseline prediction: a hybrid's average yield across its available training environments."),
        tags$li("Transfer prediction: the same hybrid historical mean plus an environmental shift predicted from four stage-specific covariates. A ridge model is trained on environment-level mean yields from training environments only."),
        tags$li("Score only hybrids observed in both the training environments and held-out target. Report pooled RMSE, MAE, bias, Spearman rank correlation, and per-environment RMSE.")),
      h3("Interpretation"),
      p("This demonstrates a phenotype-based, environment-transfer benchmark on real public trials. It does not use marker genotypes, estimate genomic breeding values, identify causal weather effects, or establish performance in a commercial breeding program. Environmental covariates may be correlated; predictions are exploratory and should not be used as operational selection advice."),
      h3("Reproduce the data preparation"),
      p("Run source('scripts/prepare_g2f_data.R') from the project root. The script downloads the versioned Figshare archive, reads only phenotype and environment tables, aggregates the released plot records, and saves a source manifest."),
      h3("Model specification"),
      withMathJax(),
      helpText("ŷᵢₑ = ȳᵢ,train + (m̂ₑ − m̄train), where m̂ₑ is the ridge-predicted environment mean from environmental covariates. The baseline is ȳᵢ,train."),
      p("See README.md and docs/methods.md for implementation details and limitations.")))
)

server <- function(input, output, session) {
  output$kpi_env <- renderText(length(unique(trial_data$year_loc)))
  output$kpi_hybrids <- renderText(length(unique(trial_data$genotype)))
  output$kpi_plots <- renderText(format(sum(trial_data$plot_count), big.mark = ","))
  output$kpi_years <- renderText(paste(range(trial_data$year), collapse = "–"))

  shortlist <- reactive({
    req(input$target_env)
    selection_table(trial_data, input$target_env, lambda = input$lambda,
                    min_envs = input$min_envs)
  })
  validation <- eventReactive(input$run_validation, {
    withProgress(message = "Holding out complete trial environments", value = 0, {
      result <- run_leave_environment_out(trial_data, lambda = input$lambda)
      incProgress(1)
      result
    })
  }, ignoreNULL = TRUE)

  output$validation_status <- renderText({
    if (is.null(validation())) return("Run grouped validation when you are ready.")
    n <- nrow(validation()$predictions)
    if (!n) "Not enough overlapping hybrid histories for validation." else
      paste(format(n, big.mark = ","), "hybrid-environment predictions scored")
  })

  output$shortlist_plot <- renderPlot({
    tab <- head(shortlist(), 15)
    req(nrow(tab))
    tab$genotype <- factor(tab$genotype, levels = rev(tab$genotype))
    ggplot(tab, aes(predicted_target_yield, genotype, fill = across_environment_sd)) +
      geom_col(width = .78) +
      scale_fill_viridis_c(option = "C", direction = -1, name = "Across-env.\nSD") +
      labs(x = "Predicted target-environment yield (source scale)", y = NULL,
           title = "Top 15 candidates by predicted target yield") +
      theme_minimal(base_size = 12) + theme(panel.grid.major.y = element_blank(),
                                             plot.title = element_text(face = "bold"))
  })
  output$shortlist_table <- renderDT({
    tab <- head(shortlist(), 100)
    if (!nrow(tab)) return(datatable(data.frame(Message = "No eligible hybrids.")))
    tab$rank <- seq_len(nrow(tab))
    tab <- tab[, c("rank", "genotype", "predicted_target_yield", "historical_mean",
                   "across_environment_sd", "n_training_environments", "target_environment")]
    datatable(tab, rownames = FALSE, options = list(pageLength = 10, scrollX = TRUE)) |>
      formatRound(c("predicted_target_yield", "historical_mean", "across_environment_sd"), 3)
  })
  output$download_shortlist <- downloadHandler(
    filename = function() paste0("maize-gxe-shortlist-", gsub("[^A-Za-z0-9-]", "-", input$target_env), ".csv"),
    content = function(file) write.csv(shortlist(), file, row.names = FALSE)
  )

  selected_predictions <- reactive({
    req(validation())
    d <- validation()$predictions
    d[d$year_loc == input$target_env, , drop = FALSE]
  })
  output$validation_kpis <- renderUI({
    req(nrow(selected_predictions()) > 0)
    d <- selected_predictions()
    model_col <- if (input$validation_model == "Historical hybrid mean")
      "historical_mean_prediction" else "environment_transfer_prediction"
    m <- regression_metrics(d$yield_mean, d[[model_col]])
    tagList(span(sprintf("n = %s", format(m$n, big.mark = ","))), HTML(" &nbsp; "),
            span(sprintf("RMSE = %.3f", m$RMSE)), HTML(" &nbsp; "),
            span(sprintf("Spearman = %.2f", m$Spearman)))
  })
  output$validation_scatter <- renderPlot({
    d <- selected_predictions()
    req(nrow(d))
    model_col <- if (input$validation_model == "Historical hybrid mean")
      "historical_mean_prediction" else "environment_transfer_prediction"
    d$prediction <- d[[model_col]]
    ggplot(d, aes(prediction, yield_mean)) +
      geom_point(alpha = .35, color = "#176b67", size = 1.4) +
      geom_abline(slope = 1, intercept = 0, linetype = 2, color = "#d9823b") +
      labs(x = "Predicted yield (source scale)", y = "Observed held-out yield (source scale)",
           title = paste("Held-out trial:", input$target_env),
           subtitle = "Each point is a hybrid mean. The dashed line is perfect prediction.") +
      theme_minimal(base_size = 12)
  })
  output$metrics_table <- renderDT({
    req(nrow(validation()$metrics) > 0)
    datatable(validation()$metrics[, c("model", "n", "RMSE", "MAE", "Bias", "Spearman")],
              rownames = FALSE, options = list(dom = "t", scrollX = TRUE)) |>
      formatRound(c("RMSE", "MAE", "Bias", "Spearman"), 3)
  })
  output$environment_table <- renderDT({
    req(nrow(validation()$by_environment) > 0)
    datatable(validation()$by_environment, rownames = FALSE,
              options = list(pageLength = 10, scrollX = TRUE)) |>
      formatRound(c("RMSE_baseline", "RMSE_transfer", "Spearman_baseline", "Spearman_transfer"), 3)
  })

  output$environment_plot <- renderPlot({
    env <- environments[environments$year_loc == input$target_env, , drop = FALSE]
    req(nrow(env) > 0)
    row <- trial_data[trial_data$year_loc == input$target_env, , drop = FALSE][1, ]
    cov <- data.frame(covariate = TRANSFER_COVARS,
                      value = as.numeric(unlist(row[, TRANSFER_COVARS], use.names = FALSE)))
    ggplot(cov, aes(reorder(covariate, value), value)) +
      geom_col(fill = "#248276", width = .68) + coord_flip() +
      labs(x = NULL, y = "Covariate value (source scale)",
           title = paste("Environmental profile ·", env$year_loc, env$location),
           subtitle = "Variables are not on a common scale; compare each against its own trial history.") +
      theme_minimal(base_size = 12)
  })
  output$environment_covariates <- renderDT({
    row <- trial_data[trial_data$year_loc == input$target_env, , drop = FALSE][1, ]
    cov <- data.frame(covariate = TRANSFER_COVARS,
                      interpretation = c("Thermal time · emergence to flowering",
                                         "Thermal time · flowering to silking",
                                         "Thermal time · silking to grain fill",
                                         "Soil water · grain fill to maturity"),
                      value = as.numeric(unlist(row[, TRANSFER_COVARS], use.names = FALSE)))
    datatable(cov, rownames = FALSE, options = list(dom = "t")) |>
      formatRound("value", 3)
  })
}

shinyApp(ui, server)
