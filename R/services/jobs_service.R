get_group_col <- function(aggregation_level) {
  switch(
    aggregation_level,
    location = "agg_location",
    city = "agg_city",
    "agg_location"
  )
}

filter_jobs_by_keywords <- function(df, keywords) {
  if (length(keywords) > 0) {
    df <- df %>% dplyr::filter(search_keyword %in% keywords)
  }
  df
}

aggregate_jobs <- function(df, group_col) {
  df %>%
    dplyr::filter(!is.na(latitude), !is.na(longitude)) %>%
    dplyr::group_by(.data[[group_col]]) %>%
    dplyr::summarise(
      job_count = dplyr::n(),
      latitude = mean(latitude, na.rm = TRUE),
      longitude = mean(longitude, na.rm = TRUE),
      avg_salary = mean(salary_min_num, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    dplyr::rename(location_name = !!rlang::sym(group_col)) %>%
    dplyr::mutate(
      marker_id = paste0(
        location_name, "|",
        format(round(latitude, 5), nsmall = 5), "|",
        format(round(longitude, 5), nsmall = 5)
      )
    )
}

filter_jobs_by_selection <- function(df, group_col, selected_group) {
  if (!is.null(selected_group) && nzchar(selected_group)) {
    df <- df %>% dplyr::filter(.data[[group_col]] == selected_group)
  }
  df
}

