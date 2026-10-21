# reference_data

Real-world geographic data used to lay out the open world. Not shipped in the game build (`.gdignore`, excluded from export).

- `osm/*.json`: raw OpenStreetMap extracts fetched via the Overpass API on 2026-10-21.
  Data (c) OpenStreetMap contributors, licensed under the Open Database License (ODbL): https://www.openstreetmap.org/copyright
  Any in-game map derived from it must keep this attribution (credits screen + README).
- `osm/map_900m.png`: FPT University HCMC campus and surroundings, 0.5 m/px, north up, origin = campus centroid (10.8414168 N, 106.8100745 E).
- `osm/map_vinhomes_1600m.png`: Vinhomes Grand Park, same metric frame (BE6 is at about x=3911 m east, y=409 m north of the campus origin).
- `osm/route_be6_fptu.json` + `map_overview_route.png`: shortest drivable route tower BE6 -> FPTU main gate on Đường D1.
- `osm/nominatim_fpt.json`: geocoding result for the campus.

Frame used everywhere: x = metres east, y = metres north of the campus centroid (equirectangular, cos(lat) corrected).
Google Maps was only viewed for visual cross-checking; nothing from it is copied into the project.
