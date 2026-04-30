# ============================================================================
# dependencies.R
# ----------------------------------------------------------------------------
# Liste et installation des packages nécessaires au projet.
# À exécuter une fois au premier clone, puis renv::snapshot() pour figer.
# ============================================================================

required_packages <- c(
  # Infrastructure
  "here",          # chemins relatifs robustes
  "renv",          # gestion reproductible des versions

  # Manipulation de données
  "dplyr",
  "tidyr",
  "readr",
  "lubridate",
  "purrr",
  "stringr",

  # Import de sources externes
  "WDI",           # World Bank data
  "jsonlite",      # API GHO (WUENIC)
  "countrycode",   # harmonisation ISO/OMS

  # Modélisation
  "plm",           # panel data models classiques
  "fixest",        # estimation FE rapide + DiD
  "lme4",          # modèles mixtes
  "sandwich",      # erreurs standard robustes
  "lmtest",        # tests d'hypothèses
  "broom",         # tidy outputs de modèles
  "broom.mixed",   # tidy pour lme4
  "margins",       # effets marginaux

  # Cartographie
  "sf",            # objets spatiaux
  "rnaturalearth", # shapefile monde
  "rnaturalearthdata",

  # Visualisation et rapport
  "ggplot2",
  "scales",
  "viridis",       # palettes
  "patchwork",     # combiner figures
  "kableExtra",    # tableaux
  "gt",            # tableaux alternatifs
  "rmarkdown",
  "knitr"
)

missing <- required_packages[!required_packages %in% installed.packages()[, "Package"]]

if (length(missing) > 0) {
  message("Installation de : ", paste(missing, collapse = ", "))
  install.packages(missing)
} else {
  message("Tous les packages sont installés.")
}

# Vérification du chargement
invisible(lapply(required_packages, function(p) {
  suppressPackageStartupMessages(library(p, character.only = TRUE))
}))

message("Environnement prêt.")
