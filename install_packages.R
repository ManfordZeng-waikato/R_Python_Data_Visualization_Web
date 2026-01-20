required_packages <- c(
  "shiny",
  "bslib",
  "leaflet",
  "leaflet.extras",
  "dplyr",
  "rlang",
  "readr",
  "DT",
  "ggplot2",
  "sf"
)

installed <- rownames(installed.packages())
missing <- setdiff(required_packages, installed)

if (length(missing) > 0) {
  install.packages(missing, repos = "https://cloud.r-project.org")
}

invisible(lapply(required_packages, library, character.only = TRUE))
