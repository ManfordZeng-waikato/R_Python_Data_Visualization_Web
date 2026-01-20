library(shiny)
library(bslib)
library(leaflet)
library(leaflet.extras)
library(dplyr)
library(readr)
library(DT)

source(file.path("R", "utils", "location_utils.R"))
source(file.path("R", "services", "jobs_data.R"))
source(file.path("R", "services", "jobs_service.R"))
source(file.path("R", "modules", "mod_jobs_explorer.R"))
source(file.path("R", "app_ui.R"))
source(file.path("R", "app_server.R"))

ui <- app_ui()
server <- app_server

shinyApp(ui, server)
