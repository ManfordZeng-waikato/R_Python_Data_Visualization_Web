"""
Add latitude/longitude coordinates to NZ job locations.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Dict, Optional

import pandas as pd
from geopy.extra.rate_limiter import RateLimiter
from geopy.geocoders import Nominatim


DEFAULT_INPUT = "nz_jobs_data.csv"
DEFAULT_OUTPUT = "nz_jobs_data_with_coords.csv"
DEFAULT_CACHE = "geocode_cache.json"


MANUAL_LOCATION_MAP = {
    "Auckland CBD": "Auckland",
    "Wellington Central": "Wellington",
    "Christchurch Central": "Christchurch",
    "Palmerston North Central": "Palmerston North",
    "Taupo Central": "Taupo",
    "Mount Eden": "Auckland",
    "North Dunedin": "Dunedin",
}


def normalize_location(raw_value: str) -> str:
    value = raw_value.strip()
    if value in MANUAL_LOCATION_MAP:
        return MANUAL_LOCATION_MAP[value]

    lower_value = value.lower()
    if "auckland" in lower_value:
        return "Auckland"
    if "wellington" in lower_value:
        return "Wellington"
    if "christchurch" in lower_value:
        return "Christchurch"
    if "dunedin" in lower_value:
        return "Dunedin"

    return value


def pick_location(row: pd.Series) -> Optional[str]:
    for col in ("location", "city", "region"):
        raw = row.get(col)
        if isinstance(raw, str) and raw.strip():
            return raw.strip()
    return None


def load_cache(cache_path: Path) -> Dict[str, Dict[str, float]]:
    if not cache_path.exists():
        return {}
    with cache_path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def save_cache(cache_path: Path, cache: Dict[str, Dict[str, float]]) -> None:
    with cache_path.open("w", encoding="utf-8") as handle:
        json.dump(cache, handle, ensure_ascii=True, indent=2)


def geocode_location(
    geocode_fn,
    location: str,
    cache: Dict[str, Dict[str, float]],
) -> Dict[str, Optional[float]]:
    if location in cache:
        cached = cache[location]
        return {"latitude": cached["latitude"], "longitude": cached["longitude"]}

    queries = [
        f"{location}, New Zealand",
        f"{location} New Zealand",
    ]

    result = None
    for query in queries:
        result = geocode_fn(query)
        if result is not None:
            break

    if result is None:
        cache[location] = {"latitude": None, "longitude": None}
        return {"latitude": None, "longitude": None}

    cache[location] = {"latitude": result.latitude, "longitude": result.longitude}
    return {"latitude": result.latitude, "longitude": result.longitude}


def add_coordinates(
    input_path: Path,
    output_path: Path,
    cache_path: Path,
    min_delay_seconds: float,
) -> None:
    df = pd.read_csv(input_path, encoding="utf-8-sig")
    df["raw_location"] = df.apply(pick_location, axis=1)
    df["normalized_location"] = df["raw_location"].fillna("").apply(normalize_location)

    unique_locations = sorted(
        set(loc for loc in df["normalized_location"].unique() if loc)
    )

    cache = load_cache(cache_path)
    geolocator = Nominatim(user_agent="nz_it_jobs_heatmap")
    geocode_fn = RateLimiter(
        geolocator.geocode,
        min_delay_seconds=min_delay_seconds,
        max_retries=2,
        error_wait_seconds=min_delay_seconds,
        return_value_on_exception=None,
    )

    coords_lookup: Dict[str, Dict[str, Optional[float]]] = {}
    for location in unique_locations:
        coords_lookup[location] = geocode_location(geocode_fn, location, cache)

    df["latitude"] = df["normalized_location"].map(
        lambda loc: coords_lookup.get(loc, {}).get("latitude")
    )
    df["longitude"] = df["normalized_location"].map(
        lambda loc: coords_lookup.get(loc, {}).get("longitude")
    )

    save_cache(cache_path, cache)
    df.to_csv(output_path, index=False, encoding="utf-8-sig")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Add coordinates to NZ job data CSV.")
    parser.add_argument("--input", default=DEFAULT_INPUT, help="Input CSV path.")
    parser.add_argument("--output", default=DEFAULT_OUTPUT, help="Output CSV path.")
    parser.add_argument("--cache", default=DEFAULT_CACHE, help="Cache JSON path.")
    parser.add_argument(
        "--min-delay",
        type=float,
        default=1.0,
        help="Minimum delay between geocoding requests (seconds).",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    add_coordinates(
        input_path=Path(args.input),
        output_path=Path(args.output),
        cache_path=Path(args.cache),
        min_delay_seconds=args.min_delay,
    )


if __name__ == "__main__":
    main()
