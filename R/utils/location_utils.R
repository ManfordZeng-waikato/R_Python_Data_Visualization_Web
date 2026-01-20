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
    "Kelburn" = "Wellington",
    "Mount Victoria" = "Wellington",
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
    "kelburn|mount victoria|lower hutt|upper hutt|petone|porirua|johnsonville|thorndon|te aro|newtown|kilbirnie|miramar",
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

haversine_km <- function(lat1, lon1, lat2, lon2) {
  rad <- pi / 180
  dlat <- (lat2 - lat1) * rad
  dlon <- (lon2 - lon1) * rad
  a <- sin(dlat / 2)^2 + cos(lat1 * rad) * cos(lat2 * rad) * sin(dlon / 2)^2
  6371 * (2 * atan2(sqrt(a), sqrt(1 - a)))
}

