#!/usr/bin/env python3
"""Process OSM JSON (osm/*.json) into a ports seed migration.
Maps OSM tags -> ports schema, dedupes, emits SQL VALUES."""
import glob, json, os, re
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
OSM = os.path.join(HERE, "osm")

def coord(el):
    if el.get("type") == "node":
        return el.get("lat"), el.get("lon")
    c = el.get("center") or {}
    return c.get("lat"), c.get("lon")

def name_of(t):
    for k in ("name", "name:en", "int_name", "official_name"):
        v = t.get(k)
        if v and v.strip():
            return v.strip()
    return None

def port_type(t):
    if t.get("leisure") == "marina" or t.get("seamark:type") == "marina":
        return "marina"
    st = t.get("seamark:type", "")
    # Individual mooring points are too granular (canal moorings, buoys) -> skip
    # unless the feature is also a harbour.
    if st == "mooring" and t.get("harbour") != "yes":
        return None
    if st == "anchorage":
        return "anchorage"
    cat = (t.get("seamark:harbour:category") or t.get("harbour:category") or "").lower()
    if "fishing" in cat:
        return "fishing"
    if any(x in cat for x in ("commercial", "industrial", "cargo", "port", "ferry", "naval")):
        return "commercial"
    # harbour=yes / seamark harbour without category
    if t.get("harbour") == "yes" or st == "harbour":
        return "other"
    return "other"

def website(t):
    for k in ("website", "contact:website", "url", "seamark:harbour:website"):
        v = t.get(k)
        if v and v.startswith("http") and len(v) <= 300:
            return v
    return None

def vhf(t):
    for k in ("seamark:radio_station:channel", "vhf", "seamark:harbour:vhf"):
        v = t.get(k)
        if v and re.fullmatch(r"[0-9A-Za-z/ .-]{1,10}", v):
            return v.strip()
    return None

def esc(s):
    return s.replace("'", "''")

def main():
    rows = {}
    seen = set()
    tcount = Counter()
    ccount = Counter()
    for path in sorted(glob.glob(os.path.join(OSM, "*.json"))):
        iso = os.path.basename(path)[:-5]
        j = json.load(open(path))
        for el in j.get("elements", []):
            t = el.get("tags") or {}
            lat, lon = coord(el)
            if lat is None or lon is None:
                continue
            # Europe + Mediterranean bounding region. Excludes overseas
            # territories (New Caledonia, Guadeloupe, Reunion, Polynesia,
            # St-Pierre) pulled in by country-area queries, and inland outliers
            # (Lake Nasser). Keeps Canaries, Azores, Madeira, Iceland, Black Sea.
            if not (-32.0 <= lon <= 45.0 and 24.0 <= lat <= 72.0):
                continue
            nm = name_of(t)
            if not nm or len(nm) > 120:
                continue
            key = (nm.lower(), round(lat, 3), round(lon, 3))
            if key in seen:
                continue
            pt = port_type(t)
            if pt is None:
                continue
            seen.add(key)
            rows[(iso, nm, round(lon, 6), round(lat, 6))] = (
                iso, nm, lon, lat, pt, website(t), vhf(t))
            tcount[pt] += 1
            ccount[iso] += 1

    vals = []
    for (iso, nm, lon, lat, pt, web, ch) in sorted(rows.values(), key=lambda r: (r[0], r[1])):
        web_s = f"'{esc(web)}'" if web else "NULL"
        ch_s = f"'{esc(ch)}'" if ch else "NULL"
        vals.append(
            f"  ('{esc(nm)}', ST_MakePoint({lon:.6f}, {lat:.6f})::geography, "
            f"'{iso}', '{pt}', NULL, NULL, {ch_s}, {web_s})")

    out = os.path.join(HERE, "ports_seed_values.sql")
    with open(out, "w") as f:
        f.write(",\n".join(vals))
    print("TOTAL rows:", len(vals))
    print("by type:", dict(tcount))
    print("countries:", len(ccount), "top:", ccount.most_common(10))
    print("wrote", out, f"({os.path.getsize(out)//1024} KB)")

if __name__ == "__main__":
    main()
