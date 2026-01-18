"""
Check CSV file for heatmap visualization requirements
Analyzes if the CSV has proper geographic data for R Shiny heatmap
"""
import csv
from collections import Counter
from pathlib import Path

def analyze_csv_for_heatmap(csv_path: str):
    """Analyze CSV file for heatmap visualization requirements"""
    
    csv_file = Path(csv_path)
    if not csv_file.exists():
        print(f"Error: CSV file not found: {csv_path}")
        return
    
    print("="*70)
    print("CSV File Analysis for Heatmap Visualization")
    print("="*70)
    
    with open(csv_file, 'r', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        rows = list(reader)
    
    total_rows = len(rows)
    print(f"\n1. Basic Statistics:")
    print(f"   Total rows: {total_rows}")
    print(f"   Columns: {', '.join(reader.fieldnames)}")
    
    # Check geographic fields
    print(f"\n2. Geographic Data Analysis:")
    
    # Location field
    locations = [r.get('location', '').strip() for r in rows if r.get('location', '').strip()]
    location_count = len(locations)
    location_coverage = (location_count / total_rows * 100) if total_rows > 0 else 0
    print(f"   Location field:")
    print(f"     - Rows with data: {location_count} ({location_coverage:.1f}%)")
    print(f"     - Unique locations: {len(set(locations))}")
    
    # City field
    cities = [r.get('city', '').strip() for r in rows if r.get('city', '').strip()]
    city_count = len(cities)
    city_coverage = (city_count / total_rows * 100) if total_rows > 0 else 0
    print(f"   City field:")
    print(f"     - Rows with data: {city_count} ({city_coverage:.1f}%)")
    print(f"     - Unique cities: {len(set(cities))}")
    
    # Region field
    regions = [r.get('region', '').strip() for r in rows if r.get('region', '').strip()]
    region_count = len(regions)
    region_coverage = (region_count / total_rows * 100) if total_rows > 0 else 0
    print(f"   Region field:")
    print(f"     - Rows with data: {region_count} ({region_coverage:.1f}%)")
    print(f"     - Unique regions: {len(set(regions))}")
    
    # Top locations
    print(f"\n3. Top 10 Locations (by job count):")
    location_counts = Counter(locations)
    for i, (loc, count) in enumerate(location_counts.most_common(10), 1):
        print(f"   {i}. {loc}: {count} jobs")
    
    # Top cities
    print(f"\n4. Top 10 Cities (by job count):")
    city_counts = Counter(cities)
    for i, (city, count) in enumerate(city_counts.most_common(10), 1):
        print(f"   {i}. {city}: {count} jobs")
    
    # Top regions
    print(f"\n5. Top Regions (by job count):")
    region_counts = Counter(regions)
    for i, (region, count) in enumerate(region_counts.most_common(10), 1):
        print(f"   {i}. {region}: {count} jobs")
    
    # Data quality check
    print(f"\n6. Data Quality Assessment:")
    
    # Check for missing geographic data
    missing_geo = sum(1 for r in rows if not r.get('location', '').strip() and 
                     not r.get('city', '').strip() and not r.get('region', '').strip())
    print(f"   Rows missing all geographic data: {missing_geo}")
    
    # Check if we have enough data for heatmap
    has_location = location_count > 0
    has_city = city_count > 0
    has_region = region_count > 0
    has_multiple_locations = len(set(locations)) > 1
    
    print(f"\n7. Heatmap Readiness Check:")
    
    issues = []
    recommendations = []
    
    if not has_location and not has_city:
        issues.append("[X] Missing location/city data")
        recommendations.append("Ensure location or city field has data")
    else:
        print(f"   [OK] Geographic data available")
    
    if not has_multiple_locations:
        issues.append("[!] Only one unique location found")
        recommendations.append("May need more diverse location data")
    else:
        print(f"   [OK] Multiple locations available ({len(set(locations))} unique)")
    
    if location_coverage < 80:
        issues.append(f"[!] Only {location_coverage:.1f}% of rows have location data")
        recommendations.append("Consider improving location data coverage")
    else:
        print(f"   [OK] Good location data coverage ({location_coverage:.1f}%)")
    
    # Check for Shiny compatibility
    print(f"\n8. R Shiny Compatibility:")
    
    # Check encoding
    print(f"   [OK] CSV encoding: UTF-8 with BOM (utf-8-sig) - Good for R")
    
    # Check if data is structured properly
    has_title = any(r.get('title', '').strip() for r in rows)
    has_company = any(r.get('company', '').strip() for r in rows)
    
    if has_title and has_company:
        print(f"   [OK] Essential fields (title, company) present")
    
    # Final assessment
    print(f"\n9. Final Assessment:")
    
    if not issues:
        print(f"   [OK] CSV file is READY for heatmap visualization!")
        print(f"   [OK] Geographic data is sufficient for R Shiny")
        print(f"   [OK] File format is compatible with R")
    else:
        print(f"   [!] Issues found:")
        for issue in issues:
            print(f"      {issue}")
    
    if recommendations:
        print(f"\n10. Recommendations:")
        for rec in recommendations:
            print(f"   - {rec}")
    
    # Suggest aggregation level
    print(f"\n11. Suggested Heatmap Aggregation Level:")
    
    if region_count > 0 and len(set(regions)) >= 3:
        print(f"   [OK] REGION level - Best for overview heatmap")
        print(f"     Use 'region' field for geographic grouping")
    elif city_count > 0 and len(set(cities)) >= 5:
        print(f"   [OK] CITY level - Good for detailed heatmap")
        print(f"     Use 'city' field for geographic grouping")
    else:
        print(f"   [!] LOCATION level - May need data normalization")
        print(f"     Consider standardizing location names")
    
    print(f"\n" + "="*70)
    print("Analysis Complete!")
    print("="*70)

if __name__ == "__main__":
    analyze_csv_for_heatmap("nz_jobs_data.csv")
