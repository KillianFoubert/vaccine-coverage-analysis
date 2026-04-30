# ============================================================================
# 09_render_reports.R
# ----------------------------------------------------------------------------
# Compile EN and FR reports to /docs/ for GitHub Pages deployment.
#
# GitHub Pages convention:
#   /docs/index.html       -> EN report (default language)
#   /docs/index_fr.html    -> FR report
#   /docs/.nojekyll        -> disables Jekyll (allows underscores)
# ============================================================================

library(here)
library(rmarkdown)

DOCS_DIR <- here("docs")
RMD_DIR  <- here("rmd")

if (!dir.exists(DOCS_DIR)) dir.create(DOCS_DIR, recursive = TRUE)

# .nojekyll for GitHub Pages
nojekyll_path <- file.path(DOCS_DIR, ".nojekyll")
if (!file.exists(nojekyll_path)) file.create(nojekyll_path)

# Compile EN (index.html, default language)
message("\n>> Compiling EN report (index.html)...")
render(
  input = file.path(RMD_DIR, "report_en.Rmd"),
  output_file = "index.html",
  output_dir = DOCS_DIR,
  quiet = TRUE
)
message("EN report compiled -> docs/index.html")

# Compile FR (index_fr.html)
message("\n>> Compiling FR report (index_fr.html)...")
render(
  input = file.path(RMD_DIR, "report_fr.Rmd"),
  output_file = "index_fr.html",
  output_dir = DOCS_DIR,
  quiet = TRUE
)
message("FR report compiled -> docs/index_fr.html")

message("\nReports available at:")
message("  docs/index.html     (EN, default)")
message("  docs/index_fr.html  (FR)")
