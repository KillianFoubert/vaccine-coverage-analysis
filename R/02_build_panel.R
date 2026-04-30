# ============================================================================
# 02_build_panel.R
# ----------------------------------------------------------------------------
# Build country-year panel from raw data sources.
#
# Steps:
#   1. Load most recent raw files
#   2. Harmonize country codes (ISO3)
#   3. Reshape WUENIC to wide (one indicator per column)
#   4. Aggregate daily OxCGRT to yearly averages
#   5. Merge into 1980-2023 country-year panel
#   6. Create derived variables (logs, dummies, COVID period)
#   7. Completeness diagnostics and save
#
# Output: /data/processed/panel.rds + panel.csv
# ============================================================================

rm(list = ls())

library(here)
library(dplyr)
library(tidyr)
library(readr)
library(lubridate)
library(countrycode)

PROC_DIR <- here("data", "processed")
if (!dir.exists(PROC_DIR)) dir.create(PROC_DIR, recursive = TRUE)

# --- Helper: find most recent file -----------------------------------------

latest_file <- function(pattern, dir = here("data", "raw")) {
  files <- list.files(dir, pattern = pattern, full.names = TRUE)
  if (length(files) == 0) stop("No file found for: ", pattern)
  files[which.max(file.mtime(files))]
}

# --- ISO3 -> WHO region mapping --------------------------------------------
# WHO classifies its 194 Member States into 6 regions.
# This mapping is stable and frozen here to avoid external dependency.
# Source: who.int. Last updated: April 2026.

who_region_map <- tribble(
  ~iso3, ~region_who,
  # AFRO (47 countries)
  "DZA","AFRO","AGO","AFRO","BEN","AFRO","BWA","AFRO","BFA","AFRO",
  "BDI","AFRO","CPV","AFRO","CMR","AFRO","CAF","AFRO","TCD","AFRO",
  "COM","AFRO","COG","AFRO","CIV","AFRO","COD","AFRO","GNQ","AFRO",
  "ERI","AFRO","SWZ","AFRO","ETH","AFRO","GAB","AFRO","GMB","AFRO",
  "GHA","AFRO","GIN","AFRO","GNB","AFRO","KEN","AFRO","LSO","AFRO",
  "LBR","AFRO","MDG","AFRO","MWI","AFRO","MLI","AFRO","MRT","AFRO",
  "MUS","AFRO","MOZ","AFRO","NAM","AFRO","NER","AFRO","NGA","AFRO",
  "RWA","AFRO","STP","AFRO","SEN","AFRO","SYC","AFRO","SLE","AFRO",
  "ZAF","AFRO","SSD","AFRO","TGO","AFRO","UGA","AFRO","TZA","AFRO",
  "ZMB","AFRO","ZWE","AFRO",

  # AMRO (35 countries)
  "ATG","AMRO","ARG","AMRO","BHS","AMRO","BRB","AMRO","BLZ","AMRO",
  "BOL","AMRO","BRA","AMRO","CAN","AMRO","CHL","AMRO","COL","AMRO",
  "CRI","AMRO","CUB","AMRO","DMA","AMRO","DOM","AMRO","ECU","AMRO",
  "SLV","AMRO","GRD","AMRO","GTM","AMRO","GUY","AMRO","HTI","AMRO",
  "HND","AMRO","JAM","AMRO","MEX","AMRO","NIC","AMRO","PAN","AMRO",
  "PRY","AMRO","PER","AMRO","KNA","AMRO","LCA","AMRO","VCT","AMRO",
  "SUR","AMRO","TTO","AMRO","USA","AMRO","URY","AMRO","VEN","AMRO",

  # EMRO (21 countries, including PSE)
  "AFG","EMRO","BHR","EMRO","DJI","EMRO","EGY","EMRO","IRN","EMRO",
  "IRQ","EMRO","JOR","EMRO","KWT","EMRO","LBN","EMRO","LBY","EMRO",
  "MAR","EMRO","OMN","EMRO","PAK","EMRO","QAT","EMRO","SAU","EMRO",
  "SOM","EMRO","SDN","EMRO","SYR","EMRO","TUN","EMRO","ARE","EMRO",
  "YEM","EMRO","PSE","EMRO",

  # EURO (53 countries)
  "ALB","EURO","AND","EURO","ARM","EURO","AUT","EURO","AZE","EURO",
  "BLR","EURO","BEL","EURO","BIH","EURO","BGR","EURO","HRV","EURO",
  "CYP","EURO","CZE","EURO","DNK","EURO","EST","EURO","FIN","EURO",
  "FRA","EURO","GEO","EURO","DEU","EURO","GRC","EURO","HUN","EURO",
  "ISL","EURO","IRL","EURO","ISR","EURO","ITA","EURO","KAZ","EURO",
  "KGZ","EURO","LVA","EURO","LTU","EURO","LUX","EURO","MLT","EURO",
  "MCO","EURO","MNE","EURO","NLD","EURO","MKD","EURO","NOR","EURO",
  "POL","EURO","PRT","EURO","MDA","EURO","ROU","EURO","RUS","EURO",
  "SMR","EURO","SRB","EURO","SVK","EURO","SVN","EURO","ESP","EURO",
  "SWE","EURO","CHE","EURO","TJK","EURO","TUR","EURO","TKM","EURO",
  "UKR","EURO","GBR","EURO","UZB","EURO",

  # SEARO (11 countries)
  "BGD","SEARO","BTN","SEARO","PRK","SEARO","IND","SEARO","IDN","SEARO",
  "MDV","SEARO","MMR","SEARO","NPL","SEARO","LKA","SEARO","THA","SEARO",
  "TLS","SEARO",

  # WPRO (27 countries)
  "AUS","WPRO","BRN","WPRO","KHM","WPRO","CHN","WPRO","COK","WPRO",
  "FJI","WPRO","JPN","WPRO","KIR","WPRO","LAO","WPRO","MYS","WPRO",
  "MHL","WPRO","FSM","WPRO","MNG","WPRO","NRU","WPRO","NZL","WPRO",
  "NIU","WPRO","PLW","WPRO","PNG","WPRO","PHL","WPRO","KOR","WPRO",
  "WSM","WPRO","SGP","WPRO","SLB","WPRO","TON","WPRO","TUV","WPRO",
  "VUT","WPRO","VNM","WPRO"
)

# --- 1. WUENIC: reshape wide -----------------------------------------------

wuenic_raw <- read_csv(latest_file("^wuenic_raw_"), show_col_types = FALSE)

wuenic <- wuenic_raw %>%
  filter(!is.na(value), year >= 1980, year <= 2023) %>%
  group_by(iso3, year, indicator) %>%
  summarise(value = mean(value, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = indicator, values_from = value) %>%
  mutate(across(any_of(c("dtp3", "mcv1", "dtp1", "pol3")),
                ~ pmax(0, pmin(100, .))))

message("WUENIC: ", nrow(wuenic), " obs., ",
        n_distinct(wuenic$iso3), " countries")

# --- 2. WDI: cleaning -------------------------------------------------------

wdi_raw <- read_csv(latest_file("^wdi_raw_"), show_col_types = FALSE)

wdi <- wdi_raw %>%
  filter(region != "Aggregates", !is.na(region)) %>%
  transmute(
    iso3 = iso3c,
    country = country,
    region_wb = region,
    income_group = income,
    year = as.integer(year),
    gdp_pc,
    health_exp,
    urban_pct,
    fertility,
    u5_mortality
  ) %>%
  filter(year >= 1980, year <= 2023)

message("WDI: ", nrow(wdi), " obs., ",
        n_distinct(wdi$iso3), " countries")

# --- 3. OxCGRT: yearly aggregation -----------------------------------------

oxcgrt_raw <- read_csv(
  latest_file("^oxcgrt_raw_"),
  show_col_types = FALSE
)

oxcgrt <- oxcgrt_raw %>%
  mutate(
    iso3 = CountryCode,
    date = ymd(Date),
    stringency = as.numeric(StringencyIndex_Average)
  ) %>%
  filter(!is.na(iso3), !is.na(date)) %>%
  mutate(year = year(date)) %>%
  group_by(iso3, year) %>%
  summarise(
    stringency_mean = mean(stringency, na.rm = TRUE),
    stringency_max  = max(stringency,  na.rm = TRUE),
    n_days = sum(!is.na(stringency)),
    .groups = "drop"
  ) %>%
  filter(n_days >= 60) %>%
  select(-n_days)

message("OxCGRT: ", nrow(oxcgrt), " obs., ",
        n_distinct(oxcgrt$iso3), " countries")

# --- 4. Build panel skeleton + joins ---------------------------------------

panel_skeleton <- expand_grid(
  iso3 = unique(wuenic$iso3),
  year = 1980:2023
)

panel <- panel_skeleton %>%
  left_join(who_region_map, by = "iso3") %>%
  left_join(wuenic,         by = c("iso3", "year")) %>%
  left_join(wdi,            by = c("iso3", "year")) %>%
  left_join(oxcgrt,         by = c("iso3", "year")) %>%
  mutate(
    stringency_mean = ifelse(is.na(stringency_mean) & year < 2020, 0,
                             stringency_mean),
    stringency_max  = ifelse(is.na(stringency_max) & year < 2020, 0,
                             stringency_max)
  )

# Warning if countries lack a WHO region
missing_region <- panel %>%
  filter(is.na(region_who)) %>%
  distinct(iso3) %>%
  pull(iso3)
if (length(missing_region) > 0) {
  message("WUENIC countries not mapped to a WHO region (will be NA): ",
          paste(missing_region, collapse = ", "))
}

# --- 5. Derived variables ---------------------------------------------------

panel <- panel %>%
  mutate(
    log_gdp_pc = ifelse(!is.na(gdp_pc) & gdp_pc > 0, log(gdp_pc), NA_real_),
    left_behind_dtp3 = ifelse(!is.na(dtp3), as.integer(dtp3 < 80), NA),
    covid_period = case_when(
      year %in% 2018:2019 ~ "pre_covid",
      year %in% 2020:2021 ~ "covid",
      year %in% 2022:2023 ~ "post_covid",
      TRUE ~ "earlier"
    ),
    post_covid = as.integer(year >= 2020)
  )

# COVID response intensity per country (mean 2020-2021)
stringency_intensity <- panel %>%
  filter(year %in% 2020:2021) %>%
  group_by(iso3) %>%
  summarise(
    stringency_intensity = mean(stringency_mean, na.rm = TRUE),
    .groups = "drop"
  )

panel <- panel %>%
  left_join(stringency_intensity, by = "iso3")

# --- 6. Completeness diagnostics -------------------------------------------

completeness <- panel %>%
  summarise(
    n_obs = n(),
    n_countries = n_distinct(iso3),
    n_years = n_distinct(year),
    dtp3_nonmissing  = round(mean(!is.na(dtp3)), 3),
    mcv1_nonmissing  = round(mean(!is.na(mcv1)), 3),
    gdp_nonmissing   = round(mean(!is.na(gdp_pc)), 3),
    region_nonmissing = round(mean(!is.na(region_who)), 3)
  )

message("\n=== Panel diagnostics ===")
print(completeness)

completeness_by_region <- panel %>%
  filter(year >= 2000) %>%
  group_by(region_who) %>%
  summarise(
    n_obs = n(),
    dtp3_coverage_avg = round(mean(dtp3, na.rm = TRUE), 1),
    dtp3_pct_nonmissing = round(100 * mean(!is.na(dtp3)), 1),
    .groups = "drop"
  )

print(completeness_by_region)

# --- 7. Save ---------------------------------------------------------------

saveRDS(panel, file.path(PROC_DIR, "panel.rds"))
write_csv(panel, file.path(PROC_DIR, "panel.csv"))

message("\nPanel saved: ", PROC_DIR, "/panel.rds")
message("Dimensions: ", nrow(panel), " rows x ", ncol(panel), " columns")
