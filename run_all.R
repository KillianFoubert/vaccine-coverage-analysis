# ============================================================================
# run_all.R  --  Master script
# ----------------------------------------------------------------------------
# Pipeline:
#   01 - Data download
#   02 - Panel construction
#   03 - Descriptive analysis
#   04 - Panel fixed effects
#   05 - Logit regional (left-behind)
#   06 - Mixed models (lme4)
#   07 - DiD COVID (event study + parallel trends)
#   08 - Choropleth maps
#   09 - Render FR/EN reports (last step)
#
# Usage: source("run_all.R")
#
# Options:
#   SKIP_DOWNLOAD <- TRUE   # skip data download
#   START_FROM   <- "06"   # restart from a specific step
#   SKIP_REPORTS <- TRUE   # skip report compilation
# ============================================================================

SKIP_DOWNLOAD <- TRUE
SKIP_REPORTS  <- FALSE
START_FROM    <- NULL

.master_env <- new.env()

.master_env$run_step <- function(script_path, label) {
  step_start <- Sys.time()
  cat("\n", strrep("=", 70), "\n", sep = "")
  cat(">> ", label, "\n", sep = "")
  cat("   File:  ", script_path, "\n", sep = "")
  cat("   Start: ", format(step_start, "%H:%M:%S"), "\n", sep = "")
  cat(strrep("-", 70), "\n", sep = "")

  tryCatch({
    sys.source(script_path, envir = new.env(parent = globalenv()))
  }, error = function(e) {
    cat("\n[ERROR] at step: ", label, "\n", sep = "")
    cat("   Message: ", conditionMessage(e), "\n", sep = "")
    stop(e)
  })

  step_end <- Sys.time()
  duration <- round(as.numeric(difftime(step_end, step_start, units = "secs")), 1)
  cat(strrep("-", 70), "\n", sep = "")
  cat("[OK] ", label, " completed in ", duration, "s\n", sep = "")
}

.master_env$run_all_start <- Sys.time()

cat("\n", strrep("=", 70), "\n", sep = "")
cat("  GLOBAL CHILDHOOD VACCINATION COVERAGE  |  ANALYSIS PIPELINE\n")
cat("  Start: ", format(.master_env$run_all_start, "%Y-%m-%d %H:%M:%S"), "\n", sep = "")
cat(strrep("=", 70), "\n", sep = "")

.master_env$steps <- list(
  list(id = "01", path = "R/01_download_data.R",
       label = "[01] Data download (WUENIC + WDI + OxCGRT)",
       skip_if = SKIP_DOWNLOAD),
  list(id = "02", path = "R/02_build_panel.R",
       label = "[02] Country-year panel construction",
       skip_if = FALSE),
  list(id = "03", path = "R/03_descriptive.R",
       label = "[03] Descriptive analysis and figures",
       skip_if = FALSE),
  list(id = "04", path = "R/04_fixed_effects.R",
       label = "[04] Panel fixed effects",
       skip_if = FALSE),
  list(id = "05", path = "R/05_logit_regional.R",
       label = "[05] Regional logit (left-behind)",
       skip_if = FALSE),
  list(id = "06", path = "R/06_mixed_models.R",
       label = "[06] Mixed models (lme4)",
       skip_if = FALSE),
  list(id = "07", path = "R/07_did_covid.R",
       label = "[07] DiD COVID (event study)",
       skip_if = FALSE),
  list(id = "08", path = "R/08_maps.R",
       label = "[08] Choropleth maps",
       skip_if = FALSE),
  list(id = "09", path = "R/09_render_reports.R",
       label = "[09] Compile FR/EN reports",
       skip_if = SKIP_REPORTS)
)

if (!is.null(START_FROM)) {
  start_idx <- which(sapply(.master_env$steps, function(s) s$id == START_FROM))
  if (length(start_idx) == 0) stop("Invalid START_FROM: ", START_FROM)
  .master_env$steps <- .master_env$steps[start_idx:length(.master_env$steps)]
}

for (step in .master_env$steps) {
  if (isTRUE(step$skip_if)) {
    cat("\n[SKIP] ", step$label, "\n", sep = "")
    next
  }
  .master_env$run_step(step$path, step$label)
}

.master_env$run_all_end <- Sys.time()
.master_env$total_duration <- round(
  as.numeric(difftime(.master_env$run_all_end,
                      .master_env$run_all_start, units = "mins")), 1
)

cat("\n", strrep("=", 70), "\n", sep = "")
cat("  PIPELINE COMPLETE\n")
cat("  Total duration: ", .master_env$total_duration, " minutes\n", sep = "")
cat(strrep("=", 70), "\n", sep = "")

cat("\nOutputs:\n")
cat("  Data    : data/processed/panel.rds, panel.csv\n")
cat("  Figures : ", length(list.files("output/figures", pattern = "\\.png$")),
    " PNG in output/figures/\n", sep = "")
cat("  Tables  : ", length(list.files("output/tables", pattern = "\\.csv$")),
    " CSV in output/tables/\n", sep = "")

if (dir.exists("output/models")) {
  cat("  Models  : ", length(list.files("output/models", pattern = "\\.rds$")),
      " RDS in output/models/\n", sep = "")
}

if (dir.exists("docs") && !SKIP_REPORTS) {
  cat("  Reports : docs/index.html (EN) + docs/index_fr.html (FR)\n")
}

rm(.master_env)
