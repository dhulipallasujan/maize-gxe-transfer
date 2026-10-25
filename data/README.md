# Data attribution and reuse

The bundled `maize_g2f_environment_means.csv` is a transformed, aggregated subset of the following source dataset:

> Lopez-Cruz, M., Aguate, F., Washburn, J. D., de Leon, N., Kaeppler, S. M., Lima, D. C., Tan, R., Thompson, A. M., de la Bretonne, L., & de los Campos, G. (2023). *Leveraging Data from the Genomes-to-Fields Initiative to Investigate G×E in Maize in North America*. Figshare. DOI: [10.6084/m9.figshare.22776806](https://doi.org/10.6084/m9.figshare.22776806).

The Figshare record lists **CC BY 4.0**. The source dataset remains subject to that attribution license; see the [Creative Commons Attribution 4.0 terms](https://creativecommons.org/licenses/by/4.0/). This repository's MIT code license does not replace or override the dataset license.

The project uses the public phenotype and environment-covariate tables (`PHENO.csv` and `ECOV.csv`) from the versioned `curated_data.zip` file (`https://ndownloader.figshare.com/files/42590572`). The source marker table is not included. Plot observations are averaged by hybrid (`genotype`) and year-location (`year_loc`); selected environmental covariates and source identifiers are retained. Counts in `source_manifest.csv` describe the local preparation.

For new preparation, run `source("scripts/prepare_g2f_data.R")` from the repository root. The script stores the downloaded source archive under `data/raw/`, a directory excluded from Git.
