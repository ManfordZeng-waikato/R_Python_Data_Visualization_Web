"""
Normalize city names in existing CSV file
Removes suffixes like CBD, Central, etc. from city/location/region fields
"""
import csv
import sys
from pathlib import Path
from typing import Optional


def normalize_city_name(city_name: str) -> str:
    """
    Normalize city name by removing common suffixes like CBD, Central, etc.
    
    Args:
        city_name: Raw city name from CSV data
    
    Returns:
        Normalized city name
    """
    if not city_name:
        return ""
    
    # Common suffixes to remove (case insensitive)
    suffixes_to_remove = [
        " cbd",
        " CBD",
        " central",
        " Central",
        " CENTRAL",
        " north",
        " North",
        " NORTH",
        " south",
        " South",
        " SOUTH",
        " east",
        " East",
        " EAST",
        " west",
        " West",
        " WEST"
    ]
    
    normalized = city_name.strip()
    
    # Remove suffixes
    for suffix in suffixes_to_remove:
        if normalized.endswith(suffix):
            normalized = normalized[:-len(suffix)].strip()
    
    return normalized


def normalize_csv_cities(input_csv: str, output_csv: Optional[str] = None, backup: bool = True):
    """
    Normalize city names in CSV file
    
    Args:
        input_csv: Input CSV file path
        output_csv: Output CSV file path (if None, overwrites input file)
        backup: Whether to create backup of original file
    """
    input_path = Path(input_csv)
    
    if not input_path.exists():
        print(f"Error: Input file not found: {input_csv}")
        return False
    
    # Generate output path
    if output_csv is None:
        output_path = input_path
        # Create backup if requested
        if backup:
            backup_path = input_path.parent / f"{input_path.stem}_backup{input_path.suffix}"
            print(f"Creating backup: {backup_path}")
            import shutil
            shutil.copy2(input_path, backup_path)
            print(f"Backup created successfully")
    else:
        output_path = Path(output_csv)
    
    # Read CSV
    print(f"Reading CSV file: {input_path}")
    with open(input_path, 'r', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames
        rows = list(reader)
    
    print(f"Found {len(rows)} rows")
    
    # Normalize geographic fields
    geo_fields = ['location', 'city', 'region']
    normalized_count = 0
    
    for row in rows:
        for field in geo_fields:
            if field in row and row[field]:
                original = row[field]
                normalized = normalize_city_name(original)
                if original != normalized:
                    row[field] = normalized
                    normalized_count += 1
    
    # Write normalized CSV
    print(f"Normalizing {normalized_count} geographic fields...")
    print(f"Writing to: {output_path}")
    
    with open(output_path, 'w', newline='', encoding='utf-8-sig') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    
    print(f"Successfully normalized CSV file!")
    print(f"Total changes: {normalized_count}")
    
    # Show statistics
    print(f"\nNormalization Statistics:")
    for field in geo_fields:
        if field in fieldnames:
            unique_before = set()
            unique_after = set()
            
            # Read original to compare (if backup exists)
            if backup and backup_path.exists():
                with open(backup_path, 'r', encoding='utf-8-sig') as bf:
                    b_reader = csv.DictReader(bf)
                    for r in b_reader:
                        if r.get(field):
                            unique_before.add(r[field])
            
            # Count unique after
            for row in rows:
                if row.get(field):
                    unique_after.add(row[field])
            
            print(f"  {field}:")
            print(f"    Unique values before: {len(unique_before)}" if unique_before else "    Unique values after: {len(unique_after)}")
            print(f"    Unique values after: {len(unique_after)}")
    
    return True


def main():
    """Main function"""
    import argparse
    
    parser = argparse.ArgumentParser(
        description='Normalize city names in CSV file (remove CBD, Central, etc.)'
    )
    parser.add_argument(
        'input_csv',
        type=str,
        help='Input CSV file path'
    )
    parser.add_argument(
        '-o', '--output',
        type=str,
        default=None,
        help='Output CSV file path (default: overwrites input file)'
    )
    parser.add_argument(
        '--no-backup',
        action='store_true',
        help='Do not create backup of original file'
    )
    
    args = parser.parse_args()
    
    print("="*70)
    print("CSV City Name Normalization Tool")
    print("="*70)
    print()
    
    success = normalize_csv_cities(
        input_csv=args.input_csv,
        output_csv=args.output,
        backup=not args.no_backup
    )
    
    if success:
        print("\n" + "="*70)
        print("Normalization complete!")
        print("="*70)
        sys.exit(0)
    else:
        print("\nNormalization failed!")
        sys.exit(1)


if __name__ == "__main__":
    main()
