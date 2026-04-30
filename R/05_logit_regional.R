# ============================================================================
# 05_logit_regional.R
# ----------------------------------------------------------------------------
# Logit on the probability of being "left-behind": DTP3 < 80% (WHO threshold).
# Period: 2000-2023.
#
# Why no country fixed effects?
#   In a 24-year panel, many countries are structurally always above the
#   threshold (e.g., France, Sweden) or always below (e.g., Chad, Somalia).
#   A country-FE logit would drop all of them. We therefore use regional
#   effects + year FE to capture common shocks. This also allows interpreting
#   the effect of time-invariant country features (WHO region).
#
# Specifications:
#   (L1) Plain logit: covariates only
#   (L2) + regional effects
#   (L3) + year FE (reference specification)
#   (L4) + COVID interaction
#
# Standard errors clustered by country (sandwich::vcovCL).
# Marginal effects via margins::margins() for interpretation in pp.
# ============================================================================

library(here)
library(dplyr)
library(readr)
library(sandwich)
library(lmtest)
library(margins)
library(broom)

TAB_DIR <- here("output", "tables")
MOD_DIR <- here("output", "models")

panel <- readRDS(here("data", "processed", "panel.rds"))

# --- 1. Sample ------------------------------------------------------------

sample <- panel %>%
  filter(
    year >= 2000, year <= 2023,
    !is.na(left_behind_dtp3),
    !is.na(log_gdp_pc),
    !is.na(health_exp),
    !is.na(urban_pct),
    !is.na(fertility),
    !is.na(region_who)
  ) %>%
  mutate(
    region_who = factor(region_who),
    region_who = relevel(region_who, ref = "EURO"),
    year_factor = factor(year)
  )

message("Logit sample: ",
        nrow(sample), " obs. | ",
        n_distinct(sample$iso3), " countries | ",
        "Left-behind prevalence: ",
        round(100 * mean(sample$left_behind_dtp3), 1), "%")

# --- 2. Estimation --------------------------------------------------------

L1 <- glm(
  left_behind_dtp3 ~ log_gdp_pc + health_exp + urban_pct + fertility,
  data = sample, family = binomial(link = "logit")
)

L2 <- glm(
  left_behind_dtp3 ~ log_gdp_pc + health_exp + urban_pct + fertility +
    region_who,
  data = sample, family = binomial(link = "logit")
)

L3 <- glm(
  left_behind_dtp3 ~ log_gdp_pc + health_exp + urban_pct + fertility +
    region_who + year_factor,
  data = sample, family = binomial(link = "logit")
)

L4 <- glm(
  left_behind_dtp3 ~ log_gdp_pc * post_covid + health_exp + urban_pct +
    fertility + region_who + year_factor,
  data = sample, family = binomial(link = "logit")
)

# --- 3. Cluster-robust SEs -------------------------------------------------

robust_se <- function(mod) {
  vcov_cl <- vcovCL(mod, cluster = sample[["iso3"]], type = "HC1")
  coeftest(mod, vcov. = vcov_cl)
}

L1_rob <- robust_se(L1)
L2_rob <- robust_se(L2)
L3_rob <- robust_se(L3)
L4_rob <- robust_se(L4)

# --- 4. Coefficients table -------------------------------------------------

tidy_logit <- function(ctest, label) {
  as.data.frame(ctest[]) %>%
    tibble::rownames_to_column("term") %>%
    rename(
      estimate = Estimate,
      std.error = `Std. Error`,
      statistic = `z value`,
      p.value = `Pr(>|z|)`
    ) %>%
    mutate(
      model = label,
      odds_ratio = exp(estimate)
    ) %>%
    select(model, term, estimate, odds_ratio, std.error, statistic, p.value)
}

results_logit <- bind_rows(
  tidy_logit(L1_rob, "L1. Covariates"),
  tidy_logit(L2_rob, "L2. + regions"),
  tidy_logit(L3_rob, "L3. + Year FE"),
  tidy_logit(L4_rob, "L4. + COVID interaction")
) %>%
  filter(!grepl("^year_factor", term)) %>%
  mutate(across(where(is.numeric), ~ round(., 4)))

write_csv(results_logit, file.path(TAB_DIR, "tab04_logit_coefficients.csv"))

# --- 5. Marginal effects (L3 = reference spec) -----------------------------

message("\nComputing marginal effects (L3)...")

margins_L3 <- margins(
  L3,
  variables = c("log_gdp_pc", "health_exp", "urban_pct", "fertility"),
  vcov = vcovCL(L3, cluster = sample[["iso3"]], type = "HC1")
)

margins_summary <- summary(margins_L3) %>%
  as.data.frame() %>%
  mutate(
    factor = as.character(factor),
    AME_pp = round(100 * AME, 2),
    SE_pp = round(100 * SE, 2),
    p = round(p, 4)
  ) %>%
  select(factor, AME_pp, SE_pp, z, p, lower, upper)

write_csv(margins_summary, file.path(TAB_DIR, "tab05_logit_marginal_effects.csv"))

message("\n=== Average marginal effects (L3), in percentage points ===")
print(margins_summary)

# --- 6. Save models -------------------------------------------------------

saveRDS(
  list(L1 = L1, L2 = L2, L3 = L3, L4 = L4,
       sample_iso3 = sample$iso3),
  file.path(MOD_DIR, "logit_models.rds")
)

message("\nLogit models estimated and saved.")
message("Tables: tab04_logit_coefficients.csv, tab05_logit_marginal_effects.csv")
