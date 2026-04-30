# ============================================================================
# 06_mixed_models.R
# ----------------------------------------------------------------------------
# Mixed models (lme4) on DTP3 coverage, 2000-2023.
#
# Goals (complementary to fixed effects):
#   1. Explicitly model the variation in national trajectories
#      (random intercepts AND random slopes by country)
#   2. Extract BLUPs (Best Linear Unbiased Predictors) to rank
#      countries by their coverage trajectory
#   3. Visualize via spaghetti plot of predicted trajectories
#
# Specifications:
#   (M1) Random intercepts only
#   (M2) Random intercepts + random slopes on time (recommended)
#   (M3) M2 + fixed-effect covariates
#
# Comparison: likelihood ratio test M1 vs M2, AIC/BIC.
# ============================================================================

library(here)
library(dplyr)
library(tidyr)
library(readr)
library(lme4)
library(broom.mixed)
library(ggplot2)

TAB_DIR <- here("output", "tables")
FIG_DIR <- here("output", "figures")
MOD_DIR <- here("output", "models")

panel <- readRDS(here("data", "processed", "panel.rds"))

# --- 1. Sample ------------------------------------------------------------

sample <- panel %>%
  filter(
    year >= 2000, year <= 2023,
    !is.na(dtp3),
    !is.na(log_gdp_pc),
    !is.na(health_exp),
    !is.na(urban_pct),
    !is.na(fertility),
    !is.na(region_who)
  ) %>%
  mutate(
    # Center time around 2000 for easier intercept and slope interpretation
    year_c = year - 2000
  )

message("Mixed-model sample: ",
        nrow(sample), " obs. | ",
        n_distinct(sample$iso3), " countries | ",
        min(sample$year), "-", max(sample$year))

# --- 2. Estimation --------------------------------------------------------

# (M1) Random intercepts only
M1 <- lmer(
  dtp3 ~ year_c + (1 | iso3),
  data = sample, REML = TRUE
)

# (M2) Random intercepts + random slopes on time
M2 <- lmer(
  dtp3 ~ year_c + (1 + year_c | iso3),
  data = sample, REML = TRUE
)

# (M3) M2 + fixed covariates
M3 <- lmer(
  dtp3 ~ year_c + log_gdp_pc + health_exp + urban_pct + fertility +
    (1 + year_c | iso3),
  data = sample, REML = TRUE
)

# --- 3. Model comparison (LRT M1 vs M2) -----------------------------------

lrt_m1_m2 <- anova(M1, M2)
message("\n=== LRT: M1 (intercept only) vs M2 (intercept + slope) ===")
print(lrt_m1_m2)

fit_metrics <- data.frame(
  model = c("M1 (intercept random)", "M2 (intercept + slope random)", "M3 (M2 + covariates)"),
  AIC = c(AIC(M1), AIC(M2), AIC(M3)),
  BIC = c(BIC(M1), BIC(M2), BIC(M3)),
  logLik = c(as.numeric(logLik(M1)),
             as.numeric(logLik(M2)),
             as.numeric(logLik(M3)))
)
fit_metrics$AIC <- round(fit_metrics$AIC, 1)
fit_metrics$BIC <- round(fit_metrics$BIC, 1)
fit_metrics$logLik <- round(fit_metrics$logLik, 1)
write_csv(fit_metrics, file.path(TAB_DIR, "tab06_mixed_models_fit.csv"))
message("\n=== Fit metrics ===")
print(fit_metrics)

# --- 4. Fixed coefficients (M3 = main spec) -------------------------------

fixed_coefs <- broom.mixed::tidy(M3, effects = "fixed", conf.int = TRUE) %>%
  mutate(across(where(is.numeric), ~ round(., 4))) %>%
  select(term, estimate, std.error, statistic, conf.low, conf.high)

write_csv(fixed_coefs, file.path(TAB_DIR, "tab06_mixed_models.csv"))
message("\n=== Fixed effects (M3) ===")
print(fixed_coefs)

varcomps <- broom.mixed::tidy(M3, effects = "ran_pars") %>%
  mutate(estimate = round(estimate, 4))
message("\n=== Variance components (M3) ===")
print(varcomps)

# --- 5. BLUPs: country-specific slopes ------------------------------------

fixed_year <- fixef(M3)["year_c"]

ranef_M3 <- ranef(M3)$iso3 %>%
  tibble::rownames_to_column("iso3") %>%
  rename(intercept_dev = `(Intercept)`,
         slope_dev = year_c) %>%
  mutate(
    total_slope = fixed_year + slope_dev,
    total_slope_per_decade = 10 * total_slope
  )

country_info <- sample %>%
  group_by(iso3) %>%
  summarise(
    region_who = first(region_who),
    dtp3_2000 = mean(dtp3[year %in% 2000:2002], na.rm = TRUE),
    dtp3_2023 = mean(dtp3[year %in% 2021:2023], na.rm = TRUE),
    .groups = "drop"
  )

country_slopes <- ranef_M3 %>%
  left_join(country_info, by = "iso3") %>%
  arrange(desc(total_slope_per_decade)) %>%
  mutate(across(where(is.numeric), ~ round(., 3)))

write_csv(country_slopes, file.path(TAB_DIR, "tab07_country_slopes.csv"))

message("\n=== Top 10 progressions (DTP3 gain per decade) ===")
print(head(country_slopes %>% select(iso3, region_who, dtp3_2000, dtp3_2023,
                                      total_slope_per_decade), 10))
message("\n=== Bottom 10 trajectories ===")
print(tail(country_slopes %>% select(iso3, region_who, dtp3_2000, dtp3_2023,
                                      total_slope_per_decade), 10))

# --- 6. Spaghetti plot ---------------------------------------------------

pred_data <- sample %>%
  mutate(predicted = predict(M3, re.form = NULL))

highlights <- c("FRA", "IND", "NGA", "BRA", "PAK")

p_spaghetti <- ggplot() +
  geom_line(
    data = pred_data %>% filter(!iso3 %in% highlights),
    aes(x = year, y = predicted, group = iso3),
    color = "grey70", alpha = 0.3, linewidth = 0.3
  ) +
  geom_line(
    data = pred_data %>% filter(iso3 %in% highlights),
    aes(x = year, y = predicted, color = iso3, group = iso3),
    linewidth = 1.2
  ) +
  scale_color_manual(values = c(
    "FRA" = "#2C3E50",
    "IND" = "#9B59B6",
    "NGA" = "#E74C3C",
    "BRA" = "#3498DB",
    "PAK" = "#F39C12"
  )) +
  scale_y_continuous(limits = c(0, 100), breaks = seq(0, 100, 20)) +
  labs(
    title = "Predicted national trajectories (mixed model M3), 2000-2023",
    subtitle = "Each line = one country. Colors = highlighted examples.",
    x = NULL, y = "Predicted DTP3 coverage (%)",
    color = "Highlighted countries",
    caption = "Source: WUENIC + WDI | Mixed model with random intercepts and slopes (lme4)"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold", size = rel(1.1)),
    plot.subtitle = element_text(color = "grey40"),
    plot.caption = element_text(color = "grey50", size = rel(0.8), hjust = 0),
    legend.position = "bottom"
  )

ggsave(file.path(FIG_DIR, "fig05_spaghetti_trajectories.png"),
       p_spaghetti, width = 9, height = 5.5, dpi = 200)

# --- 7. Distribution of country slopes ------------------------------------

p_slopes <- ggplot(country_slopes,
                   aes(x = total_slope_per_decade, fill = region_who)) +
  geom_histogram(bins = 30, color = "white", linewidth = 0.3) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey40") +
  scale_fill_manual(values = c(
    "AFRO"  = "#E74C3C", "AMRO"  = "#3498DB", "EMRO"  = "#F39C12",
    "EURO"  = "#2ECC71", "SEARO" = "#9B59B6", "WPRO"  = "#1ABC9C"
  )) +
  labs(
    title = "Distribution of national DTP3 trajectories (per decade)",
    subtitle = "BLUPs from mixed model M3. Positive slope = improvement.",
    x = "DTP3 change per decade (percentage points)",
    y = "Number of countries",
    fill = "WHO Region",
    caption = "Source: mixed model (lme4) on WUENIC panel 2000-2023"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold", size = rel(1.1)),
    plot.subtitle = element_text(color = "grey40"),
    plot.caption = element_text(color = "grey50", size = rel(0.8), hjust = 0),
    legend.position = "bottom"
  )

ggsave(file.path(FIG_DIR, "fig06_slope_distribution.png"),
       p_slopes, width = 8, height = 5, dpi = 200)

# --- 8. Save models ------------------------------------------------------

saveRDS(
  list(M1 = M1, M2 = M2, M3 = M3),
  file.path(MOD_DIR, "mixed_models.rds")
)

message("\nMixed models estimated and saved.")
message("Tables: tab06_mixed_models*.csv, tab07_country_slopes.csv")
message("Figures: fig05_spaghetti_trajectories.png, fig06_slope_distribution.png")
