import csv
import re


CSV_PATH = r"d:\Projects\R+Python\R_Python_Data_Visualization_Web\nz_jobs_data_with_coords.csv"


MANUAL = {
    "Auckland CBD": "Auckland",
    "Grey Lynn": "Auckland",
    "Albany": "Auckland",
    "Mount Eden": "Auckland",
    "Mount Wellington": "Auckland",
    "Wellington Central": "Wellington",
    "Petone": "Wellington",
    "Lower Hutt": "Wellington",
    "Christchurch Central": "Christchurch",
    "Addington": "Christchurch",
    "Palmerston North Central": "Palmerston North",
    "North Dunedin": "Dunedin",
    "Taupo Central": "Taupo",
    "Hamilton Lake": "Hamilton",
    "Te Rapa": "Hamilton",
}

PAT_AKL = re.compile(
    r"grey lynn|ponsonby|takapuna|newmarket|remuera|epsom|parnell|grafton|ellerslie|penrose|onehunga|avondale|mt albert|mount albert|new lynn|henderson|glenfield|rosedale|manukau|papatoetoe|howick|east tamaki|mount roskill|mt roskill|devonport|browns bay|mount wellington|mt wellington",
    re.I,
)
PAT_WLG = re.compile(
    r"lower hutt|upper hutt|petone|porirua|johnsonville|thorndon|te aro|newtown|kilbirnie|miramar",
    re.I,
)
PAT_HAM = re.compile(
    r"hamilton lake|hamilton east|te rapa|chartwell|rototuna|frankton|claudelands|hillcrest|dinsdale",
    re.I,
)
PAT_CHC = re.compile(
    r"addington|riccarton|hornby|sydenham|ilam|fendalton|papanui|linwood|wigram|halswell",
    re.I,
)


def normalize_city(v: str | None) -> str | None:
    if v is None:
        return None
    v = str(v).strip()
    if not v:
        return None
    if v in MANUAL:
        return MANUAL[v]
    if PAT_AKL.search(v):
        return "Auckland"
    if PAT_WLG.search(v):
        return "Wellington"
    if PAT_HAM.search(v):
        return "Hamilton"
    if PAT_CHC.search(v):
        return "Christchurch"

    lv = v.lower()
    if "auckland" in lv:
        return "Auckland"
    if "wellington" in lv:
        return "Wellington"
    if "christchurch" in lv:
        return "Christchurch"
    if "hamilton" in lv:
        return "Hamilton"
    if "dunedin" in lv:
        return "Dunedin"
    if "taupo" in lv:
        return "Taupo"
    if "nelson" in lv:
        return "Nelson"
    if "napier" in lv:
        return "Napier"
    return v


def main() -> None:
    counts: dict[str | None, int] = {}
    raw_vals: set[str] = set()
    coords: dict[str | None, dict[str, float]] = {}
    coords_n: dict[str | None, int] = {}

    with open(CSV_PATH, "r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            raw = (row.get("raw_location") or "").strip()
            raw_vals.add(raw)
            city = normalize_city(raw)
            counts[city] = counts.get(city, 0) + 1

            lat_s = (row.get("latitude") or "").strip()
            lon_s = (row.get("longitude") or "").strip()
            if lat_s and lon_s:
                try:
                    lat = float(lat_s)
                    lon = float(lon_s)
                except ValueError:
                    continue
                acc = coords.setdefault(city, {"lat_sum": 0.0, "lon_sum": 0.0})
                acc["lat_sum"] += lat
                acc["lon_sum"] += lon
                coords_n[city] = coords_n.get(city, 0) + 1

    raw_vals = {v for v in raw_vals if v}
    print("distinct raw_location:", len(raw_vals))
    print("distinct agg_city:", len(counts))
    for k, v in sorted(counts.items(), key=lambda kv: kv[1], reverse=True)[:50]:
        print(f"{k}: {v}")

    print("\nMean coords per agg_city (where available):")
    for k, v in sorted(coords_n.items(), key=lambda kv: kv[1], reverse=True):
        if k is None:
            continue
        n = v
        lat = coords[k]["lat_sum"] / n
        lon = coords[k]["lon_sum"] / n
        print(f"{k}: n={n} lat={lat:.5f} lon={lon:.5f}")


if __name__ == "__main__":
    main()

