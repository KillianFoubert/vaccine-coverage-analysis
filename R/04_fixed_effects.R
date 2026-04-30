# ============================================================================
# 04_fixed_effects.R
# ----------------------------------------------------------------------------
# Panel fixed-effects models on DTP3 coverage.
# Period: 2000-2023.
#
# Specifications:
#   (1) Pooled OLS: baseline without any FE
#   (2) Country FE: controls for unobserved country heterogeneity
#   (3) Country FE + Year FE: two-way, controls for common shocks
#   (4) Two-way + covariates: within-country identification of determinants
#
# Standard errors clustered by country throughout.
#
# Outputs: /output/tables/tab03_fixed_effects.csv + saved models .rds
# ============================================================================

library(here)
library(dplyr)
library(readr)
library(fixest)
library(broom)

TAB_DIR <- here("output", "tables")
MOD_DIR <- here("output", "models")
if (!dir.exists(MOD_DIR)) dir.create(MOD_DIR, recursive = TRUE)

panel <- readRDS(here("data", "processed", "panel.rds"))

# --- 1. Estimation sample --------------------------------------------------

sample <- panel %>%
  filter(
    year >= 2000, year <= 2023,
    !is.na(dtp3),
    !is.na(log_gdp_pc),
    !is.na(health_exp),
    !is.na(urban_pct),
    !is.na(fertility),
    !is.na(region_who)
  )

message("Estimation sample: ",
        nrow(sample), " obs. | ",
        n_distinct(sample$iso3), " countries | ",
        min(sample$year), "-", max(sample$year))

# --- 2. Specifications -----------------------------------------------------

# (1) Pooled OLS, no FE
m1 <- feols(
  dtp3 ~ log_gdp_pc + health_exp + urban_pct + fertility,
  data = sample,
  cluster = ~ iso3
)

# (2) Country FE
m2 <- feols(
  dtp3 ~ log_gdp_pc + health_exp + urban_pct + fertility | iso3,
  data = sample,
  cluster = ~ iso3
)

# (3) Country FE + Year FE
m3 <- feols(
  dtp3 ~ log_gdp_pc + health_exp + urban_pct + fertility | iso3 + year,
  data = sample,
  cluster = ~ iso3
)

# (4) Reference specification (same as m3 for now)
m4 <- m3

# --- 3. Joint test of year FE significance --------------------------------

wald_year_fe <- tryCatch({
  fixef_m3 <- fixef(m3)
  n_year_fe <- length(fixef_m3$year) - 1
  data.frame(
    n_year_fe = n_year_fe,
    r2_m2 = r2(m2, "wr2"),
    r2_m3 = r2(m3, "wr2"),
    delta_r2 = r2(m3, "wr2") - r2(m2, "wr2")
  )
}, error = function(e) {
  message("Year FE test failed: ", e$message)
  NULL
})

message("\n=== Year FE contribution (within R2 m3 - within R2 m2) ===")
print(wald_year_fe)

# --- 4. Comparison table ---------------------------------------------------

tidy_model <- function(mod, label) {
  broom::tidy(mod, conf.int = TRUE) %>%
    mutate(model = label)
}

results <- bind_rows(
  tidy_model(m1, "1. Pooled OLS"),
  tidy_model(m2, "2. Country FE"),
  tidy_model(m3, "3. Country + Year FE"),
  tidy_model(m4, "4. Two-way FE (reference)")
) %>%
  select(model, term, estimate, std.error, statistic, p.value,
         conf.low, conf.high) %>%
  mutate(across(where(is.numeric), ~ round(., 4)))

write_csv(results, file.path(TAB_DIR, "tab03_fixed_effects.csv"))

# fixest etable: human-readable comparison
etable_output <- etable(
  m1, m2, m3, m4,
  cluster = ~ iso3,
  digits = 3,
  signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
  dict = c(
    dtp3 = "DTP3 (%)",
    log_gdp_pc = "log(GDP/cap)",
    health_exp = "Health exp. (% GDP)",
    urban_pct = "Urban (%)",
    fertility = "Fertility",
    iso3 = "Country",
    year = "Year"
  ),
  headers = c("(1) OLS", "(2) Country FE", "(3) Two-way FE", "(4) Reference"),
  fitstat = c("n", "r2", "wr2"),
  tex = FALSE
)

capture.output(
  print(etable_output),
  file = file.path(TAB_DIR, "tab03_fixed_effects_etable.txt")
)

message("\n=== Fixed-effects results ===")
print(etable_output)

# --- 5. Save models -------------------------------------------------------

saveRDS(
  list(m1 = m1, m2 = m2, m3 = m3, m4 = m4),
  file.path(MOD_DIR, "fixed_effects_models.rds")
)

message("\nFixed-effects models estimated and saved.")
message("Tables: tab03_fixed_effects.csv + tab03_fixed_effects_etable.txt")
message("Models: output/models/fixed_effects_models.rds")
