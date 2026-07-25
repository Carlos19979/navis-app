# Ports reference dataset

`migrations/00040_seed_ports.sql` seeds ~13.8k marinas, harbours, anchorages
and fishing/commercial ports across the Mediterranean and European coasts. The
map (`features/ports`) and the boat port pickers read from this table.

## Provenance & licence

Data is extracted from **OpenStreetMap**, © OpenStreetMap contributors,
available under the **Open Database License (ODbL)**. Attribution is required
wherever the data is displayed (the map credits OpenStreetMap via the tile
attribution). Source features: `leisure=marina`, `harbour=yes`, and
`seamark:type` in (`harbour`, `marina`, `anchorage`) — individual `mooring`
points are excluded as too granular.

## Regenerate / update the dataset

Run from this directory (needs Python 3, network access to an Overpass mirror):

```bash
python3 extract_ports.py      # per-country Overpass queries -> osm/<ISO>.json (cached)
python3 process_ports.py      # map tags -> rows, dedupe, bbox-filter -> ports_seed_values.sql
python3 assemble_migration.py # batch into ../../migrations/00040_seed_ports.sql
```

- `extract_ports.py` queries one country at a time (`area["ISO3166-1"=...]`) with
  mirror fallback; re-running skips countries already cached under `osm/`.
- `process_ports.py` maps OSM tags to the `ports` schema
  (`port_type` marina/anchorage/fishing/commercial/other), requires a name,
  dedupes by name + rounded coordinates, and keeps only the Europe+Med bounding
  region (excludes overseas territories and inland outliers).
- `assemble_migration.py` writes batched `INSERT`s plus a `pg_trgm` GIN index on
  `name` so `ILIKE` port search stays fast at this scale.

Raw `osm/` JSON and the intermediate `ports_seed_values.sql` are build artifacts
and are not committed.
