library(shiny)
library(leaflet)
library(dplyr)
library(readr)
library(DT)

normalize_city <- function(value) {
  if (is.na(value) || !nzchar(value)) {
    return(NA_character_)
  }

  v <- trimws(as.character(value))

  manual <- c(
    "Auckland CBD" = "Auckland",
    "Albany" = "Auckland",
    "Mount Eden" = "Auckland",
    "Wellington Central" = "Wellington",
    "Petone" = "Wellington",
    "Christchurch Central" = "Christchurch",
    "Addington" = "Christchurch",
    "Palmerston North Central" = "Palmerston North",
    "North Dunedin" = "Dunedin",
    "Taupo Central" = "Taupo"
  )

  if (v %in% names(manual)) {
    return(unname(manual[[v]]))
  }

  lower <- tolower(v)
  if (grepl("auckland", lower)) return("Auckland")
  if (grepl("wellington", lower)) return("Wellington")
  if (grepl("christchurch", lower)) return("Christchurch")
  if (grepl("dunedin", lower)) return("Dunedin")
  if (grepl("taupo", lower)) return("Taupo")
  if (grepl("nelson", lower)) return("Nelson")
  if (grepl("napier", lower)) return("Napier")

  v
}


load_jobs_data <- function() {
  coords_path <- "nz_jobs_data_with_coords.csv"
  fallback_path <- "nz_jobs_data.csv"

  if (file.exists(coords_path)) {
    read_csv(coords_path, show_col_types = FALSE, locale = locale(encoding = "UTF-8"))
  } else {
    read_csv(fallback_path, show_col_types = FALSE, locale = locale(encoding = "UTF-8"))
  }
}


normalize_salary <- function(df) {
  df %>%
    mutate(
      salary_min_num = suppressWarnings(as.numeric(salary_min)),
      salary_max_num = suppressWarnings(as.numeric(salary_max))
    ) %>%
    mutate(
      salary_min_num = ifelse(is.na(salary_min_num), NA, salary_min_num),
      salary_max_num = ifelse(is.na(salary_max_num), NA, salary_max_num)
    )
}


ui <- fluidPage(
  titlePanel("NZ IT Jobs Heatmap"),
  sidebarLayout(
    sidebarPanel(
      selectizeInput(
        "keyword_filter",
        "Search keyword",
        choices = NULL,
        multiple = TRUE,
        options = list(placeholder = "Select search keywords")
      ),
      selectInput(
        "aggregation_level",
        "Aggregation level",
        choices = c("location", "city"),
        selected = "location"
      ),
      hr(),
      h4("Summary"),
      textOutput("summary_stats")
    ),
    mainPanel(
      leafletOutput("jobs_map", height = 520),
      hr(),
      DTOutput("jobs_table")
    )
  )
)


server <- function(input, output, session) {
  raw_data <- reactive({
    df <- normalize_salary(load_jobs_data())

    base_location <- if ("normalized_location" %in% names(df)) {
      df$normalized_location
    } else {
      df$location
    }

    df <- df %>%
      mutate(
        agg_location = ifelse(is.na(base_location) | !nzchar(base_location), NA_character_, as.character(base_location)),
        agg_city = vapply(base_location, normalize_city, character(1))
      )

    df
  })

  observeEvent(raw_data(), {
    df <- raw_data()
    updateSelectizeInput(session, "keyword_filter", choices = sort(unique(df$search_keyword)))
  })

  filtered_data <- reactive({
    df <- raw_data()

    if (length(input$keyword_filter) > 0) {
      df <- df %>% filter(search_keyword %in% input$keyword_filter)
    }

    df
  })

  aggregated_data <- reactive({
    df <- filtered_data()

    group_col <- switch(
      input$aggregation_level,
      location = "agg_location",
      city = "agg_city",
      "agg_location"
    )

    df %>%
      filter(!is.na(latitude), !is.na(longitude)) %>%
      group_by(.data[[group_col]]) %>%
      summarise(
        job_count = n(),
        latitude = mean(latitude, na.rm = TRUE),
        longitude = mean(longitude, na.rm = TRUE),
        avg_salary = mean(salary_min_num, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      rename(location_name = !!rlang::sym(group_col))
  })

  output$summary_stats <- renderText({
    df <- filtered_data()
    total_jobs <- nrow(df)
    group_col <- switch(
      input$aggregation_level,
      location = "agg_location",
      city = "agg_city",
      "agg_location"
    )
    group_label <- switch(
      input$aggregation_level,
      location = "Locations",
      city = "Cities",
      "Locations"
    )
    unique_locations <- n_distinct(df[[group_col]])
    avg_salary <- suppressWarnings(mean(df$salary_min_num, na.rm = TRUE))
    avg_salary_text <- ifelse(is.finite(avg_salary), round(avg_salary), "N/A")

    paste(
      "Jobs:", total_jobs, "\n",
      paste0(group_label, ":"), unique_locations, "\n",
      "Avg min salary:", avg_salary_text
    )
  })

  output$jobs_map <- renderLeaflet({
    leaflet() %>%
      addProviderTiles("CartoDB.Positron") %>%
      setView(lng = 172.0, lat = -41.0, zoom = 5)
  })

  observe({
    agg <- aggregated_data()
    if (nrow(agg) == 0) {
      return()
    }

    pal <- colorNumeric("YlOrRd", agg$job_count)

    leafletProxy("jobs_map", data = agg) %>%
      clearMarkers() %>%
      clearControls() %>%
      addCircleMarkers(
        lng = ~longitude,
        lat = ~latitude,
        radius = ~pmax(4, sqrt(job_count) * 2.5),
        fillColor = ~pal(job_count),
        fillOpacity = 0.8,
        color = "#444444",
        weight = 1,
        label = ~paste0(location_name, ": ", job_count, " jobs"),
        popup = ~paste0(
          "<strong>", location_name, "</strong><br/>",
          "Jobs: ", job_count, "<br/>",
          "Avg min salary: ", ifelse(is.finite(avg_salary), round(avg_salary), "N/A")
        )
      ) %>%
      addLegend(
        "bottomright",
        pal = pal,
        values = ~job_count,
        title = "Jobs"
      )
  })

  output$jobs_table <- renderDT({
    df <- filtered_data() %>%
      select(
        title,
        company,
        location,
        salary,
        posted_date,
        work_type,
        url
      )
    datatable(df, options = list(pageLength = 10, autoWidth = TRUE))
  })
}


shinyApp(ui, server)
