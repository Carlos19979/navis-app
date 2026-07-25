#!/usr/bin/env python3
"""Assemble 00040_seed_ports.sql from ports_seed_values.sql (batched INSERTs)."""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "ports_seed_values.sql")
# scripts/ports/ -> ../../migrations/
DST = os.path.normpath(
    os.path.join(HERE, "..", "..", "migrations", "00040_seed_ports.sql"))
COLS = "(name, location, country, port_type, depth_m, facilities, vhf_channel, website)"
BATCH = 1000

rows = [ln.rstrip(",\n") for ln in open(SRC) if ln.strip()]
n = len(rows)

parts = [
    "-- 00040_seed_ports.sql",
    "-- Reference dataset of marinas, harbours, anchorages and fishing/commercial",
    "-- ports across the Mediterranean and European coasts. Extracted from",
    "-- OpenStreetMap (ODbL) via Overpass, per-country, deduped and cleaned.",
    f"-- {n} rows. Public read (RLS ports_select_all). Regenerate: see scripts.",
    "",
    "-- Trigram index so name search (ILIKE '%q%') stays fast at this scale.",
    "CREATE EXTENSION IF NOT EXISTS pg_trgm;",
    "CREATE INDEX IF NOT EXISTS idx_ports_name_trgm",
    "  ON ports USING GIN (name gin_trgm_ops);",
    "",
]

for i in range(0, n, BATCH):
    chunk = rows[i:i + BATCH]
    parts.append(f"INSERT INTO ports {COLS} VALUES")
    parts.append(",\n".join(chunk) + ";")
    parts.append("")

open(DST, "w").write("\n".join(parts) + "\n")
print(f"wrote {DST}: {n} rows, {os.path.getsize(DST)//1024} KB, "
      f"{(n + BATCH - 1)//BATCH} batches")
