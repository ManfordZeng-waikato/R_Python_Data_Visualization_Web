app_ui <- function() {
  bslib::page_fillable(
    theme = bslib::bs_theme(
      version = 5,
      bootswatch = "flatly",
      primary = "#2563eb",
      base_font = bslib::font_google("Inter"),
      heading_font = bslib::font_google("Inter")
    ),
    shiny::tags$head(
      shiny::tags$style(
        shiny::HTML(
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
    shiny::div(
      class = "app-header",
      shiny::h2("NZ IT Jobs Heatmap"),
      shiny::div(
        class = "app-subtitle",
        "Explore the geographic distribution of IT job postings in New Zealand"
      )
    ),
    mod_jobs_explorer_ui("jobs_explorer")
  )
}

