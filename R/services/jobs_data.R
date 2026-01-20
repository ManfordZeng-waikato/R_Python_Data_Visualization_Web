load_jobs_data <- function() {
  coords_path <- "nz_jobs_data_with_coords.csv"
  fallback_path <- "nz_jobs_data.csv"

  if (file.exists(coords_path)) {
    readr::read_csv(
      coords_path,
      show_col_types = FALSE,
      locale = readr::locale(encoding = "UTF-8")
    )
  } else {
    readr::read_csv(
      fallback_path,
      show_col_types = FALSE,
      locale = readr::locale(encoding = "UTF-8")
    )
  }
}

normalize_salary <- function(df) {
  df %>%
    dplyr::mutate(
      salary_min_num = suppressWarnings(as.numeric(salary_min)),
      salary_max_num = suppressWarnings(as.numeric(salary_max))
    ) %>%
    dplyr::mutate(
      salary_min_num = ifelse(is.na(salary_min_num), NA, salary_min_num),
      salary_max_num = ifelse(is.na(salary_max_num), NA, salary_max_num)
    )
}

prepare_jobs_raw <- function(df) {
  # Use the most granular location we have for "location" aggregation.
  # If the enriched CSV is used, it should contain raw_location (original location string).
  base_location_raw <- if ("raw_location" %in% names(df)) {
    df$raw_location
  } else if ("location" %in% names(df)) {
    df$location
  } else {
    NA_character_
  }

  df %>%
    dplyr::mutate(
      agg_location = ifelse(
        is.na(base_location_raw) | !nzchar(base_location_raw),
        NA_character_,
        as.character(base_location_raw)
      ),
      agg_city = vapply(base_location_raw, normalize_city, character(1))
    )
}

