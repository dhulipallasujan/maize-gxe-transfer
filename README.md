# Maize G×E Transfer Lab

**A real-data R Shiny app for validating hybrid performance predictions across maize trial environments.**

Can a hybrid's past trial performance travel to a year-location it has not seen? This project benchmarks a historical hybrid-mean baseline against a simple environment-aware transfer model using curated Genomes-to-Fields (G2F) maize trials. The app makes the held-out environments visible, reports prediction and ranking metrics, and produces a target-environment candidate shortlist.

This project complements the author's genomic-prediction and mixed-model repositories by focusing on **environment transfer, grouped validation, and selection stability**. It uses observed phenotypes and environmental covariates; it does not claim to be genomic selection.

## Why a breeder or data-science recruiter should care

- Uses a documented, open-licensed real maize dataset rather than simulated outcomes.
- Holds out complete year-location trials to avoid plot-level leakage across train and test data.
- Compares an interpretable baseline to an environment-aware model using identical held-out entries.
- Reports RMSE, MAE, bias, and Spearman rank correlation, plus environment-specific performance.
- Shows how model predictions translate into a candidate shortlist and exposes the across-environment variability behind it.
- Includes a reproducible data-preparation script, data-source manifest, methods note, and interactive Shiny interface.

## What the app does

1. Summarizes plot observations into hybrid × year-location mean yields.
2. Trains an environmental ridge regression on mean yields and stage-specific covariates from training environments.
3. Predicts a held-out hybrid mean as its historical training-environment average plus the estimated environmental shift.
4. Evaluates each year-location in turn as a complete holdout and compares it with the historical-mean baseline.
5. Ranks hybrids for a selected held-out target environment, subject to a minimum prior-environment history.

## Data and license

The project uses the phenotype (`PHENO.csv`) and environmental covariate (`ECOV.csv`) tables from the G2F curated release: [Lopez-Cruz et al., *Leveraging Data from the Genomes-to-Fields Initiative to Investigate G×E in Maize in North America*](https://doi.org/10.6084/m9.figshare.22776806). The Figshare record identifies the source license as **Creative Commons Attribution 4.0 International (CC BY 4.0)**. This is openly reusable with attribution; it is not public-domain data. The large marker table is not downloaded or redistributed. The bundled analysis table is an attributed transformation containing hybrid-environment means and selected covariates. See [data/README.md](data/README.md) for the source credit and license details.

The source data are provided by their authors. This repository's MIT license applies to the project code, not the upstream dataset.

## Run locally in RStudio

Open `MaizeGxETransfer.Rproj` and run:

```r
install.packages(c("shiny", "ggplot2", "DT"))
shiny::runApp()
```

The prepared analysis table is included, so no download is needed for the first run. To regenerate it from the source archive:

```r
source("scripts/prepare_g2f_data.R")
```

The script downloads the versioned public Figshare archive (approximately 149 MB) to `data/raw/`, reads only `PHENO.csv` and `ECOV.csv`, and writes the aggregated analysis table and source manifest. The raw archive is excluded from Git.

## Validation and model details

The grouping unit is the complete G2F `year_loc` trial environment. For each fold, every hybrid observation from that environment is removed before estimating hybrid historical means and the environmental response model. Only hybrids with prior observations are scored. This measures **environment transfer for previously observed hybrids**; it does not measure prediction for new genotypes or new breeding populations.

### Reproduced benchmark on the bundled data

The fixed ridge penalty (`lambda = 1`) was run across all **136 held-out environments**, producing **52,037** scored hybrid-environment predictions. The environment-aware model modestly improved pooled RMSE and MAE and improved rank correlation on this dataset; it also had a small positive prediction bias. These are internal grouped-validation results, not evidence of generalization to another breeding program.

| Model | RMSE | MAE | Bias | Spearman rank correlation |
| --- | ---: | ---: | ---: | ---: |
| Historical hybrid mean | 2.671 | 2.128 | 0.000 | 0.326 |
| Environment-aware transfer | 2.645 | 2.114 | +0.055 | 0.393 |

The environment model uses four covariates from the source release: thermal time from emergence to flowering (`TT_EnJFlo`), flowering to silking (`TT_FlaFlw`), silking to grain fill (`TT_FlwStG`), and soil water from grain fill to maturity (`SW_EnGMat`). Ridge regularization stabilizes the small environment-level regression. No covariate selection is performed against held-out yields.

For hybrid *i* and held-out environment *e*:

```text
transfer prediction = mean hybrid yield in training environments
                    + (predicted environment mean - training environment grand mean)
baseline prediction = mean hybrid yield in training environments
```

This is an additive transfer benchmark. It does not estimate genotype-specific environmental sensitivity, GCA/SCA, marker effects, causal weather response, or prediction uncertainty. See [docs/methods.md](docs/methods.md) for assumptions and interpretation.

## Repository layout

```text
app.R                                  Shiny dashboard
R/model.R                              Transfer model and grouped validation
scripts/prepare_g2f_data.R             Reproducible source-data preparation
data/maize_g2f_environment_means.csv   Attributed, aggregated analysis table
data/source_manifest.csv               Source and preparation counts
data/README.md                         Dataset citation and license note
docs/methods.md                        Statistical design and limitations
```

## Responsible interpretation

The shortlist is a research demonstration, not an operational recommendation. Trial protocols, target population of environments, hybrid history, covariate definitions, and selection objectives all affect practical use. Review the source record and local licensing terms before redistributing data or a derived dataset.
