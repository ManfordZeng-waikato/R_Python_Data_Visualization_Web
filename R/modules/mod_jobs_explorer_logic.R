build_raw_data <- function() {
  shiny::reactive({
    df <- normalize_salary(load_jobs_data())
    prepare_jobs_raw(df)
  })
}

build_filtered_data <- function(raw_data, input) {
  shiny::reactive({
    df <- raw_data()
    filter_jobs_by_keywords(df, input$keyword_filter)
  })
}

build_aggregated_data <- function(filtered_data, group_col) {
  shiny::reactive({
    df <- filtered_data()
    aggregate_jobs(df, group_col())
  })
}

build_kpi <- function(df_all, df_show, group_col, aggregation_level) {
  total_jobs <- nrow(df_all)
  showing_jobs <- nrow(df_show)
  groups_total <- if (nrow(df_all) > 0) dplyr::n_distinct(df_all[[group_col]]) else 0
  groups_show <- if (nrow(df_show) > 0) dplyr::n_distinct(df_show[[group_col]]) else 0

  label <- switch(
    aggregation_level,
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
}

handle_keyword_choices <- function(session, raw_data) {
  shiny::observeEvent(raw_data(), {
    df <- raw_data()
    shiny::updateSelectizeInput(session, "keyword_filter", choices = sort(unique(df$search_keyword)))
  })
}

handle_selection_clear <- function(input, selected_group) {
  shiny::observeEvent(input$clear_selection, {
    selected_group(NULL)
  })
}

handle_selected_text <- function(output, selected_group) {
  output$selected_location <- shiny::renderText({
    sel <- selected_group()
    if (is.null(sel) || !nzchar(sel)) {
      return("None")
    }
    sel
  })
}

mod_jobs_explorer_server <- function(id) {
  shiny::moduleServer(id, function(input, output, session) {
    selected_group <- shiny::reactiveVal(NULL)

    groups <- list(
      bubble = "bubble_markers",
      cluster = "cluster_markers",
      heat = "heat_layer"
    )

    raw_data <- build_raw_data()
    current_group_col <- shiny::reactive({
      get_group_col(input$aggregation_level)
    })

    handle_keyword_choices(session, raw_data)

    filtered_data <- build_filtered_data(raw_data, input)
    aggregated_data <- build_aggregated_data(filtered_data, current_group_col)

    table_data <- shiny::reactive({
      df <- filtered_data()
      group_col <- current_group_col()
      filter_jobs_by_selection(df, group_col, selected_group())
    })

    handle_selection_clear(input, selected_group)
    handle_selected_text(output, selected_group)

    output$kpi_cards <- shiny::renderUI({
      df_all <- filtered_data()
      df_show <- table_data()
      group_col <- current_group_col()
      build_kpi(df_all, df_show, group_col, input$aggregation_level)
    })

    output$jobs_map <- leaflet::renderLeaflet({
      create_base_map(session$ns("jobs_map"))
    })

    shiny::observe({
      shiny::req(input$jobs_map_bounds)

      agg <- aggregated_data()
      mode <- input$map_mode
      if (is.null(mode) || !nzchar(mode)) {
        mode <- "bubble"
      }

      proxy <- leaflet::leafletProxy("jobs_map", session = session)
      proxy <- clear_map_layers(proxy, groups)
      update_map_layers(proxy, agg, mode, groups)
    })

    shiny::observeEvent(input$jobs_map_click, {
      click <- input$jobs_map_click
      if (is.null(click) || is.null(click$lat) || is.null(click$lng)) {
        return()
      }

      selected <- nearest_group(click$lat, click$lng, aggregated_data(), max_km = 80)
      if (!is.null(selected)) {
        selected_group(selected)
      }
    })

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
