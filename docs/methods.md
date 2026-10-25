# Methods and validation plan

## Analysis unit

The source phenotype table contains plot-level yield. This project takes the arithmetic mean of plot yields for each `genotype × year_loc` cell and preserves the number of source plot records contributing to each mean. The analysis joins one environmental covariate vector per year-location environment. Only rows with finite yield means and all four selected covariates are retained.

## Question

For a genotype already observed in previous trials, how accurately can its yield mean be estimated in a complete year-location environment that was excluded from model fitting? The project intentionally does not represent untested-genotype or genomic prediction.

## Models

**Historical hybrid-mean baseline.** The mean of a hybrid's observed yield means in the training environments.

**Environment-aware additive transfer.** Estimate a ridge regression of training-environment mean yield on four source-provided stage covariates. Use the regression to estimate the target environment's mean response, subtract the mean response across training environments, and add that shift to each hybrid's historical mean.

For standardized training covariates `X`, the environmental ridge coefficients minimize:

```text
sum((environment_mean - intercept - X %*% beta)^2) + lambda * sum(beta^2)
```

The intercept is not penalized. Covariates are centered and scaled with training-environment statistics only. A target fold is never used to estimate hybrid means, environmental coefficients, scaling values, or penalty choice.

## Cross-validation

Leave-one-environment-out (LOEO) validation holds out the entire `year_loc` group. This blocks same-trial plot leakage and better reflects transfer to a new trial than random plot splits. A held-out hybrid is included only if it has at least one valid training observation. For per-environment metric display, the fold must also have the minimum number of overlapping hybrid predictions implemented by the app.

Pooled and per-environment statistics are:

- RMSE and MAE for prediction error in source yield units.
- Bias as mean(predicted − observed).
- Spearman correlation as a rank agreement summary.

Pooled scores weight each scored hybrid-environment pair equally, so environments with more eligible hybrids contribute more. The app also reports environment-specific RMSE to expose heterogeneity.

## Candidate shortlist

For a selected target year-location, the target yield observations are excluded while predictions are generated. Candidates need a user-selected minimum number of historical environments. The app ranks them by predicted target yield and reports historical mean, across-environment standard deviation, and training-environment count. Standard deviation is a descriptive instability measure, not a prediction interval.

## Limitations

- Four covariates and an additive environmental shift simplify complex genotype-by-environment interaction.
- The model does not use SNPs, pedigrees, marker-derived relationships, GCA/SCA, or dominance.
- Covariates can be correlated; ridge regularization reduces coefficient instability but does not prove causal effects.
- Candidate rankings depend on the source trial network and the availability of historical entries.
- The validation concerns the curated source records and does not establish external validity for another breeding program, region, crop year, or management protocol.
- Yield values retain the source data scale; no unit conversion is applied by this project.
