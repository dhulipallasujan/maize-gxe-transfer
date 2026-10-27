# Download and prepare the publicly released Genomes-to-Fields maize data.
# Data DOI: 10.6084/m9.figshare.22776806 (CC BY 4.0; see data/README.md).

dir.create("data", showWarnings = FALSE, recursive = TRUE)
dir.create("data/raw", showWarnings = FALSE, recursive = TRUE)
archive <- file.path("data", "raw", "g2f_curated_data.zip")
if (!file.exists(archive)) {
  options(timeout = max(600, getOption("timeout")))
  download.file("https://ndownloader.figshare.com/files/42590572", archive,
                mode = "wb", method = "libcurl", quiet = FALSE)
}

phenotypes <- read.csv(unz(archive, "data/PHENO.csv"), stringsAsFactors = FALSE)
environment_covariates <- read.csv(unz(archive, "data/ECOV.csv"), stringsAsFactors = FALSE,
                                   check.names = FALSE)
covariates <- c("TT_EnJFlo", "TT_FlaFlw", "TT_FlwStG", "SW_EnGMat")
required <- c("year_loc", "year", "location", "genotype", "region", "yield")
missing <- setdiff(required, names(phenotypes))
if (length(missing)) stop("Required phenotype fields are missing: ", paste(missing, collapse = ", "))
if (!all(c("X", covariates) %in% names(environment_covariates))) {
  stop("Expected environment covariates were not found in ECOV.csv.")
}

phenotypes$yield <- suppressWarnings(as.numeric(phenotypes$yield))
phenotypes <- phenotypes[is.finite(phenotypes$yield) & !is.na(phenotypes$genotype), , drop = FALSE]
env_meta <- phenotypes[!duplicated(phenotypes$year_loc),
                       c("year_loc", "year", "location", "region"), drop = FALSE]
mean_table <- aggregate(yield ~ year_loc + genotype, phenotypes, mean)
names(mean_table)[3] <- "yield_mean"
count_table <- aggregate(yield ~ year_loc + genotype, phenotypes, length)
names(count_table)[3] <- "plot_count"
hybrid_means <- merge(mean_table, count_table, by = c("year_loc", "genotype"))
hybrid_means <- merge(hybrid_means, env_meta, by = "year_loc", all.x = TRUE)

environment_covariates <- environment_covariates[, c("X", covariates), drop = FALSE]
names(environment_covariates)[1] <- "year_loc"
environment_covariates$year_loc <- as.character(environment_covariates$year_loc)
hybrid_means$year_loc <- as.character(hybrid_means$year_loc)
prepared <- merge(hybrid_means, environment_covariates, by = "year_loc", all.x = TRUE)
prepared <- prepared[complete.cases(prepared[, c("yield_mean", covariates)]) &
                       is.finite(prepared$yield_mean), , drop = FALSE]
prepared <- prepared[, c("year_loc", "year", "location", "region", "genotype",
                         "yield_mean", "plot_count", covariates)]
prepared <- prepared[order(prepared$year, prepared$location, prepared$genotype), ]
write.csv(prepared, file.path("data", "maize_g2f_environment_means.csv"), row.names = FALSE)

manifest <- data.frame(source = "G2F curated maize trials",
                       doi = "10.6084/m9.figshare.22776806",
                       license = "CC BY 4.0",
                       usable_plot_records = nrow(phenotypes),
                       prepared_hybrid_environment_means = nrow(prepared),
                       environments = length(unique(prepared$year_loc)),
                       genotypes = length(unique(prepared$genotype)),
                       prepared_on = as.character(Sys.Date()))
write.csv(manifest, file.path("data", "source_manifest.csv"), row.names = FALSE)
message("Prepared ", nrow(prepared), " hybrid-by-environment means across ",
        length(unique(prepared$year_loc)), " environments.")
