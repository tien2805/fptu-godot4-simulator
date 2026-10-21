# reference_data

Real-world geographic data used to lay out the open world. Not shipped in the game build (`.gdignore`, excluded from export).

- `osm/*.json`: raw OpenStreetMap extracts fetched via the Overpass API on 2026-10-21.
  Data (c) OpenStreetMap contributors, licensed under the Open Database License (ODbL): https://www.openstreetmap.org/copyright
  Any in-game map derived from it must keep this attribution (credits screen + README).
- `osm/map_900m.png`: FPT University HCMC campus and surroundings, 0.5 m/px, north up, origin = campus centroid (10.8414168 N, 106.8100745 E).
- `osm/map_vinhomes_1600m.png`: Vinhomes Grand Park, same metric frame (BE6 is at about x=3911 m east, y=409 m north of the campus origin).
- `osm/route_be6_fptu.json` + `map_overview_route.png`: shortest drivable route tower BE6 -> FPTU main gate on Đường D1.
- `osm/nominatim_fpt.json`: geocoding result for the campus.

- `msbuildings/vn_132230111.csv.gz` (NOT committed, git-ignored, 194.5 MB): Microsoft Global ML Building Footprints, release 2026-08-13, Vietnam, quadkey 132230111 (zoom-9 tile covering HCMC), downloaded 2026-10-22 with the owner's permission from
  https://bfppub.z5.web.core.windows.net/2026-08-13/global-buildings.geojsonl/RegionName=Vietnam/quadkey=132230111/part-00184-110f5303-ff85-4c71-a2bf-c6070024fec8.c000.csv.gz
  (manifest: https://bfppub.blob.core.windows.net/%24web/2026-08-13/dataset-links.csv). Licence: CDLA-Permissive-2.0, https://cdla.dev/permissive-2-0/ (the licence text must accompany redistributed data; README and credits link it).
- `msbuildings/scope_extract.json` (committed, 0.6 MB): the 3084 footprints of that tile inside the game scope (campus disc 700 m, Vinhomes disc 900 m around BE6, route corridor 150 m), projected to the frame below. Produced by a stream filter (gzip GeoJSONL, coarse lon/lat box, exact region test). No height estimates exist for this area in the release (all -1).
- `tools/osm_to_mapdata.py` merges the extract into `assets/data/mapdata.json` (buildings with `"source": "msft"`): footprints are dropped when smaller than 25 m2, duplicating an OSM building, inside the Vinhomes Grand Park compound (imagery predates the towers), inside the FPT or HUTECH plots (drawn by FPTUCampusBuilder), on a carriageway or in water; storeys are derived from the footprint area (tube houses 2-4, warehouses 1-2). Run with `--no-ms` to build OSM-only data.

Frame used everywhere: x = metres east, y = metres north of the campus centroid (equirectangular, cos(lat) corrected).
Google Maps was only viewed for visual cross-checking; nothing from it is copied into the project.
