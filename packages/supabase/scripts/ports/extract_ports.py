#!/usr/bin/env python3
"""Fetch marinas/harbours from OSM Overpass per country (Mediterranean + Europe).
Saves raw JSON per ISO code to osm/<ISO>.json. Idempotent (skips existing)."""
import json, os, sys, time, urllib.parse, urllib.request

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "osm")
os.makedirs(OUT, exist_ok=True)

MIRRORS = [
    "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
    "https://overpass-api.de/api/interpreter",
    "https://overpass.private.coffee/api/interpreter",
]

# Mediterranean (incl. N. Africa + Levant) + European coastal countries.
COUNTRIES = [
    "ES","FR","IT","MC","MT","SI","HR","BA","ME","AL","GR","TR","CY","GI",
    "PT","IE","GB","NL","BE","DE","DK","NO","SE","FI","EE","LV","LT","PL","IS",
    "RO","BG","UA","GE",
    "MA","DZ","TN","LY","EG","IL","LB","SY",
]

def query(iso):
    return (
        "[out:json][timeout:240];"
        f'area["ISO3166-1"="{iso}"][admin_level=2]->.a;'
        "("
        'nwr["leisure"="marina"](area.a);'
        'nwr["harbour"="yes"](area.a);'
        'nwr["seamark:type"~"^(harbour|marina|anchorage|mooring)$"](area.a);'
        ");"
        "out center tags;"
    )

def fetch(iso):
    data = urllib.parse.urlencode({"data": query(iso)}).encode()
    last = None
    for m in MIRRORS:
        try:
            req = urllib.request.Request(m, data=data,
                headers={"User-Agent": "navis-ports-seed/1.0"})
            with urllib.request.urlopen(req, timeout=260) as r:
                body = r.read().decode("utf-8", "replace")
            if body.lstrip().startswith("{"):
                j = json.loads(body)
                return j, m
            last = f"non-json from {m}: {body[:120]}"
        except Exception as e:
            last = f"{m}: {e}"
        time.sleep(3)
    raise RuntimeError(last)

def main():
    total = 0
    for iso in COUNTRIES:
        path = os.path.join(OUT, f"{iso}.json")
        if os.path.exists(path) and os.path.getsize(path) > 0:
            n = len(json.load(open(path)).get("elements", []))
            print(f"{iso}: cached {n}", flush=True); total += n; continue
        try:
            j, mirror = fetch(iso)
            els = j.get("elements", [])
            json.dump(j, open(path, "w"))
            print(f"{iso}: {len(els)} ({mirror.split('/')[2]})", flush=True)
            total += len(els)
        except Exception as e:
            print(f"{iso}: ERROR {e}", flush=True)
        time.sleep(2)
    print(f"TOTAL elements: {total}", flush=True)

if __name__ == "__main__":
    main()
