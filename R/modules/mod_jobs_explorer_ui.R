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
