create_base_map <- function(ns_id) {
  nz_lng_min <- 166.2
  nz_lng_max <- 178.9
  nz_lat_min <- -47.8
  nz_lat_max <- -34.0

  leaflet::leaflet(
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
}

clear_map_layers <- function(proxy, groups) {
  proxy <- tryCatch(
    leaflet::clearMarkerClusters(proxy),
    error = function(e) {
      proxy
    }
  )

  proxy <- proxy %>%
    leaflet::clearGroup(groups$bubble) %>%
    leaflet::clearGroup(groups$cluster) %>%
    leaflet::clearGroup(groups$heat)

  proxy <- tryCatch(leaflet.extras::clearHeatmap(proxy), error = function(e) proxy)

  proxy %>%
    leaflet::clearControls() %>%
    leaflet::addScaleBar(position = "bottomleft", options = leaflet::scaleBarOptions(imperial = FALSE))
}

update_map_layers <- function(proxy, agg, mode, groups) {
  if (is.null(agg) || nrow(agg) == 0) {
    return(proxy)
  }

  pal <- leaflet::colorNumeric(
    palette = c("#93c5fd", "#3b82f6", "#1d4ed8", "#7c3aed", "#ef4444"),
    domain = agg$job_count
  )

  if (mode == "heatmap") {
    heat_intensity <- sqrt(agg$job_count)
    heat_max <- suppressWarnings(as.numeric(stats::quantile(heat_intensity, 0.95, na.rm = TRUE)))
    if (!is.finite(heat_max) || heat_max <= 0) {
      heat_max <- max(heat_intensity, na.rm = TRUE)
    }

    proxy <- proxy %>%
      leaflet.extras::addHeatmap(
        data = agg,
        lng = ~longitude,
        lat = ~latitude,
        group = groups$heat,
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
    proxy <- proxy %>%
      leaflet::addCircleMarkers(
        data = agg,
        lng = ~longitude,
        lat = ~latitude,
        group = groups$cluster,
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
    proxy <- proxy %>%
      leaflet::addCircleMarkers(
        data = agg,
        lng = ~longitude,
        lat = ~latitude,
        group = groups$bubble,
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

  proxy %>%
    leaflet::addLegend(
      "bottomright",
      pal = pal,
      values = agg$job_count,
      title = "Jobs",
      opacity = 0.95
    )
}

nearest_group <- function(click_lat, click_lng, agg, max_km = 80) {
  if (is.null(agg) || nrow(agg) == 0) {
    return(NULL)
  }

  d <- haversine_km(click_lat, click_lng, agg$latitude, agg$longitude)
  idx <- which.min(d)
  if (length(idx) == 0 || !is.finite(d[idx])) {
    return(NULL)
  }

  if (d[idx] <= max_km) {
    return(as.character(agg$location_name[idx]))
  }

  NULL
}
