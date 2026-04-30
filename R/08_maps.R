# ============================================================================
# 08_maps.R
# ----------------------------------------------------------------------------
# Choropleth maps of DTP3 coverage and trajectories.
#
# Four maps produced:
#   1. DTP3 coverage in 2023 (current state)
#   2. Change 2010-2023 (recent dynamics)
#   3. Mixed-model country slopes per decade (BLUPs from M3)
#   4. COVID disruption: change 2019-2021 (acute pandemic effect)
#
# Stack: sf + rnaturalearth + ggplot2.
# ============================================================================

library(here)
library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)
library(sf)
library(rnaturalearth)
library(rnaturalearthdata)
library(viridis)

FIG_DIR <- here("output", "figures")
TAB_DIR <- here("output", "tables")

panel <- readRDS(here("data", "processed", "panel.rds"))

# --- Load world shapefile --------------------------------------------------

world <- ne_countries(scale = "medium", returnclass = "sf") %>%
  filter(iso_a3_eh != "ATA")  # exclude Antarctica for cleaner display

# --- Common map theme ------------------------------------------------------

theme_map <- function() {
  theme_void(base_size = 11) +
    theme(
      plot.title = element_text(face = "bold", size = rel(1.15),
                                hjust = 0, margin = margin(b = 4)),
      plot.subtitle = element_text(color = "grey40", size = rel(0.95),
                                   hjust = 0, margin = margin(b = 8)),
      plot.caption = element_text(color = "grey50", size = rel(0.8),
                                  hjust = 0, margin = margin(t = 8)),
      legend.position = "bottom",
      legend.key.width = unit(2, "cm"),
      legend.key.height = unit(0.4, "cm"),
      legend.title = element_text(size = rel(0.9))
    )
}

# Helper: join data to world shapefile via ISO3 code
# NOTE: We use iso_a3_eh (Elan Hierarchy) rather than iso_a3 because the
# default iso_a3 column in rnaturalearth has missing values for several
# countries with overseas territories (France, Norway), which would
# incorrectly display them as "no data". iso_a3_eh provides standard ISO3
# codes for all countries.
join_to_world <- function(df, value_col, iso_col = "iso3") {
  world %>%
    left_join(df, by = c("iso_a3_eh" = iso_col))
}

# --- Map 1: DTP3 coverage in 2023 -----------------------------------------

dtp3_2023 <- panel %>%
  filter(year == 2023, !is.na(dtp3)) %>%
  select(iso3, dtp3)

map1_data <- join_to_world(dtp3_2023, "dtp3")

map1 <- ggplot(map1_data) +
  geom_sf(aes(fill = dtp3), color = "white", linewidth = 0.1) +
  scale_fill_viridis(
    option = "plasma",
    direction = -1,
    na.value = "grey90",
    breaks = c(20, 40, 60, 80, 100),
    limits = c(0, 100),
    name = "DTP3 (%)"
  ) +
  labs(
    title = "DTP3 coverage worldwide, 2023",
    subtitle = "Third dose of diphtheria-tetanus-pertussis vaccine, % of one-year-olds",
    caption = "Source: WHO/UNICEF (WUENIC). Grey = no data."
  ) +
  theme_map()

ggsave(file.path(FIG_DIR, "fig09_map_dtp3_2023.png"),
       map1, width = 11, height = 6, dpi = 200)

# --- Map 2: Change 2010-2023 ----------------------------------------------

change_2010_2023 <- panel %>%
  filter(year %in% c(2010, 2023), !is.na(dtp3)) %>%
  select(iso3, year, dtp3) %>%
  pivot_wider(names_from = year, values_from = dtp3, names_prefix = "y") %>%
  mutate(change = y2023 - y2010) %>%
  filter(!is.na(change))

map2_data <- join_to_world(change_2010_2023, "change")

map2 <- ggplot(map2_data) +
  geom_sf(aes(fill = change), color = "white", linewidth = 0.1) +
  scale_fill_gradient2(
    low = "#B22222",
    mid = "#F5F5DC",
    high = "#2E8B57",
    midpoint = 0,
    na.value = "grey90",
    limits = c(-30, 30),
    breaks = c(-30, -15, 0, 15, 30),
    oob = scales::squish,
    name = "Change (pp)"
  ) +
  labs(
    title = "Change in DTP3 coverage, 2010-2023",
    subtitle = "Green = improvement, red = decline. Values capped at +/- 30 pp.",
    caption = "Source: WUENIC. Grey = no data."
  ) +
  theme_map()

ggsave(file.path(FIG_DIR, "fig10_map_change_2010_2023.png"),
       map2, width = 11, height = 6, dpi = 200)

# --- Map 3: Mixed-model trajectories (BLUPs per decade) -------------------

slopes_table <- read_csv(here("output", "tables", "tab07_country_slopes.csv"),
                         show_col_types = FALSE)

slopes_data <- slopes_table %>%
  select(iso3, total_slope_per_decade)

map3_data <- join_to_world(slopes_data, "total_slope_per_decade")

map3 <- ggplot(map3_data) +
  geom_sf(aes(fill = total_slope_per_decade), color = "white", linewidth = 0.1) +
  scale_fill_gradient2(
    low = "#B22222",
    mid = "#F5F5DC",
    high = "#2E8B57",
    midpoint = 0,
    na.value = "grey90",
    limits = c(-20, 20),
    breaks = c(-20, -10, 0, 10, 20),
    oob = scales::squish,
    name = "Trend (pp/decade)"
  ) +
  labs(
    title = "National DTP3 trajectories, 2000-2023",
    subtitle = "Mixed-model BLUPs: country-specific slopes per decade",
    caption = "Source: lme4 mixed model M3. Values capped at +/- 20 pp. Grey = no data."
  ) +
  theme_map()

ggsave(file.path(FIG_DIR, "fig11_map_blups_slopes.png"),
       map3, width = 11, height = 6, dpi = 200)

# --- Map 4: COVID disruption (change 2019-2021) ---------------------------

covid_change <- panel %>%
  filter(year %in% c(2019, 2021), !is.na(dtp3)) %>%
  select(iso3, year, dtp3) %>%
  pivot_wider(names_from = year, values_from = dtp3, names_prefix = "y") %>%
  mutate(covid_drop = y2021 - y2019) %>%
  filter(!is.na(covid_drop))

map4_data <- join_to_world(covid_change, "covid_drop")

map4 <- ggplot(map4_data) +
  geom_sf(aes(fill = covid_drop), color = "white", linewidth = 0.1) +
  scale_fill_gradient2(
    low = "#B22222",
    mid = "#F5F5DC",
    high = "#2E8B57",
    midpoint = 0,
    na.value = "grey90",
    limits = c(-25, 10),
    breaks = c(-25, -15, -5, 0, 10),
    oob = scales::squish,
    name = "Change (pp)"
  ) +
  labs(
    title = "COVID-19 disruption: DTP3 change 2019-2021",
    subtitle = "Red = decline during pandemic, green = improvement",
    caption = "Source: WUENIC. Grey = no data."
  ) +
  theme_map()

ggsave(file.path(FIG_DIR, "fig12_map_covid_disruption.png"),
       map4, width = 11, height = 6, dpi = 200)

# --- Save underlying map data for inspection ------------------------------

map_data_export <- list(
  dtp3_2023 = dtp3_2023,
  change_2010_2023 = change_2010_2023,
  blups_slopes = slopes_data,
  covid_drop = covid_change
)

write_csv(dtp3_2023, file.path(TAB_DIR, "tab10_map_dtp3_2023.csv"))
write_csv(change_2010_2023, file.path(TAB_DIR, "tab11_map_change_2010_2023.csv"))
write_csv(covid_change, file.path(TAB_DIR, "tab12_map_covid_drop.csv"))

message("\nMaps generated:")
message("  fig09_map_dtp3_2023.png         (current coverage)")
message("  fig10_map_change_2010_2023.png  (recent dynamics)")
message("  fig11_map_blups_slopes.png      (mixed-model trajectories)")
message("  fig12_map_covid_disruption.png  (COVID acute effect)")
