mod_jobs_explorer_ui <- function(id) {
  ns <- shiny::NS(id)

  bslib::layout_sidebar(
    fillable = TRUE,
    sidebar = bslib::sidebar(
      title = "Controls",
      open = "desktop",
      width = 340,
      shiny::selectizeInput(
        ns("keyword_filter"),
        "Search keyword",
        choices = NULL,
        multiple = TRUE,
        options = list(placeholder = "Select search keywords")
      ),
      shiny::selectInput(
        ns("aggregation_level"),
        "Aggregation level",
        choices = c("location", "city"),
        selected = "location"
      ),
      shiny::radioButtons(
        ns("map_mode"),
        "Map style",
        choices = c("Bubble" = "bubble", "Heatmap" = "heatmap", "Cluster" = "cluster"),
        selected = "bubble",
        inline = TRUE
      ),
      shiny::hr(),
      shiny::div(
        style = "display:flex; align-items:center; justify-content:space-between; gap: 8px;",
        shiny::div(
          shiny::div(style = "font-weight: 600;", "Selected"),
          shiny::textOutput(ns("selected_location"), inline = TRUE)
        ),
        shiny::actionButton(ns("clear_selection"), "Clear", class = "btn btn-sm btn-outline-secondary")
      ),
      shiny::hr(),
      NULL
    ),
    shiny::uiOutput(ns("kpi_cards")),
    bslib::navset_card_tab(
      height = "100%",
      bslib::nav_panel(
        "Map",
        bslib::card_body(fill = TRUE, leaflet::leafletOutput(ns("jobs_map"), height = "100%"))
      ),
      bslib::nav_panel(
        "Job listings",
        bslib::card_body(
          shiny::h6(style = "margin-bottom: 10px; opacity: 0.8;", "Tip: use search in the table header and sort columns."),
          DT::DTOutput(ns("jobs_table"))
        )
      )
    )
  )
}

mod_jobs_explorer_server <- function(id) {
  shiny::moduleServer(id, function(input, output, session) {
    selected_group <- shiny::reactiveVal(NULL)

    GROUP_BUBBLE <- "bubble_markers"
    GROUP_CLUSTER <- "cluster_markers"
    GROUP_HEAT <- "heat_layer"

    raw_data <- shiny::reactive({
      df <- normalize_salary(load_jobs_data())
      prepare_jobs_raw(df)
    })

    current_group_col <- shiny::reactive({
      get_group_col(input$aggregation_level)
    })

    shiny::observeEvent(raw_data(), {
      df <- raw_data()
      shiny::updateSelectizeInput(session, "keyword_filter", choices = sort(unique(df$search_keyword)))
    })

    filtered_data <- shiny::reactive({
      df <- raw_data()
      filter_jobs_by_keywords(df, input$keyword_filter)
    })

    aggregated_data <- shiny::reactive({
      df <- filtered_data()
      group_col <- current_group_col()
      aggregate_jobs(df, group_col)
    })

    table_data <- shiny::reactive({
      df <- filtered_data()
      group_col <- current_group_col()
      filter_jobs_by_selection(df, group_col, selected_group())
    })

    shiny::observeEvent(input$clear_selection, {
      selected_group(NULL)
    })

    output$selected_location <- shiny::renderText({
      sel <- selected_group()
      if (is.null(sel) || !nzchar(sel)) {
        return("None")
      }
      sel
    })

    output$kpi_cards <- shiny::renderUI({
      df_all <- filtered_data()
      df_show <- table_data()
      group_col <- current_group_col()

      total_jobs <- nrow(df_all)
      showing_jobs <- nrow(df_show)
      groups_total <- if (nrow(df_all) > 0) dplyr::n_distinct(df_all[[group_col]]) else 0
      groups_show <- if (nrow(df_show) > 0) dplyr::n_distinct(df_show[[group_col]]) else 0

      label <- switch(
        input$aggregation_level,
        location = "Locations",
        city = "Cities",
        "Locations"
      )

      bslib::layout_columns(
        col_widths = c(3, 3, 3, 3),
        bslib::value_box(title = "Total jobs", value = format(total_jobs, big.mark = ",")),
        bslib::value_box(title = "Showing jobs", value = format(showing_jobs, big.mark = ",")),
        bslib::value_box(title = paste0(label, " (total)"), value = format(groups_total, big.mark = ",")),
        bslib::value_box(title = paste0(label, " (showing)"), value = format(groups_show, big.mark = ","))
      )
    })

    output$jobs_map <- leaflet::renderLeaflet({
      # Limit view to NZ main islands only (exclude remote ocean/islands like Chatham/Kermadec).
      nz_lng_min <- 166.2
      nz_lng_max <- 178.9
      nz_lat_min <- -47.8
      nz_lat_max <- -34.0

      agg <- aggregated_data()

      base <- leaflet::leaflet(
        options = leaflet::leafletOptions(
          minZoom = 4,
          maxBoundsViscosity = 1.0,
          preferCanvas = TRUE
        )
      ) %>%
        leaflet::addProviderTiles("CartoDB.PositronNoLabels") %>%
        leaflet::addProviderTiles("CartoDB.PositronOnlyLabels", options = leaflet::providerTileOptions(opacity = 0.9)) %>%
        leaflet::addScaleBar(position = "bottomleft", options = leaflet::scaleBarOptions(imperial = FALSE)) %>%
        leaflet::fitBounds(
          lng1 = nz_lng_min,
          lat1 = nz_lat_min,
          lng2 = nz_lng_max,
          lat2 = nz_lat_max
        ) %>%
        leaflet::setMaxBounds(
          lng1 = nz_lng_min,
          lat1 = nz_lat_min,
          lng2 = nz_lng_max,
          lat2 = nz_lat_max
        )

      if (is.null(agg) || nrow(agg) == 0) {
        return(base)
      }

      pal <- leaflet::colorNumeric(
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
          leaflet.extras::addHeatmap(
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
        base <- base %>%
          leaflet::addCircleMarkers(
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
            clusterOptions = leaflet::markerClusterOptions(
              disableClusteringAtZoom = 7,
              maxClusterRadius = 45,
              spiderfyOnMaxZoom = TRUE,
              zoomToBoundsOnClick = TRUE,
              showCoverageOnHover = FALSE
            )
          )
      } else {
        base <- base %>%
          leaflet::addCircleMarkers(
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
        leaflet::addLegend(
          "bottomright",
          pal = pal,
          values = agg$job_count,
          title = "Jobs",
          opacity = 0.95
        )
    })

    # Clicking on the map (including on heatmap areas) selects the nearest group.
    shiny::observeEvent(input$jobs_map_click, {
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
    shiny::observeEvent(input$jobs_map_marker_click, {
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

    output$jobs_table <- DT::renderDT({
      df <- table_data() %>%
        dplyr::select(
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

      DT::datatable(
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
  })
}

