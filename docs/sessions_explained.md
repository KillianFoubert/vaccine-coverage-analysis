# Methodological appendix: choices and rationale

This document complements the main report (`docs/index.html`) by gathering, in one place, the methodological reasoning behind each step of the analysis. It is intended as a reference for the analyst (myself) and for curious readers (recruiters, collaborators, fellow researchers) who want to understand not just *what* was done but *why*.

The document is organized chronologically by analytical session, mirroring the structure of the project's development.

## Table of contents

1. Session 1: data sources and panel construction
2. Session 2: fixed effects and logit
3. Session 3: mixed models and DiD COVID
4. Session 4: choropleth maps
5. Cross-cutting methodological notes

---

## 1. Session 1: data sources and panel construction

### Why DTP3 as the main outcome

Among all immunization indicators, the third dose of diphtheria-tetanus-pertussis (DTP3) was selected as the project's main outcome for three reasons. First, it is the international benchmark used by WHO in all annual reports, which makes results directly comparable to existing literature. Second, DTP3 measures more than vaccine availability: it implies that a child has had at least three distinct contacts with the health system before age one, which jointly captures geographic accessibility, continuity of care, and household demand. Third, the threshold of DTP3 < 80% has been formalized as the criterion for identifying "left-behind" countries, providing a natural binary outcome for the logit analysis.

### Why three data sources

The combination of WUENIC (WHO/UNICEF), WDI (World Bank), and OxCGRT (Oxford COVID-19) was chosen to address three complementary dimensions:

- **WUENIC** provides the outcome variable with the highest international credibility (jointly validated by WHO and UNICEF since 1980).
- **WDI** provides the structural covariates (GDP per capita, health expenditure, urbanization, fertility) that allow modeling of the determinants.
- **OxCGRT** provides the continuous treatment variable for the COVID DiD analysis, capturing the intensity of national pandemic responses.

All three sources are public, machine-readable, and have stable APIs, which guarantees reproducibility.

### Why panel data, not cross-section

A pure cross-sectional analysis would compare countries at a single point in time and risk attributing differences to spurious cross-country correlations (e.g., richer countries tend to have higher coverage *and* lower fertility, so a cross-sectional regression cannot disentangle the two effects). The panel structure allows controlling for unobserved time-invariant country characteristics through fixed effects, which is fundamental to the identification strategy in Sections 4 to 7 of the report.

### Why aggregating OxCGRT to yearly means

The OxCGRT data are daily, with up to 366 observations per country-year. Yearly aggregation was chosen for two reasons. First, the outcome variable (DTP3 coverage) is reported annually, so any finer temporal resolution would be wasted. Second, year-on-year stringency is the relevant policy variable for an annual coverage outcome. The minimum requirement of 60 valid daily observations per country-year ensures that the yearly mean is well-defined.

### Why 1980-2023 (full panel) but 2000-2023 (estimation samples)

The full panel covers 1980-2023 to faithfully represent the WUENIC dataset, but estimation is restricted to 2000-2023 for two reasons. First, WDI covariates (especially health expenditure) have systematic missingness before 2000. Restricting to 2000-2023 boosts completeness from around 70% to over 99% on covariates. Second, the COVID DiD requires a credible pre-treatment baseline, which is well-served by 2015-2019.

---

## 2. Session 2: fixed effects and logit

### Two-way fixed effects: country FE + year FE

The main panel specification includes both country fixed effects ($\alpha_i$) and year fixed effects ($\gamma_t$). This is what is meant by "two-way fixed effects" in the panel data literature.

**What two-way FE absorbs.** The country FE absorbs everything that is constant in time for each country: geography, colonial history, institutional quality, baseline cultural attitudes toward vaccination. The year FE absorbs everything that affects all countries equally in a given year: global Gavi campaigns, common economic cycles, pandemics. After both sets of FE, the variation that remains is the within-country, within-year deviation from each country's mean and from the global trend.

**Mathematical mechanism: double demeaning.** Two-way FE estimation is mathematically equivalent to applying the following transformation to each variable:

$$
\tilde{y}_{it} = y_{it} - \bar{y}_{i\cdot} - \bar{y}_{\cdot t} + \bar{y}_{\cdot\cdot}
$$

where $\bar{y}_{i\cdot}$ is the country mean, $\bar{y}_{\cdot t}$ is the year mean, and $\bar{y}_{\cdot\cdot}$ is the grand mean. This is called "double demeaning". The OLS regression on these transformed variables gives identical coefficients to the regression with FE dummies. The regression then identifies effects via the residual variation: "in country $i$ in year $t$, was the coverage higher or lower than what country $i$'s overall level and year $t$'s global trend would predict?".

**Why some variables lose significance under two-way FE.** Variables that vary little within countries over the panel period (urbanization changes by fractions of a percentage point per year) cannot have their effect reliably identified once country FE are included. Their variance is essentially absorbed into $\alpha_i$. This is precisely what we observe: `urban_pct` and `health_exp` are significant in pooled OLS (which exploits between-country variation) but lose significance under country FE. This is not a null result in a substantive sense, but a methodological one: we cannot identify these effects without exploiting cross-country variation, which the FE design intentionally rules out.

**Why log GDP changes substantially under two-way FE.** Adding year FEs increases the log GDP coefficient from 4.15 to 5.71. This means that common temporal shocks (especially the 2020-2021 pandemic period and global growth cycles) were correlated with cross-country GDP variation in ways that biased the simpler specification downward. The two-way FE strips this contamination, isolating the within-country effect.

### What three-way FE (country × year) would do

A natural question is: why not include country × year interactions for even tighter identification? The answer is that three-way FE would saturate the model. Each observation is uniquely identified by (country, year), so country × year FE would absorb all variation. There would be no residual variation left to estimate covariate effects.

A more sensible refinement, used in some papers, is **region × year FE**. This absorbs any time-varying shock specific to a WHO region (e.g., the Sahel crisis 2012-2014 affecting AFRO but not EURO) without saturating the model. This could be added as a robustness check in future iterations of the project.

### Why cluster-robust standard errors at the country level

Observations within the same country across years are not independent. Many factors (institutional quality, ongoing programs) generate within-country serial correlation in the residuals. Naive standard errors (assuming independence) underestimate the true uncertainty. Clustering at the country level allows for arbitrary serial correlation within each country and gives the conservative inference appropriate for panel data. This typically inflates standard errors by 30-50% compared to OLS standard errors, which prevents over-interpretation of marginally significant results.

### Why a logit with regional FE (and not country FE)

For the binary outcome "left-behind" (DTP3 < 80%), a country-FE logit would mechanically drop all countries that are always above 80% (e.g., France, Sweden) or always below (e.g., Chad, Somalia) over the 24-year panel. This is because country FE absorb all variation for countries with no within-country switching. The result would be a logit estimated on a very specific subsample of "switching" countries, which biases inference and limits substantive interpretation.

Using regional FE (with EURO as the reference) instead retains the full sample and allows the logit to exploit cross-country variation. The trade-off is that we cannot make causal claims about within-country changes in left-behind status. But for a *predictive* tool that helps INGOs and ministries identify which countries are at risk *today*, this is the appropriate design.

### Why marginal effects in percentage points

Logit coefficients are log-odds, which are notoriously hard to interpret. The average marginal effect (AME), computed via `margins::margins()`, expresses each coefficient as the change in probability of being left-behind per unit change in the covariate, in percentage points. This is directly readable: "an additional birth per woman raises the probability of being left-behind by 11.6 percentage points" makes immediate sense, while a log-odds coefficient does not.

---

## 3. Session 3: mixed models and DiD COVID

### Why mixed models, not just fixed effects

Fixed effects identify the *average* effect across all countries, which is useful but limited. The mixed model adds two outputs that fixed effects cannot provide: variance components (how heterogeneous are country trajectories?) and BLUPs (what is each country's individual trajectory?). For monitoring and evaluation purposes, this country-level granularity is far more actionable than a single average effect.

### Partial pooling: the central concept

The mixed model lies between two extremes:

- **No pooling** (separate regression per country): each country has its own intercept and slope, estimated entirely from its own 24 observations. For countries with noisy data, the resulting estimates are unreliable. With 195 countries × 2 parameters, we estimate 390 parameters total, consuming all degrees of freedom.

- **Complete pooling** (single global regression): one intercept and one slope for the entire panel, ignoring the obvious heterogeneity between countries. Two parameters total, but a substantively wrong assumption.

The mixed model takes a middle path. It assumes country-specific intercepts and slopes are drawn from a Gaussian distribution: $u_i \sim N(0, \sigma_u^2)$ and $v_i \sim N(0, \sigma_v^2)$. We estimate four parameters at the population level (the global intercept, the global slope, $\sigma_u^2$, and $\sigma_v^2$), then compute each country's BLUPs as a weighted average between its own data and the global mean.

The weighting is determined by two factors. Countries with more or less noisy data get pulled less or more toward the global mean. Countries in a tight distribution (small $\sigma_u^2$ or $\sigma_v^2$) get pulled more strongly than countries in a dispersed distribution. The mathematical result is that BLUPs are, on average, closer to the true (unknown) country trajectories than the no-pooling estimates. This is the **James-Stein theorem**, one of the foundational results in 20th-century statistics.

### A concrete example of partial pooling

Consider three countries with very different data patterns:

- **France** has 24 years of data tightly clustered around 95%. Its no-pooling slope estimate would be approximately 0 with high precision. The mixed model gives France a slope very close to 0 because the data are precise enough to trust them.

- **Bangladesh** has 24 years showing a clear trajectory from 67% to 94%. Its no-pooling slope would be around +1.1 per year with good precision. The mixed model gives Bangladesh a slope very close to +1.1.

- **South Sudan** has 24 years of erratic data (40, 25, 60, 30, 15, etc.). Its no-pooling slope might be -0.2, but with enormous uncertainty. The mixed model gives South Sudan a slope between -0.2 and the global mean (+0.3), recognizing that its own data are too noisy to trust completely.

### Connection to Ridge regression for an econometrician

For someone trained in econometrics, mixed models can be understood as a regularized form of fixed effects. Pure FE leaves each intercept entirely free. The mixed model imposes a Gaussian prior that pulls intercepts toward a common mean. This is mathematically equivalent to Ridge regression on the country dummies. The trade-off is the standard bias-variance trade-off: regularization adds a small amount of bias in exchange for a substantial reduction in variance, which often improves out-of-sample predictive accuracy.

### Continuous-treatment DiD: the identification challenge

The standard DiD design compares a treatment group (which receives an intervention) to a control group (which does not), before and after the intervention. For the COVID-19 pandemic, this is impossible: there is no country that escaped the virus.

The continuous-treatment DiD addresses this by exploiting **variation in treatment intensity**. While all countries faced the virus, they responded with very different non-pharmaceutical interventions, captured by the OxCGRT Stringency Index. The design then asks: did countries with stricter responses experience larger DTP3 declines than countries with milder responses?

The identification assumption is that, in the absence of the COVID shock, countries with high and low stringency would have followed parallel trajectories. This is the standard parallel trends assumption, adapted to a continuous treatment.

### Why standardize the treatment variable

Stringency_intensity is measured on the OxCGRT 0-100 scale, but the standard deviation across countries is informative for interpretation. We standardize to z-scores so that 1 unit of treatment = 1 SD of intensity. This makes the coefficient directly interpretable: "an additional standard deviation of stringency causes an X percentage point change in DTP3 coverage". This is preferable to expressing effects in arbitrary scale units.

### Event study: validating parallel trends

The single-coefficient DiD estimates the mean effect over the post-period. The event study extends this by estimating a separate coefficient for each year, with 2019 as the omitted reference category. The coefficients pre-2020 should be close to zero if parallel trends hold (no pre-existing divergence between high- and low-stringency countries). The coefficients post-2020 reveal the dynamic effect: when did the disruption peak, and how quickly did countries recover?

In our results, the pre-2020 coefficients hover near zero with overlapping confidence intervals, providing visual support for the parallel trends assumption. The 2020 and 2021 coefficients are negative (consistent with the main DiD), and 2022 returns to near zero, suggesting transitory rather than permanent disruption.

### Placebo test: a robustness check

If parallel trends hold, then artificially placing the "post" treatment in a pre-treatment year (say 2017) should produce no significant effect. The placebo coefficient is -0.55 with $p = 0.229$, which is reassuring. There is no detectable pre-trend that would invalidate the design.

The placebo test does not *prove* causal validity (no test can), but it rules out one common failure mode: if high-stringency and low-stringency countries had been on diverging paths even before COVID, the placebo would have caught it. Combined with the event study, this provides multiple lines of evidence supporting the design.

### Limitations of the continuous-treatment DiD

The treatment is not randomly assigned: countries that imposed stricter responses also faced different epidemic burdens, had different baseline health system capacities, and operated under different political constraints. Country fixed effects absorb time-invariant differences, but if any country-level factor evolved differently after 2020 in high-stringency countries (e.g., post-COVID economic recoveries, political crises), the coefficient would partially capture those effects too.

The proper interpretation is that we recover a *plausible causal estimate* of the disruption channel through non-pharmaceutical interventions. The estimate is conservative (small in magnitude), validated by parallel trends and placebo, but it is not a randomized controlled trial.

---

## 4. Session 4: choropleth maps

### Why four maps, not one

Each of the four maps answers a distinct question:

1. **Map 1 (DTP3 in 2023)**: where does coverage stand today?
2. **Map 2 (Change 2010-2023)**: how have countries moved over the recent past?
3. **Map 3 (Mixed-model BLUPs)**: what are the model-estimated underlying trajectories, after smoothing noisy data?
4. **Map 4 (COVID disruption 2019-2021)**: where did the pandemic hit hardest?

Maps 2 and 3 may seem redundant, but they tell complementary stories. Map 2 shows raw observed change, including all year-to-year noise. Map 3 shows what the mixed model predicts after averaging information across years and countries. The contrast between them is itself informative: countries with single-year shocks appear extreme in Map 2 but moderate in Map 3, while countries with steady progress appear similar in both.

### Color choices

For the static 2023 coverage map, we use a sequential scale (`viridis::plasma`, reversed) because the variable is unidirectional (always between 0 and 100, with higher meaning better). For change maps, we use a diverging scale (red-cream-green) centered on zero because the variable can be positive or negative, and zero is a meaningful pivot. Caps at +/- 30 pp (Map 2) or +/- 20 pp (Map 3) prevent extreme outliers from dominating the color scale.

### Why ISO3 codes for joining

The world shapefile from `rnaturalearth` and our panel data both use ISO3 codes (FRA, IND, NGA, etc.) as the country identifier. ISO3 is a stable international standard, preferred over country names (which vary in spelling and translation) and over numeric codes (which differ across organizations). Joining on ISO3 is robust and minimizes country mismatches.

### Why R, not GIS software

The choropleth maps could have been produced in dedicated GIS software (QGIS, ArcGIS), but doing them in R has three advantages. First, the entire analysis pipeline is in R, so adding maps requires no new tools. Second, the maps are reproducible: re-running the script produces identical output, avoiding the click-and-drag issues of GUI tools. Third, the maps integrate seamlessly into the RMarkdown report, with no manual export-import steps.

---

## 5. Cross-cutting methodological notes

### Why two languages (English + French)

The primary target audience for this portfolio includes both international organizations (where English is the working language) and French-speaking biostatistics positions in Bordeaux and Paris. Producing both versions demonstrates bilingual analytical capability and signals the dual-track job search strategy.

### Why a single set of figures (in English)

The figures are produced once in English and reused in both reports. Maintaining two parallel figure sets would be high-maintenance for low marginal benefit: the figures convey numerical and visual information that is universally readable, while the prose interpretation is what truly needs translation. Most bilingual analytical reports follow this convention.

### Why GitHub Pages, not a static PDF

The deliverable is a website hosted on GitHub Pages, not a PDF. This choice reflects how modern data products are consumed: links shareable in emails, browseable on mobile devices, easy to update as data refresh. A PDF would be a snapshot. The website is a living document that can evolve.

### Why a master script (run_all.R)

A reproducible project should run end-to-end with a single command. The `run_all.R` master script orchestrates the nine analytical scripts in order, with options to skip slow steps (download) or restart from any point. This is the standard pattern in modern data science for ensuring that any analyst (including future me) can reproduce the entire workflow with `Rscript run_all.R`.

### Why public APIs over scraped data

All three data sources are accessed via stable public APIs (WHO GHO, World Bank WDI package, OxCGRT GitHub release). This guarantees that the project remains reproducible as long as those sources continue to exist. Scraped data, in contrast, breaks whenever the source website changes its structure.

### What was deliberately not done

A few methodological choices were considered and rejected:

- **Imputation of missing DTP3 values**: WUENIC already includes imputation (it is the "Estimates" in WHO/UNICEF Estimates). Re-imputing would be redundant.
- **Sub-national analysis**: limited to country-level data, missing important within-country heterogeneity (rural-urban gaps, conflict zones). This is a clear limitation acknowledged in the conclusion.
- **Multi-vaccine analysis**: focused on DTP3 as the benchmark indicator, but the dataset includes MCV1, DTP1, and POL3. Extending to a multivariate model would be a natural next step.
- **Forecasting**: no out-of-sample prediction or scenario analysis. The project is descriptive and inferential, not predictive.

---

*This document is part of the public GitHub repository accompanying the [main report](index.html). For questions or feedback, contact Killian Foubert via GitHub: [@KillianFoubert](https://github.com/KillianFoubert).*
