# ============================================================================
# 07_did_covid.R
# ----------------------------------------------------------------------------
# Continuous-treatment Difference-in-Differences: COVID-19 impact on DTP3
# coverage, modulated by Stringency Index intensity (OxCGRT).
#
# Design:
#   - "Treatment" = stringency_intensity (mean 2020-2021 by country, fixed)
#   - "Post" = year >= 2020 (binary)
#   - Effect of interest: beta on stringency x post interaction
#
# Period: 2015-2023 (5 pre, 4 post for parallel trends validation)
#
# Specifications:
#   (D1) Main DiD: continuous stringency x post interaction
#   (D2) Event study: stringency x year interactions (2015-2023)
#   (D3) Pre-2020 placebo: parallel trends test on 2015-2019
#
# SEs clustered by country (fixest native).
# ============================================================================

library(here)
library(dplyr)
library(tidyr)
library(readr)
library(fixest)
library(ggplot2)

TAB_DIR <- here("output", "tables")
FIG_DIR <- here("output", "figures")
MOD_DIR <- here("output", "models")

panel <- readRDS(here("data", "processed", "panel.rds"))

# --- 1. Build DiD sample ---------------------------------------------------

did_sample <- panel %>%
  filter(
    year >= 2015, year <= 2023,
    !is.na(dtp3),
    !is.na(stringency_intensity),
    !is.na(region_who)
  ) %>%
  mutate(
    post_covid = as.integer(year >= 2020),
    # Standardize stringency_intensity for direct interpretation:
    # 1 unit = 1 SD of COVID response intensity
    stringency_z = as.numeric(scale(stringency_intensity))
  )

message("DiD sample: ",
        nrow(did_sample), " obs. | ",
        n_distinct(did_sample$iso3), " countries | ",
        min(did_sample$year), "-", max(did_sample$year))

message("Stringency_intensity distribution (mean 2020-2021 by country):")
print(summary(did_sample$stringency_intensity))

# --- 2. (D1) Main DiD ------------------------------------------------------

D1 <- feols(
  dtp3 ~ stringency_z:post_covid | iso3 + year,
  data = did_sample,
  cluster = ~ iso3
)

message("\n=== (D1) Main DiD ===")
print(summary(D1))

d1_tidy <- broom::tidy(D1, conf.int = TRUE) %>%
  mutate(across(where(is.numeric), ~ round(., 4)))

write_csv(d1_tidy, file.path(TAB_DIR, "tab08_did_main.csv"))

# --- 3. (D2) Event study --------------------------------------------------

did_sample <- did_sample %>%
  mutate(year_factor = factor(year, levels = c("2019", as.character(setdiff(2015:2023, 2019)))))

D2 <- feols(
  dtp3 ~ stringency_z:year_factor | iso3 + year,
  data = did_sample,
  cluster = ~ iso3
)

message("\n=== (D2) Event study ===")
print(summary(D2))

d2_tidy <- broom::tidy(D2, conf.int = TRUE) %>%
  filter(grepl("year_factor", term)) %>%
  mutate(
    year = as.integer(gsub(".*year_factor", "", term)),
    across(where(is.numeric), ~ round(., 4))
  ) %>%
  arrange(year) %>%
  bind_rows(
    data.frame(
      term = "stringency_z:year_factor2019 (reference)",
      year = 2019,
      estimate = 0,
      std.error = 0,
      statistic = NA,
      p.value = NA,
      conf.low = 0,
      conf.high = 0
    )
  ) %>%
  arrange(year)

write_csv(d2_tidy, file.path(TAB_DIR, "tab09_did_eventstudy.csv"))

# --- 4. (D3) Placebo test --------------------------------------------------

placebo_sample <- did_sample %>%
  filter(year %in% 2015:2019) %>%
  mutate(fake_post = as.integer(year >= 2017))

D3 <- feols(
  dtp3 ~ stringency_z:fake_post | iso3 + year,
  data = placebo_sample,
  cluster = ~ iso3
)

message("\n=== (D3) Placebo test (fake 'post' at 2017, on 2015-2019 only) ===")
print(summary(D3))

d3_tidy <- broom::tidy(D3, conf.int = TRUE) %>%
  mutate(across(where(is.numeric), ~ round(., 4)))

# --- 5. Event study figure -------------------------------------------------

p_eventstudy <- ggplot(d2_tidy, aes(x = year, y = estimate)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey40") +
  geom_vline(xintercept = 2019.5, linetype = "dotted", color = "red", alpha = 0.7) +
  annotate("text", x = 2019.5, y = max(d2_tidy$conf.high, na.rm = TRUE),
           label = "COVID", hjust = -0.15, color = "red", size = 3) +
  geom_errorbar(aes(ymin = conf.low, ymax = conf.high),
                width = 0.15, color = "grey50") +
  geom_point(size = 2.5, color = "#2C3E50") +
  scale_x_continuous(breaks = 2015:2023) +
  labs(
    title = "Event study: COVID Stringency Index effect on DTP3 coverage",
    subtitle = "Coefficient beta_t = effect of 1 SD of stringency in year t. 2019 = reference.",
    x = NULL,
    y = "Coefficient (DTP3 points per SD of stringency)",
    caption = "Source: WUENIC + OxCGRT. SE clustered by country. Bars = 95% CI."
  ) +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold", size = rel(1.1)),
    plot.subtitle = element_text(color = "grey40"),
    plot.caption = element_text(color = "grey50", size = rel(0.8), hjust = 0)
  )

ggsave(file.path(FIG_DIR, "fig07_did_eventstudy.png"),
       p_eventstudy, width = 8.5, height = 5, dpi = 200)

# --- 6. Tertile figure -----------------------------------------------------

intensity_groups <- did_sample %>%
  distinct(iso3, stringency_intensity) %>%
  mutate(tertile = ntile(stringency_intensity, 3),
         tertile_lab = factor(tertile, levels = 1:3,
                              labels = c("T1 (low response)",
                                         "T2 (medium response)",
                                         "T3 (high response)")))

did_with_tertiles <- did_sample %>%
  left_join(intensity_groups %>% select(iso3, tertile_lab), by = "iso3")

trajectory_by_tertile <- did_with_tertiles %>%
  group_by(year, tertile_lab) %>%
  summarise(dtp3_mean = mean(dtp3, na.rm = TRUE), .groups = "drop")

p_tertiles <- ggplot(trajectory_by_tertile,
                     aes(x = year, y = dtp3_mean, color = tertile_lab)) +
  annotate("rect", xmin = 2019.5, xmax = 2021.5,
           ymin = -Inf, ymax = Inf, alpha = 0.10, fill = "red") +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  scale_color_manual(values = c(
    "T1 (low response)" = "#2ECC71",
    "T2 (medium response)" = "#F39C12",
    "T3 (high response)" = "#E74C3C"
  )) +
  scale_x_continuous(breaks = 2015:2023) +
  labs(
    title = "DTP3 coverage by tertile of COVID response intensity",
    subtitle = "Did countries with the strictest responses (T3) drop more sharply?",
    x = NULL, y = "Mean DTP3 coverage (%)",
    color = "Stringency tertile",
    caption = "Source: WUENIC + OxCGRT. Red band = 2020-2021."
  ) +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold", size = rel(1.1)),
    plot.subtitle = element_text(color = "grey40"),
    plot.caption = element_text(color = "grey50", size = rel(0.8), hjust = 0),
    legend.position = "bottom"
  )

ggsave(file.path(FIG_DIR, "fig08_did_intensity_tertiles.png"),
       p_tertiles, width = 9, height = 5.5, dpi = 200)

# --- 7. Save models -------------------------------------------------------

saveRDS(
  list(D1 = D1, D2 = D2, D3 = D3),
  file.path(MOD_DIR, "did_models.rds")
)

message("\nDiD COVID estimated and saved.")
message("Tables: tab08_did_main.csv, tab09_did_eventstudy.csv")
message("Figures: fig07_did_eventstudy.png, fig08_did_intensity_tertiles.png")

message("\n=== SUMMARY ===")
cat("(D1) Main DiD effect: ",
    round(d1_tidy$estimate[1], 2), " pp DTP3 per SD of stringency",
    " [p=", d1_tidy$p.value[1], "]\n", sep = "")
cat("(D3) Placebo test 2017: ",
    round(d3_tidy$estimate[1], 2), " pp",
    " [p=", d3_tidy$p.value[1], "]",
    if (d3_tidy$p.value[1] > 0.10) " parallel trends OK"
    else " parallel trends questionable", "\n", sep = "")
