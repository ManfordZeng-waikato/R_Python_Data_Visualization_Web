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
    "Grey Lynn" = "Auckland",
    "Albany" = "Auckland",
    "Mount Eden" = "Auckland",
    "Mount Wellington" = "Auckland",
    "Wellington Central" = "Wellington",
    "Petone" = "Wellington",
    "Lower Hutt" = "Wellington",
    "Christchurch Central" = "Christchurch",
    "Addington" = "Christchurch",
    "Palmerston North Central" = "Palmerston North",
    "North Dunedin" = "Dunedin",
    "Taupo Central" = "Taupo",
    "Hamilton Lake" = "Hamilton",
    "Te Rapa" = "Hamilton"
  )

  if (v %in% names(manual)) {
    return(unname(manual[[v]]))
  }

  lower <- tolower(v)

  # Common Auckland suburbs that should aggregate to Auckland at city level.
  if (grepl(
    "grey lynn|ponsonby|takapuna|newmarket|remuera|epsom|parnell|grafton|ellerslie|penrose|onehunga|avondale|mt albert|mount albert|new lynn|henderson|glenfield|rosedale|manukau|papatoetoe|howick|east tamaki|mount roskill|mt roskill|devonport|browns bay|mount wellington|mt wellington",
    lower
  )) {
    return("Auckland")
  }

  # Wellington region suburbs (treat as Wellington at city aggregation).
  if (grepl(
    "lower hutt|upper hutt|petone|porirua|johnsonville|thorndon|te aro|newtown|kilbirnie|miramar",
    lower
  )) {
    return("Wellington")
  }

  # Hamilton suburbs (treat as Hamilton at city aggregation).
  if (grepl(
    "hamilton lake|hamilton east|te rapa|chartwell|rototuna|frankton|claudelands|hillcrest|dinsdale",
    lower
  )) {
    return("Hamilton")
  }

  # Christchurch suburbs (treat as Christchurch at city aggregation).
  if (grepl(
    "addington|riccarton|hornby|sydenham|ilam|fendalton|papanui|linwood|wigram|halswell",
    lower
  )) {
    return("Christchurch")
  }

  if (grepl("auckland", lower)) return("Auckland")
  if (grepl("wellington", lower)) return("Wellington")
  if (grepl("christchurch", lower)) return("Christchurch")
  if (grepl("hamilton", lower)) return("Hamilton")
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


ui <- page_fillable(
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
          margin: 14px 0 14px 0;
          box-shadow: 0 10px 25px rgba(37, 99, 235, 0.25);
        }
        .app-header h2 { margin: 0; font-weight: 700; }
        .app-subtitle { margin-top: 6px; opacity: 0.92; }

        .leaflet-container { border-radius: 12px; }
        .leaflet-control {
          border-radius: 12px !important;
          box-shadow: 0 8px 18px rgba(15, 23, 42, 0.10) !important;
          border: 1px solid rgba(15, 23, 42, 0.10) !important;
          background: rgba(255,255,255,0.92) !important;
          backdrop-filter: blur(6px);
        }
        .leaflet-bar a { border-radius: 10px !important; border: 0 !important; }
        .leaflet-popup-content-wrapper {
          border-radius: 14px !important;
          box-shadow: 0 12px 30px rgba(15, 23, 42, 0.18) !important;
        }
        .leaflet-popup-tip { box-shadow: 0 12px 30px rgba(15, 23, 42, 0.10) !important; }

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
    div(class = "app-subtitle", "Explore the geographic distribution of IT job postings in New Zealand")
  ),
  layout_sidebar(
    fillable = TRUE,
    sidebar = sidebar(
      title = "Controls",
      open = "desktop",
      width = 340,
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
      radioButtons(
        "map_mode",
        "Map style",
        choices = c("Bubble" = "bubble", "Heatmap" = "heatmap", "Cluster" = "cluster"),
        selected = "bubble",
        inline = TRUE
      ),
      hr(),
      div(
        style = "display:flex; align-items:center; justify-content:space-between; gap: 8px;",
        div(
          div(style = "font-weight: 600;", "Selected"),
          textOutput("selected_location", inline = TRUE)
        ),
        actionButton("clear_selection", "Clear", class = "btn btn-sm btn-outline-secondary")
      ),
      hr(),
      div(style = "font-weight: 600;", "Map points"),
      textOutput("map_points_summary"),
      tags$details(
        tags$summary("Diagnostics"),
        verbatimTextOutput("map_points_debug")
      )
    ),
    uiOutput("kpi_cards"),
    navset_card_tab(
      height = "100%",
      nav_panel(
        "Map",
        card_body(fill = TRUE, leafletOutput("jobs_map", height = "100%"))
      ),
      nav_panel(
        "Job listings",
        card_body(
          h6(style = "margin-bottom: 10px; opacity: 0.8;", "Tip: use search in the table header and sort columns."),
          DTOutput("jobs_table")
        )
      )
    )
  )
)


server <- function(input, output, session) {
  selected_group <- reactiveVal(NULL)

  GROUP_BUBBLE <- "bubble_markers"
  GROUP_CLUSTER <- "cluster_markers"
  GROUP_HEAT <- "heat_layer"

  raw_data <- reactive({
    df <- normalize_salary(load_jobs_data())

    # Use the most granular location we have for "location" aggregation.
    # If the enriched CSV is used, it should contain raw_location (original location string).
    base_location_raw <- if ("raw_location" %in% names(df)) {
      df$raw_location
    } else if ("location" %in% names(df)) {
      df$location
    } else {
      NA_character_
    }

    df <- df %>%
      mutate(
        agg_location = ifelse(
          is.na(base_location_raw) | !nzchar(base_location_raw),
          NA_character_,
          as.character(base_location_raw)
        ),
        agg_city = vapply(base_location_raw, normalize_city, character(1))
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
      rename(location_name = !!rlang::sym(group_col)) %>%
      mutate(
        marker_id = paste0(
          location_name, "|",
          format(round(latitude, 5), nsmall = 5), "|",
          format(round(longitude, 5), nsmall = 5)
        )
      )
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

  output$map_points_summary <- renderText({
    agg <- aggregated_data()
    if (is.null(agg) || nrow(agg) == 0) {
      return("0 points")
    }
    paste0(nrow(agg), " points")
  })

  output$map_points_debug <- renderText({
    agg <- aggregated_data()
    if (is.null(agg) || nrow(agg) == 0) {
      return("aggregated_data(): 0 rows")
    }

    head_names <- paste(head(agg$location_name, 10), collapse = ", ")
    paste0(
      "aggregation_level: ", input$aggregation_level, "\n",
      "map_mode: ", input$map_mode, "\n",
      "rows: ", nrow(agg), "\n",
      "lat range: ", paste(range(agg$latitude, na.rm = TRUE), collapse = " .. "), "\n",
      "lng range: ", paste(range(agg$longitude, na.rm = TRUE), collapse = " .. "), "\n",
      "top names: ", head_names
    )
  })

  output$kpi_cards <- renderUI({
    df_all <- filtered_data()
    df_show <- table_data()
    group_col <- current_group_col()

    total_jobs <- nrow(df_all)
    showing_jobs <- nrow(df_show)
    groups_total <- if (nrow(df_all) > 0) n_distinct(df_all[[group_col]]) else 0
    groups_show <- if (nrow(df_show) > 0) n_distinct(df_show[[group_col]]) else 0
    avg_salary <- suppressWarnings(mean(df_show$salary_min_num, na.rm = TRUE))
    avg_salary_text <- ifelse(is.finite(avg_salary), format(round(avg_salary), big.mark = ","), "N/A")

    label <- switch(
      input$aggregation_level,
      location = "Locations",
      city = "Cities",
      "Locations"
    )

    layout_columns(
      col_widths = c(3, 3, 3, 3),
      value_box(title = "Total jobs", value = format(total_jobs, big.mark = ",")),
      value_box(title = "Showing jobs", value = format(showing_jobs, big.mark = ",")),
      value_box(title = paste0(label, " (total)"), value = format(groups_total, big.mark = ",")),
      value_box(title = paste0(label, " (showing)"), value = format(groups_show, big.mark = ","))
    )
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
    # Limit view to NZ main islands only (exclude remote ocean/islands like Chatham/Kermadec).
    nz_lng_min <- 166.2
    nz_lng_max <- 178.9
    nz_lat_min <- -47.8
    nz_lat_max <- -34.0

    agg <- aggregated_data()

    base <- leaflet(
      options = leafletOptions(
        minZoom = 4,
        maxBoundsViscosity = 1.0,
        preferCanvas = TRUE
      )
    ) %>%
      addProviderTiles("CartoDB.PositronNoLabels") %>%
      addProviderTiles("CartoDB.PositronOnlyLabels", options = providerTileOptions(opacity = 0.9)) %>%
      addScaleBar(position = "bottomleft", options = scaleBarOptions(imperial = FALSE)) %>%
      fitBounds(
        lng1 = nz_lng_min,
        lat1 = nz_lat_min,
        lng2 = nz_lng_max,
        lat2 = nz_lat_max
      ) %>%
      setMaxBounds(
        lng1 = nz_lng_min,
        lat1 = nz_lat_min,
        lng2 = nz_lng_max,
        lat2 = nz_lat_max
      )

    if (is.null(agg) || nrow(agg) == 0) {
      return(base)
    }

    pal <- colorNumeric(
      palette = c("#93c5fd", "#3b82f6", "#1d4ed8", "#7c3aed", "#ef4444"),
      domain = agg$job_count
    )

    mode <- input$map_mode
    if (is.null(mode) || !nzchar(mode)) {
      mode <- "bubble"
    }

    if (mode == "heatmap") {
      heat_intensity <- sqrt(agg$job_count)
      heat_max <- suppressWarnings(as.numeric(stats::quantile(heat_intensity, 0.95, na.rm = TRUE)))
      if (!is.finite(heat_max) || heat_max <= 0) {
        heat_max <- max(heat_intensity, na.rm = TRUE)
      }

      base <- base %>%
        addHeatmap(
          data = agg,
          lng = ~longitude,
          lat = ~latitude,
          group = GROUP_HEAT,
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
        )
    } else if (mode == "cluster") {
      # Keep cluster visuals consistent with Bubble: clustered circle markers.
      base <- base %>%
        addCircleMarkers(
          data = agg,
          lng = ~longitude,
          lat = ~latitude,
          group = GROUP_CLUSTER,
          radius = ~pmax(5, sqrt(job_count) * 2.8),
          fillColor = ~pal(job_count),
          fillOpacity = 0.68,
          color = "#ffffff",
          opacity = 0.9,
          weight = 2,
          layerId = ~marker_id,
          label = ~paste0(location_name, ": ", job_count, " jobs"),
          popup = ~paste0(
            "<strong>", location_name, "</strong><br/>",
            "Jobs: ", job_count, "<br/>",
            "Avg min salary: ", ifelse(is.finite(avg_salary), round(avg_salary), "N/A")
          ),
          clusterOptions = markerClusterOptions(
            disableClusteringAtZoom = 7,
            maxClusterRadius = 45,
            spiderfyOnMaxZoom = TRUE,
            zoomToBoundsOnClick = TRUE,
            showCoverageOnHover = FALSE
          )
        )
    } else {
      base <- base %>%
        addCircleMarkers(
          data = agg,
          lng = ~longitude,
          lat = ~latitude,
          group = GROUP_BUBBLE,
          radius = ~pmax(5, sqrt(job_count) * 2.8),
          fillColor = ~pal(job_count),
          fillOpacity = 0.68,
          color = "#ffffff",
          opacity = 0.9,
          weight = 2,
          layerId = ~marker_id,
          label = ~paste0(location_name, ": ", job_count, " jobs"),
          popup = ~paste0(
            "<strong>", location_name, "</strong><br/>",
            "Jobs: ", job_count, "<br/>",
            "Avg min salary: ", ifelse(is.finite(avg_salary), round(avg_salary), "N/A")
          )
        )
    }

    base %>%
      addLegend(
        "bottomright",
        pal = pal,
        values = agg$job_count,
        title = "Jobs",
        opacity = 0.95
      )
  })

  haversine_km <- function(lat1, lon1, lat2, lon2) {
    rad <- pi / 180
    dlat <- (lat2 - lat1) * rad
    dlon <- (lon2 - lon1) * rad
    a <- sin(dlat / 2)^2 + cos(lat1 * rad) * cos(lat2 * rad) * sin(dlon / 2)^2
    6371 * (2 * atan2(sqrt(a), sqrt(1 - a)))
  }

  clear_cluster_layers <- function(map) {
    tryCatch(
      {
        leaflet::clearMarkerClusters(map)
      },
      error = function(e) {
        map
      }
    )
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
    agg <- aggregated_data()
    if (is.null(agg) || nrow(agg) == 0) {
      return()
    }
    idx <- which(agg$marker_id == as.character(click$id))
    if (length(idx) >= 1) {
      selected_group(as.character(agg$location_name[idx[1]]))
    }
  })

  # Map layers are rendered inside output$jobs_map to avoid stale cluster layers.

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

    df$url <- ifelse(
      is.na(df$url) | df$url == "",
      "",
      paste0('<a href="', df$url, '" target="_blank" rel="noopener noreferrer">Open</a>')
    )

    datatable(
      df,
      escape = FALSE,
      rownames = FALSE,
      options = list(
        pageLength = 12,
        autoWidth = TRUE,
        scrollX = TRUE,
        order = list(list(4, "desc"))
      )
    )
  })
}


shinyApp(ui, server)
