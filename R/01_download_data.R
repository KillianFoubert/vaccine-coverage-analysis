# ============================================================================
# 01_download_data.R
# ----------------------------------------------------------------------------
# Automated download of the three project data sources:
#   1. WUENIC : WHO/UNICEF Estimates of National Immunization Coverage
#   2. WDI    : World Development Indicators (World Bank)
#   3. OxCGRT : Oxford COVID-19 Government Response Tracker
#
# Output: /data/raw/ (raw timestamped files)
# ============================================================================

rm(list = ls())

library(here)
library(dplyr)
library(readr)
library(WDI)

# Increase timeout for WDI downloads (server can be slow)
options(timeout = 300)

RAW_DIR <- here("data", "raw")
if (!dir.exists(RAW_DIR)) dir.create(RAW_DIR, recursive = TRUE)

dl_date <- format(Sys.Date(), "%Y%m%d")

message("Downloading data, ", Sys.time())

# --- 1. WUENIC --------------------------------------------------------------

gho_indicators <- list(
  dtp3 = "WHS4_100",
  mcv1 = "WHS4_544",
  dtp1 = "WHS4_117",
  pol3 = "WHS4_128"
)

download_gho <- function(indicator_code, label) {
  url <- paste0("https://ghoapi.azureedge.net/api/", indicator_code)
  message("  Downloading ", label, " (", indicator_code, ")...")
  tryCatch({
    raw <- jsonlite::fromJSON(url, flatten = TRUE)
    df <- raw$value %>%
      as_tibble() %>%
      filter(SpatialDimType == "COUNTRY") %>%
      select(
        iso3 = SpatialDim,
        year = TimeDim,
        value = NumericValue,
        dim1 = Dim1
      ) %>%
      filter(is.na(dim1) | dim1 == "" | dim1 == "BTSX") %>%
      select(-dim1) %>%
      mutate(indicator = label)
    return(df)
  }, error = function(e) {
    warning("Download failed for ", label, ": ", e$message)
    return(NULL)
  })
}

wuenic_list <- lapply(names(gho_indicators), function(ind) {
  download_gho(gho_indicators[[ind]], ind)
})
wuenic_raw <- bind_rows(wuenic_list)

write_csv(
  wuenic_raw,
  file.path(RAW_DIR, paste0("wuenic_raw_", dl_date, ".csv"))
)
message("  -> WUENIC saved (", nrow(wuenic_raw), " observations)")

# --- 2. WDI -----------------------------------------------------------------

message("Downloading WDI...")

wdi_indicators <- c(
  gdp_pc       = "NY.GDP.PCAP.KD",
  health_exp   = "SH.XPD.CHEX.GD.ZS",
  urban_pct    = "SP.URB.TOTL.IN.ZS",
  fertility    = "SP.DYN.TFRT.IN",
  u5_mortality = "SH.DYN.MORT"
)

wdi_raw <- WDI(
  country = "all",
  indicator = wdi_indicators,
  start = 1980,
  end = 2023,
  extra = TRUE
)

write_csv(
  wdi_raw,
  file.path(RAW_DIR, paste0("wdi_raw_", dl_date, ".csv"))
)
message("  -> WDI saved (", nrow(wdi_raw), " observations)")

# --- 3. OxCGRT --------------------------------------------------------------

message("Downloading OxCGRT...")

oxcgrt_url <- paste0(
  "https://raw.githubusercontent.com/OxCGRT/covid-policy-dataset/main/",
  "data/OxCGRT_compact_national_v1.csv"
)

oxcgrt_raw <- read_csv(
  oxcgrt_url,
  col_types = cols(.default = "c"),
  progress = FALSE
)

write_csv(
  oxcgrt_raw,
  file.path(RAW_DIR, paste0("oxcgrt_raw_", dl_date, ".csv"))
)
message("  -> OxCGRT saved (", nrow(oxcgrt_raw), " observations)")

message("\nDownload complete, ", Sys.time())
message("Files in: ", RAW_DIR)
print(list.files(RAW_DIR, pattern = "^(wuenic|wdi|oxcgrt)"))
