library(shiny)
library(bslib)
library(leaflet)
library(leaflet.extras)
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
  theme = bs_theme(
    version = 5,
    bootswatch = "flatly",
    primary = "#2563eb",
    base_font = font_google("Inter"),
    heading_font = font_google("Inter")
  ),
  tags$head(
    tags$style(
      HTML(
        "
        body { background: #f7f9fc; }
        .app-header {
          background: linear-gradient(135deg, #2563eb 0%, #06b6d4 100%);
          color: #fff;
          border-radius: 16px;
          padding: 18px 18px;
          margin-bottom: 14px;
          box-shadow: 0 10px 25px rgba(37, 99, 235, 0.25);
        }
        .app-header h2 { margin: 0; font-weight: 700; }
        .app-subtitle { margin-top: 6px; opacity: 0.92; }

        .sidebar-card {
          background: #ffffff;
          border: 1px solid rgba(15, 23, 42, 0.08);
          border-radius: 14px;
          padding: 14px 14px;
          box-shadow: 0 6px 18px rgba(15, 23, 42, 0.06);
        }

        .content-card {
          background: #ffffff;
          border: 1px solid rgba(15, 23, 42, 0.08);
          border-radius: 14px;
          padding: 12px 12px;
          box-shadow: 0 6px 18px rgba(15, 23, 42, 0.06);
          margin-bottom: 14px;
        }

        .leaflet-container { border-radius: 12px; }
        .leaflet-control {
          border-radius: 12px !important;
          box-shadow: 0 8px 18px rgba(15, 23, 42, 0.10) !important;
          border: 1px solid rgba(15, 23, 42, 0.10) !important;
          background: rgba(255,255,255,0.92) !important;
          backdrop-filter: blur(6px);
        }
        .leaflet-bar a {
          border-radius: 10px !important;
          border: 0 !important;
        }
        .leaflet-popup-content-wrapper {
          border-radius: 14px !important;
          box-shadow: 0 12px 30px rgba(15, 23, 42, 0.18) !important;
        }
        .leaflet-popup-tip {
          box-shadow: 0 12px 30px rgba(15, 23, 42, 0.10) !important;
        }

        /* DT cosmetics */
        table.dataTable { border-collapse: separate !important; border-spacing: 0 8px !important; }
        table.dataTable tbody tr { background: #ffffff; box-shadow: 0 2px 10px rgba(15, 23, 42, 0.05); }
        table.dataTable tbody td { border-top: 0 !important; }
        "
      )
    )
  ),
  div(
    class = "app-header",
    h2("NZ IT Jobs Heatmap"),
    div(class = "app-subtitle", "Interactive geographic distribution of IT job postings in New Zealand")
  ),
  fluidRow(
    column(
      width = 3,
      div(
        class = "sidebar-card",
        h4("Filters"),
        selectizeInput(
          "keyword_filter",
          "Search keyword",
          choices = NULL,
          multiple = TRUE,
          options = list(placeholder = "Select search keywords")
        ),
        radioButtons(
          "map_mode",
          "Map style",
          choices = c("Bubble" = "bubble", "Heatmap" = "heatmap", "Cluster" = "cluster"),
          selected = "bubble",
          inline = TRUE
        ),
        selectInput(
          "aggregation_level",
          "Aggregation level",
          choices = c("location", "city"),
          selected = "location"
        ),
        div(
          style = "margin-top: 8px;",
          strong("Selected:"),
          textOutput("selected_location", inline = TRUE),
          actionButton("clear_selection", "Clear", class = "btn btn-sm btn-outline-secondary", style = "margin-left: 8px;")
        ),
        hr(),
        h4("Summary"),
        textOutput("summary_stats")
      )
    ),
    column(
      width = 9,
      div(
        class = "content-card",
        leafletOutput("jobs_map", height = 560)
      ),
      div(
        class = "content-card",
        h4("Job listings"),
        DTOutput("jobs_table")
      )
    )
  )
)


server <- function(input, output, session) {
  selected_group <- reactiveVal(NULL)

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

  current_group_col <- reactive({
    switch(
      input$aggregation_level,
      location = "agg_location",
      city = "agg_city",
      "agg_location"
    )
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

    group_col <- current_group_col()

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

  # Filter the table by the currently selected group (if any).
  table_data <- reactive({
    df <- filtered_data()
    group_col <- current_group_col()

    sel <- selected_group()
    if (!is.null(sel) && nzchar(sel)) {
      df <- df %>% filter(.data[[group_col]] == sel)
    }

    df
  })

  observeEvent(input$clear_selection, {
    selected_group(NULL)
  })

  output$selected_location <- renderText({
    sel <- selected_group()
    if (is.null(sel) || !nzchar(sel)) {
      return("None")
    }
    sel
  })

  output$summary_stats <- renderText({
    df <- table_data()
    total_jobs <- nrow(df)
    group_col <- current_group_col()
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
      addProviderTiles("CartoDB.PositronNoLabels") %>%
      addProviderTiles("CartoDB.PositronOnlyLabels", options = providerTileOptions(opacity = 0.9)) %>%
      addScaleBar(position = "bottomleft", options = scaleBarOptions(imperial = FALSE)) %>%
      setView(lng = 172.0, lat = -41.0, zoom = 5)
  })

  haversine_km <- function(lat1, lon1, lat2, lon2) {
    rad <- pi / 180
    dlat <- (lat2 - lat1) * rad
    dlon <- (lon2 - lon1) * rad
    a <- sin(dlat / 2)^2 + cos(lat1 * rad) * cos(lat2 * rad) * sin(dlon / 2)^2
    6371 * (2 * atan2(sqrt(a), sqrt(1 - a)))
  }

  # Clicking on the map (including on heatmap areas) selects the nearest group.
  observeEvent(input$jobs_map_click, {
    click <- input$jobs_map_click
    if (is.null(click) || is.null(click$lat) || is.null(click$lng)) {
      return()
    }

    agg <- aggregated_data()
    if (nrow(agg) == 0) {
      return()
    }

    d <- haversine_km(click$lat, click$lng, agg$latitude, agg$longitude)
    idx <- which.min(d)
    if (length(idx) == 0 || !is.finite(d[idx])) {
      return()
    }

    # Only select if reasonably close to a point (helps avoid accidental selections).
    if (d[idx] <= 80) {
      selected_group(as.character(agg$location_name[idx]))
    }
  })

  # Clicking a marker selects that group immediately.
  observeEvent(input$jobs_map_marker_click, {
    click <- input$jobs_map_marker_click
    if (is.null(click) || is.null(click$id)) {
      return()
    }
    selected_group(as.character(click$id))
  })

  observe({
    agg <- aggregated_data()
    if (nrow(agg) == 0) {
      return()
    }

    pal <- colorNumeric(
      palette = c("#93c5fd", "#3b82f6", "#1d4ed8", "#7c3aed", "#ef4444"),
      domain = agg$job_count
    )

    proxy <- leafletProxy("jobs_map", data = agg) %>%
      clearMarkers() %>%
      clearControls() %>%
      clearHeatmap()

    if (is.null(input$map_mode) || input$map_mode == "bubble") {
      proxy %>%
        addCircleMarkers(
          lng = ~longitude,
          lat = ~latitude,
          radius = ~pmax(5, sqrt(job_count) * 2.8),
          fillColor = ~pal(job_count),
          fillOpacity = 0.68,
          color = "#ffffff",
          opacity = 0.9,
          weight = 2,
          layerId = ~location_name,
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
          title = "Jobs",
          opacity = 0.95
        )
    } else if (input$map_mode == "cluster") {
      proxy %>%
        addCircleMarkers(
          lng = ~longitude,
          lat = ~latitude,
          radius = ~pmax(4, sqrt(job_count) * 2.3),
          fillColor = ~pal(job_count),
          fillOpacity = 0.75,
          color = "#ffffff",
          opacity = 0.9,
          weight = 2,
          layerId = ~location_name,
          label = ~paste0(location_name, ": ", job_count, " jobs"),
          popup = ~paste0(
            "<strong>", location_name, "</strong><br/>",
            "Jobs: ", job_count, "<br/>",
            "Avg min salary: ", ifelse(is.finite(avg_salary), round(avg_salary), "N/A")
          ),
          clusterOptions = markerClusterOptions()
        ) %>%
        addLegend(
          "bottomright",
          pal = pal,
          values = ~job_count,
          title = "Jobs",
          opacity = 0.95
        )
    } else {
      heat_intensity <- sqrt(agg$job_count)
      heat_max <- suppressWarnings(as.numeric(stats::quantile(heat_intensity, 0.95, na.rm = TRUE)))
      if (!is.finite(heat_max) || heat_max <= 0) {
        heat_max <- max(heat_intensity, na.rm = TRUE)
      }

      proxy %>%
        addHeatmap(
          lng = ~longitude,
          lat = ~latitude,
          intensity = ~sqrt(job_count),
          blur = 16,
          radius = 20,
          minOpacity = 0.25,
          max = heat_max,
          gradient = c(
            "0.00" = "#93c5fd",
            "0.40" = "#3b82f6",
            "0.65" = "#1d4ed8",
            "0.85" = "#7c3aed",
            "1.00" = "#ef4444"
          )
        ) %>%
        addLegend(
          "bottomright",
          pal = pal,
          values = ~job_count,
          title = "Jobs",
          opacity = 0.95
        )
    }
  })

  output$jobs_table <- renderDT({
    df <- table_data() %>%
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
