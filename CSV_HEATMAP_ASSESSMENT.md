# CSV File Assessment for Heatmap Visualization

## Summary

✅ **Your CSV file is READY for R Shiny heatmap visualization!**

## Data Overview

- **Total Jobs**: 200
- **Geographic Coverage**: 100% (all rows have location data)
- **Unique Locations**: 33 different locations
- **Data Format**: UTF-8 with BOM (compatible with R)

## Geographic Data Quality

### Location Distribution (Top 10)

| Location | Job Count | Percentage |
|----------|-----------|------------|
| Auckland CBD | 71 | 35.5% |
| Wellington Central | 29 | 14.5% |
| Christchurch Central | 16 | 8.0% |
| Albany | 9 | 4.5% |
| Wellington | 8 | 4.0% |
| Auckland | 7 | 3.5% |
| Palmerston North Central | 6 | 3.0% |
| Mount Eden | 6 | 3.0% |
| Christchurch | 5 | 2.5% |
| Taupo Central | 4 | 2.0% |

## CSV Structure for Shiny

Your CSV has the following fields:

1. **Geographic Fields** (for heatmap):
   - `location` - Full location name
   - `city` - City name
   - `region` - Region name
   
2. **Job Information**:
   - `search_keyword` - Job search keyword
   - `title` - Job title
   - `company` - Company name
   - `salary`, `salary_min`, `salary_max` - Salary information
   - `description` - Job description
   - `url` - Job URL
   - `job_id` - Unique job ID
   - `posted_date` - Posted date
   - `work_type`, `job_type` - Additional job metadata

## Recommendations for R Shiny

### 1. Data Aggregation

**Option A: Use City/Region Aggregation**
Since `location`, `city`, and `region` fields currently contain similar values (e.g., all "Auckland CBD"), you may want to aggregate by:

- **City level**: Group locations like "Auckland CBD", "Auckland", "Albany", "Mount Eden" → "Auckland"
- **Region level**: Create broader regions (e.g., "Auckland Region", "Wellington Region")

**Option B: Use Current Location Field**
If you want more granular heatmap, use the `location` field directly. However, you may need location name normalization.

### 2. R Code Suggestion

```r
# Read CSV
df <- read.csv("nz_jobs_data.csv", encoding = "UTF-8")

# Aggregate by location for heatmap
location_counts <- df %>%
  group_by(location) %>%
  summarise(job_count = n())

# Or normalize city names first
df <- df %>%
  mutate(
    city_normalized = case_when(
      grepl("Auckland", location, ignore.case = TRUE) ~ "Auckland",
      grepl("Wellington", location, ignore.case = TRUE) ~ "Wellington",
      grepl("Christchurch", location, ignore.case = TRUE) ~ "Christchurch",
      TRUE ~ location
    )
  )
```

### 3. Shiny App Structure

Your Shiny app should:

1. **Load CSV**: Use `read.csv()` with UTF-8 encoding
2. **Filter Data**: Allow filtering by `search_keyword`, salary range, etc.
3. **Aggregate**: Group by location/city/region and count jobs
4. **Visualize**: Use `leaflet` or `ggplot2` with NZ map data for heatmap

### 4. Geographic Mapping

For accurate heatmaps, you may need:

- **NZ Geographic Data**: Use `rgdal` or `sf` package with NZ shapefiles
- **Coordinates**: Consider adding latitude/longitude for each location
- **Map Library**: Use `leaflet` for interactive maps or `ggplot2` for static heatmaps

### 5. Data Enhancement (Optional)

To improve heatmap accuracy, consider:

- Adding latitude/longitude coordinates for each location
- Normalizing location names (e.g., "Auckland CBD" → "Auckland")
- Grouping nearby locations into regions
- Using NZ Statistics geographic codes

## Current Status

✅ **Ready to use**: Your CSV has all necessary fields  
✅ **Geographic data**: 100% coverage  
✅ **Format**: UTF-8 compatible with R  
✅ **Structure**: Clean, well-organized columns  

## Next Steps

1. ✅ CSV file is ready
2. 🔄 Create R Shiny app
3. 🔄 Load and process CSV data
4. 🔄 Create geographic heatmap visualization
5. 🔄 Add filters and interactivity

Your data is well-structured and ready for Shiny visualization!
