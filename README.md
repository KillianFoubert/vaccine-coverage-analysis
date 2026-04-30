# Global Childhood Vaccination Coverage, 1980-2023

A reproducible analysis of childhood DTP3 vaccination coverage across 195 countries, applying panel data econometrics, mixed-effects modeling, causal inference, and spatial visualization.

**Live report:** [KillianFoubert.github.io/vaccine-coverage-analysis](https://KillianFoubert.github.io/vaccine-coverage-analysis) (English) / [KillianFoubert.github.io/vaccine-coverage-analysis/index_fr.html](https://KillianFoubert.github.io/vaccine-coverage-analysis/index_fr.html) (Français)

**Methodological appendix:** [`docs/sessions_explained.md`](docs/sessions_explained.md)

---

## Overview

This project demonstrates a complete applied econometrics workflow on a public health question of operational importance: what drives variation in childhood vaccination coverage worldwide, and how did COVID-19 disrupt vaccination services?

The analysis combines three public data sources (WUENIC, WDI, OxCGRT) into a 1980-2023 country-year panel and applies four complementary methodologies:

- Panel fixed effects with cluster-robust inference (`fixest`)
- Pooled logit for binary classification (`glm`, `margins`, `sandwich`)
- Linear mixed-effects models with random intercepts and slopes (`lme4`)
- Continuous-treatment difference-in-differences with event study and placebo testing (`fixest`)
- Choropleth maps for spatial visualization (`sf`, `rnaturalearth`)

Bilingual reports are rendered to GitHub Pages with `rmarkdown`.

## Key findings

- **Fertility** is the strongest within-country structural determinant of DTP3 coverage. A one-unit increase in fertility is associated with a 5.8 percentage point decrease in coverage.
- **Country trajectories vary widely**: Niger, Sierra Leone, and Uganda gained more than 14 points per decade since 2000, while Ukraine, Papua New Guinea, and Azerbaijan lost more than 10.
- **The COVID-19 disruption was real but moderate**: about 1 percentage point per standard deviation of stringency intensity, with full recovery apparent by 2022-2023.

## Repository structure

```
vaccine-coverage-analysis/
├── R/
│   ├── 01_download_data.R           # WUENIC + WDI + OxCGRT download
│   ├── 02_build_panel.R             # Panel construction, ISO3 + WHO regions
│   ├── 03_descriptive.R             # Trends, regions, COVID, left-behind
│   ├── 04_fixed_effects.R           # Two-way panel FE with fixest
│   ├── 05_logit_regional.R          # Logit on left-behind, marginal effects
│   ├── 06_mixed_models.R            # lme4 with random intercepts and slopes
│   ├── 07_did_covid.R               # Continuous-treatment DiD + event study
│   ├── 08_maps.R                    # 4 choropleth maps via sf/rnaturalearth
│   └── 09_render_reports.R          # Compile RMarkdown to docs/
├── rmd/
│   ├── report_en.Rmd                # English report source
│   └── report_fr.Rmd                # French report source
├── data/
│   ├── raw/                         # Downloaded data (timestamped)
│   └── processed/                   # panel.rds + panel.csv
├── output/
│   ├── figures/                     # 12 PNG figures
│   ├── tables/                      # 12 CSV tables
│   └── models/                      # Saved RDS models for inspection
├── docs/
│   ├── index.html                   # Compiled English report
│   ├── index_fr.html                # Compiled French report
│   └── sessions_explained.md        # Methodological appendix
├── run_all.R                        # Master orchestration script
├── dependencies.R                   # Required packages
└── README.md                        # This file
```

## Methodological highlights

### Two-way fixed effects

The panel specification controls for both country and year fixed effects, identifying coefficients via residual within-country, within-year variation. This conservative design absorbs time-invariant country characteristics (institutions, geography) and common temporal shocks (global cycles, pandemic). See [`docs/sessions_explained.md`](docs/sessions_explained.md) for a detailed discussion of why three-way FE would saturate the model and why region-by-year FE could be a future robustness check.

### Mixed models with partial pooling

The mixed-effects model leverages the entire panel to produce country-specific BLUPs (Best Linear Unbiased Predictors), which are weighted averages between each country's own data and the global mean. This gives more reliable trajectory estimates than naive country-by-country regressions, especially for countries with noisy data. The mathematical foundation is the James-Stein theorem.

### Continuous-treatment DiD

Since no country was a "control" during COVID, we exploit cross-country variation in stringency intensity (OxCGRT). The design is validated by parallel trends (event study) and a placebo test on the pre-treatment period. The resulting estimate is conservative and explicitly framed as a *plausible causal estimate* of the disruption channel through non-pharmaceutical interventions.

## How to reproduce

### Prerequisites

R version 4.4 or higher, with the packages listed in `dependencies.R`.

### Quick start

```bash
git clone https://github.com/KillianFoubert/vaccine-coverage-analysis
cd vaccine-coverage-analysis
Rscript dependencies.R
Rscript run_all.R
```

The full pipeline takes about 3-5 minutes on a standard laptop. Outputs are in `data/processed/`, `output/`, and `docs/`.

### Selective re-runs

The master script supports targeted re-runs:

```r
# Skip data download (use cached files)
SKIP_DOWNLOAD <- TRUE
source("run_all.R")

# Restart from a specific step
START_FROM <- "06"
source("run_all.R")

# Skip report compilation
SKIP_REPORTS <- TRUE
source("run_all.R")
```

## Data sources

All sources are public and freely accessible:

- **WUENIC**: WHO/UNICEF Estimates of National Immunization Coverage. Accessed via the WHO Global Health Observatory API.
- **WDI**: World Development Indicators, World Bank. Accessed via the `WDI` R package.
- **OxCGRT**: Oxford COVID-19 Government Response Tracker. Accessed via the project's GitHub release.

## Limitations

- The DTP3 indicator captures only one dimension of immunization performance.
- Country-level analysis cannot reveal sub-national heterogeneity (rural-urban gaps, conflict zones, ethnic disparities).
- The DiD assumes parallel trends, which is validated but not proven.

See the conclusion section of the report for a full discussion.

## Author

Killian Foubert, PhD in economics (Ghent University / UNU-CRIS), specializing in quantitative methods, panel data econometrics, and applied causal inference.

- GitHub: [@KillianFoubert](https://github.com/KillianFoubert)

## License

This project is released under the MIT License. Data sources retain their original licenses.
