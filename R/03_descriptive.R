# ============================================================================
# 03_descriptive.R
# ----------------------------------------------------------------------------
# Descriptive analysis of the panel:
#   - Global and regional trends 1980-2023
#   - COVID dip and recovery
#   - Identification of "left-behind" countries
#   - Descriptive statistics tables
#
# Outputs in /output/figures/ + /output/tables/
# ============================================================================

library(here)
library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)
library(scales)
library(kableExtra)

panel <- readRDS(here("data", "processed", "panel.rds"))

FIG_DIR <- here("output", "figures")
TAB_DIR <- here("output", "tables")

# --- ggplot theme ----------------------------------------------------------

theme_project <- function(base_size = 11) {
  theme_minimal(base_size = base_size) +
    theme(
      panel.grid.minor = element_blank(),
      plot.title = element_text(face = "bold", size = rel(1.1)),
      plot.subtitle = element_text(color = "grey40"),
      plot.caption = element_text(color = "grey50", size = rel(0.8),
                                  hjust = 0),
      legend.position = "bottom",
      strip.text = element_text(face = "bold")
    )
}

# WHO region palette
who_colors <- c(
  "AFRO"  = "#E74C3C",
  "AMRO"  = "#3498DB",
  "EMRO"  = "#F39C12",
  "EURO"  = "#2ECC71",
  "SEARO" = "#9B59B6",
  "WPRO"  = "#1ABC9C"
)

# --- Figure 1: Global DTP3 trend -------------------------------------------

global_trend <- panel %>%
  filter(!is.na(dtp3)) %>%
  group_by(year) %>%
  summarise(
    dtp3_mean = mean(dtp3, na.rm = TRUE),
    dtp3_median = median(dtp3, na.rm = TRUE),
    n_countries = n(),
    .groups = "drop"
  )

p1 <- ggplot(global_trend, aes(x = year)) +
  geom_line(aes(y = dtp3_mean, color = "Mean"), linewidth = 1) +
  geom_line(aes(y = dtp3_median, color = "Median"),
            linewidth = 1, linetype = "dashed") +
  annotate("rect", xmin = 2019.5, xmax = 2021.5,
           ymin = -Inf, ymax = Inf,
           alpha = 0.12, fill = "red") +
  annotate("text", x = 2020.5, y = 55,
           label = "COVID-19", size = 3, color = "grey30") +
  scale_color_manual(values = c("Mean" = "#2C3E50",
                                "Median" = "#E74C3C")) +
  scale_y_continuous(limits = c(40, 100),
                     breaks = seq(40, 100, 10)) +
  labs(
    title = "Global DTP3 coverage, 1980-2023",
    subtitle = "Mean and median of national rates (N ~ 195 countries)",
    x = NULL, y = "DTP3 coverage (%)",
    color = NULL,
    caption = "Source: WHO/UNICEF Estimates of National Immunization Coverage (WUENIC)"
  ) +
  theme_project()

ggsave(file.path(FIG_DIR, "fig01_global_trend.png"),
       p1, width = 8, height = 5, dpi = 200)

# --- Figure 2: Regional trends ---------------------------------------------

regional_trend <- panel %>%
  filter(!is.na(dtp3), !is.na(region_who)) %>%
  group_by(year, region_who) %>%
  summarise(
    dtp3_mean = mean(dtp3, na.rm = TRUE),
    n = n(),
    .groups = "drop"
  )

p2 <- ggplot(regional_trend,
             aes(x = year, y = dtp3_mean, color = region_who)) +
  geom_line(linewidth = 1) +
  annotate("rect", xmin = 2019.5, xmax = 2021.5,
           ymin = -Inf, ymax = Inf,
           alpha = 0.10, fill = "red") +
  scale_color_manual(values = who_colors) +
  scale_y_continuous(limits = c(30, 100)) +
  labs(
    title = "DTP3 coverage by WHO region, 1980-2023",
    subtitle = "Mean of national rates by region",
    x = NULL, y = "DTP3 coverage (%)",
    color = "WHO Region",
    caption = "Source: WUENIC | Regions: AFRO (Africa), AMRO (Americas), EMRO (Eastern Mediterranean), EURO (Europe), SEARO (South-East Asia), WPRO (Western Pacific)"
  ) +
  theme_project()

ggsave(file.path(FIG_DIR, "fig02_regional_trend.png"),
       p2, width = 9, height = 5.5, dpi = 200)

# --- Figure 3: COVID impact ------------------------------------------------

covid_impact <- panel %>%
  filter(year %in% 2018:2023, !is.na(dtp3), !is.na(region_who)) %>%
  group_by(year, region_who) %>%
  summarise(dtp3_mean = mean(dtp3, na.rm = TRUE), .groups = "drop")

p3 <- ggplot(covid_impact,
             aes(x = year, y = dtp3_mean,
                 color = region_who, group = region_who)) +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  scale_color_manual(values = who_colors) +
  scale_x_continuous(breaks = 2018:2023) +
  labs(
    title = "COVID-19 shock and recovery: DTP3 by region, 2018-2023",
    subtitle = "The 2020-2021 dip varies markedly across regions",
    x = NULL, y = "DTP3 coverage (%)",
    color = "WHO Region",
    caption = "Source: WUENIC"
  ) +
  theme_project()

ggsave(file.path(FIG_DIR, "fig03_covid_impact.png"),
       p3, width = 9, height = 5.5, dpi = 200)

# --- Figure 4: Left-behind countries' trajectories -------------------------

left_behind_2023 <- panel %>%
  filter(year == 2023, !is.na(dtp3), dtp3 < 70) %>%
  pull(iso3)

p4 <- panel %>%
  filter(iso3 %in% left_behind_2023,
         year >= 2000, !is.na(dtp3)) %>%
  ggplot(aes(x = year, y = dtp3, group = iso3)) +
  geom_line(alpha = 0.5, color = "#E74C3C") +
  geom_hline(yintercept = 80, linetype = "dashed", color = "grey40") +
  annotate("text", x = 2001, y = 82,
           label = "WHO threshold 80%", size = 3, color = "grey30",
           hjust = 0) +
  scale_y_continuous(limits = c(0, 100)) +
  labs(
    title = paste0("Trajectories of ", length(left_behind_2023),
                   " countries with DTP3 < 70% in 2023"),
    subtitle = "Marked heterogeneity: some declining, others recovering",
    x = NULL, y = "DTP3 coverage (%)",
    caption = "Source: WUENIC"
  ) +
  theme_project()

ggsave(file.path(FIG_DIR, "fig04_left_behind_trajectories.png"),
       p4, width = 8, height = 5, dpi = 200)

# --- Table 1: Descriptive statistics ---------------------------------------

desc_stats <- panel %>%
  filter(year >= 2000) %>%
  summarise(
    `N observations`         = format(n(), big.mark = ","),
    `N countries`            = as.character(n_distinct(iso3)),
    `Years`                  = paste0(min(year), "-", max(year)),
    `DTP3 mean (%)`          = sprintf("%.1f", mean(dtp3, na.rm = TRUE)),
    `DTP3 median (%)`        = sprintf("%.1f", median(dtp3, na.rm = TRUE)),
    `DTP3 P10 (%)`           = sprintf("%.1f", quantile(dtp3, 0.10, na.rm = TRUE)),
    `DTP3 P90 (%)`           = sprintf("%.1f", quantile(dtp3, 0.90, na.rm = TRUE)),
    `Median GDP/cap (USD)`   = format(round(median(gdp_pc, na.rm = TRUE)), big.mark = ","),
    `Mean urban share (%)`   = sprintf("%.1f", mean(urban_pct, na.rm = TRUE))
  ) %>%
  pivot_longer(everything(), names_to = "Statistic", values_to = "Value")

write_csv(desc_stats, file.path(TAB_DIR, "tab01_descriptive_stats.csv"))

# --- Table 2: Top 20 COVID drops -------------------------------------------

covid_drop <- panel %>%
  filter(year %in% c(2019, 2021), !is.na(dtp3)) %>%
  select(iso3, year, dtp3, region_who) %>%
  pivot_wider(names_from = year, values_from = dtp3,
              names_prefix = "dtp3_") %>%
  mutate(drop = dtp3_2019 - dtp3_2021) %>%
  filter(!is.na(drop), dtp3_2019 >= 50) %>%
  arrange(desc(drop)) %>%
  head(20)

write_csv(covid_drop, file.path(TAB_DIR, "tab02_covid_drops_top20.csv"))

message("Descriptive figures and tables generated.")
message("  - ", length(list.files(FIG_DIR)), " figures in ", FIG_DIR)
message("  - ", length(list.files(TAB_DIR)), " tables in ", TAB_DIR)
