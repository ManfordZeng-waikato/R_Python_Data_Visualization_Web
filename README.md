# NZ IT Jobs Heatmap (R Shiny + Python)

This project visualizes New Zealand IT job postings on an interactive Leaflet map.
Python is used for data enrichment (geocoding), and R Shiny provides the web UI.

## Prerequisites

- Python 3.9+
- R 4.1+
- Internet access for geocoding (OpenStreetMap/Nominatim)

## 1. Python Setup

Create and activate a virtual environment, then install dependencies:

```powershell
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

## 2. Add Coordinates to the CSV

Run the geocoding script to generate a new CSV with latitude/longitude:

```powershell
python add_coordinates.py --input nz_jobs_data.csv --output nz_jobs_data_with_coords.csv
```

The script writes a local cache file (`geocode_cache.json`) to reduce API calls.

## 3. R Package Installation

Install required R packages:

```r
source("install_packages.R")
```

## 4. Run the Shiny App

```r
shiny::runApp("app.R")
```

The app will load `nz_jobs_data_with_coords.csv` if available, otherwise it falls back
to `nz_jobs_data.csv`.

## Notes

- If some locations fail to geocode, review or extend the manual mapping in
  `add_coordinates.py` (`MANUAL_LOCATION_MAP`).
- Geocoding uses OpenStreetMap Nominatim. Be considerate with request rates.
- The Shiny app supports both bubble markers and a true heatmap layer (via `leaflet.extras`).
