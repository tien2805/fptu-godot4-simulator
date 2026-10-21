# -*- coding: utf-8 -*-
"""Derive assets/data/mapdata.json (the only geographic file that ships) from the raw OpenStreetMap extracts
in reference_data/osm/.  Pure Python (json + math), no third-party packages.

Frame: Godot world units = metres. x = east, z = -north (so north is -Z, Godot forward), y up.
Origin (0,0) = FPT University HCMC campus centroid (10.8414168 N, 106.8100745 E).

Scope (first open-world build, decided by the owner 2026-10-21):
  * campus region      : everything within CAMPUS_R metres of the origin
  * Vinhomes region    : everything within VIN_R metres of tower BE6 (The Beverly, Vincom, VinBus, golf, parks)
  * corridor           : everything within CORR_R metres of the real BE6 -> FPTU route (roads + low-detail blocks)

Run:  python tools/osm_to_mapdata.py
Data (c) OpenStreetMap contributors, ODbL 1.0 - https://www.openstreetmap.org/copyright
"""
import io, json, math, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "reference_data", "osm")
OUT = os.path.join(ROOT, "assets", "data", "mapdata.json")
LAT0, LON0 = 10.8414168, 106.8100745
KX = 111320.0 * math.cos(math.radians(LAT0))
KY = 110574.0
CAMPUS_R = 700.0
VIN_R = 900.0
CORR_R = 150.0
BE6_WAY = 1308943355
CAMPUS_PLOT_WAY = 1022939891
CAMPUS_RING_REL = 13698121
HUTECH_PLOT_WAY = 1271061070
HUTECH_BLD_WAY = 605379728

ROAD_CLASS = {  # width in metres of ONE carriageway (oneway ways are one carriageway each), lanes default
    "motorway": (11.0, 3), "trunk": (11.0, 3), "primary": (10.5, 3), "secondary": (8.0, 2), "tertiary": (7.0, 2),
    "residential": (6.0, 2), "unclassified": (6.0, 2), "living_street": (5.0, 1), "service": (4.0, 1),
    "motorway_link": (6.0, 1), "trunk_link": (6.0, 1), "primary_link": (6.0, 1), "secondary_link": (6.0, 1), "tertiary_link": (6.0, 1),
    "pedestrian": (4.0, 0), "footway": (2.0, 0), "path": (1.5, 0), "cycleway": (2.5, 0), "steps": (2.0, 0),
}
# brand names shown in game are fictionalised (trademark safety); streets, areas, universities, towers keep their public names
DISPLAY_NAME = {
    "Vincom Mega Mall": "VinMall Grand Park", "Highlands Coffee": "Lowlands Coffee", "Gong Cha": "Gong Trà", "Pharmacity": "Pharmacitea",
    "Nhà thuốc Long Châu": "Nhà thuốc Long Chầu", "Techcombank": "TechcomBank", "ACB Lite - Vinhomes Grand Park": "ACB Nhẹ",
    "Nam A Bank": "Nam Á Bank", "Viettel Post": "Việt Tèo Post", "VinMart": "VinMắt", "Bách Hóa XANH": "Bách Hoá XANH LÈ",
    "Napoli Coffee": "Napoly Coffee", "Decathlon": "Decathlón", "Passio Coffee FPT": "Passion Coffee", "7-Eleven": "7-Elevenn",
}


def xy(p):
    """lat/lon dict -> (x east, z south) metres"""
    return ((p["lon"] - LON0) * KX, -(p["lat"] - LAT0) * KY)


def load(name):
    with io.open(os.path.join(SRC, name), encoding="utf-8") as f:
        return json.load(f)["elements"]


def rings_of(e):
    if e["type"] == "way" and e.get("geometry"):
        return [[xy(p) for p in e["geometry"]]]
    if e["type"] == "relation":
        outer, inner = [], []
        for m in e.get("members", []):
            if not m.get("geometry"):
                continue
            (inner if m.get("role") == "inner" else outer).append([xy(p) for p in m["geometry"]])
        return outer + inner
    return []


def centroid(pts):
    return (sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts))


def area(pts):
    a = 0.0
    for i in range(len(pts) - 1):
        a += pts[i][0] * pts[i + 1][1] - pts[i + 1][0] * pts[i][1]
    return abs(a) / 2.0


def simplify(pts, eps=0.5):
    """Douglas-Peucker"""
    if len(pts) < 3:
        return pts

    def dist(p, a, b):
        ax, ay = a; bx, by = b; px, py = p
        dx, dy = bx - ax, by - ay
        L2 = dx * dx + dy * dy
        if L2 < 1e-9:
            return math.hypot(px - ax, py - ay)
        t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / L2))
        return math.hypot(px - (ax + t * dx), py - (ay + t * dy))

    dmax, idx = 0.0, 0
    for i in range(1, len(pts) - 1):
        d = dist(pts[i], pts[0], pts[-1])
        if d > dmax:
            dmax, idx = d, i
    if dmax > eps:
        return simplify(pts[:idx + 1], eps)[:-1] + simplify(pts[idx:], eps)
    return [pts[0], pts[-1]]


def seg_dist(p, a, b):
    ax, ay = a; bx, by = b; px, py = p
    dx, dy = bx - ax, by - ay
    L2 = dx * dx + dy * dy
    if L2 < 1e-9:
        return math.hypot(px - ax, py - ay)
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / L2))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


def r2(v):
    return round(v, 2)


def main():
    els = {}
    for fn in ["fpt_campus_900m.json", "vinhomes_gp_1600m.json", "roads_bbox_fpt_vinhomes.json"]:
        for e in load(fn):
            els[(e["type"], e["id"])] = e
    route_raw = json.load(io.open(os.path.join(SRC, "route_be6_fptu.json"), encoding="utf-8"))
    route = [(x, -y) for x, y in route_raw["points"]]  # stored as (east, north) -> (x, z)
    be6 = els[("way", BE6_WAY)]
    be6_ring = rings_of(be6)[0]
    be6_c = centroid(be6_ring)

    def in_scope(pts):
        c = centroid(pts) if len(pts) > 1 else pts[0]
        if math.hypot(c[0], c[1]) <= CAMPUS_R:
            return "campus"
        if math.hypot(c[0] - be6_c[0], c[1] - be6_c[1]) <= VIN_R:
            return "vinhomes"
        # corridor: any vertex near the route
        step = max(1, len(pts) // 40)
        for p in pts[::step]:
            for i in range(len(route) - 1):
                if seg_dist(p, route[i], route[i + 1]) <= CORR_R:
                    return "corridor"
        return None

    roads, buildings, water, areas, pois = [], [], [], [], []
    for e in els.values():
        t = e.get("tags", {})
        if e["type"] == "node":
            if ("amenity" in t or "shop" in t or t.get("highway") == "bus_stop" or t.get("tourism")) and "name" in t:
                p = xy(e)
                reg = in_scope([p])
                if reg:
                    pois.append({"name": t["name"], "display": DISPLAY_NAME.get(t["name"], t["name"]), "kind": t.get("amenity") or t.get("shop") or t.get("highway") or t.get("tourism"), "x": r2(p[0]), "z": r2(p[1]), "region": reg})
            continue
        rings = rings_of(e)
        if not rings:
            continue
        if "highway" in t and e["type"] == "way":
            h = t["highway"]
            if h not in ROAD_CLASS:
                continue
            pts = rings[0]
            reg = in_scope(pts)
            if not reg:
                continue
            if reg == "corridor" and ROAD_CLASS[h][1] == 0:
                continue  # no footpaths in the corridor
            w, lanes = ROAD_CLASS[h]
            try:
                lanes = int(t.get("lanes", lanes))
            except ValueError:
                pass
            roads.append({"id": e["id"], "name": t.get("name", ""), "class": h, "width": w if h not in ("primary", "secondary", "trunk") else max(w, 3.5 * lanes), "lanes": lanes,
                          "oneway": t.get("oneway") in ("yes", "1", "true") or t.get("junction") == "roundabout", "roundabout": t.get("junction") == "roundabout",
                          "bridge": t.get("bridge") == "yes", "region": reg, "points": [[r2(x), r2(z)] for x, z in simplify(pts, 0.4)]})
        elif "building" in t:
            outer = rings[0]
            reg = in_scope(outer)
            if not reg:
                continue
            a = area(outer)
            lv = t.get("building:levels")
            try:
                lv = int(float(lv)) if lv else None
            except ValueError:
                lv = None
            name = t.get("name", "")
            kind = t["building"]
            if lv is None:
                if name.upper().startswith("TÒA BE"):
                    lv = 30
                elif kind == "apartments":
                    lv = 25
                elif a > 3000:
                    lv = 3
                elif a > 600:
                    lv = 2
                else:
                    lv = 2 if reg != "corridor" else 2
            style = "tower" if kind == "apartments" or lv >= 10 else ("mall" if a > 5000 else ("industrial" if kind in ("industrial", "warehouse") or (a > 1500 and lv <= 3) else "shophouse"))
            if name.upper().startswith("TÒA BE") or name.startswith("BS") or name.startswith("GH") or name.startswith("Tòa OS"):
                style = "beverly"
            buildings.append({"id": e["id"], "name": name, "display": DISPLAY_NAME.get(name, name), "kind": kind, "levels": lv, "height": r2(lv * (3.2 if style in ("tower", "beverly") else 3.6)),
                              "style": style, "region": reg, "area": r2(a), "outer": [[r2(x), r2(z)] for x, z in simplify(outer, 0.3)],
                              "inner": [[[r2(x), r2(z)] for x, z in simplify(r, 0.3)] for r in rings[1:]]})
        elif t.get("natural") == "water" or t.get("water") or t.get("waterway") in ("river", "stream", "canal", "riverbank"):
            pts = rings[0]
            reg = in_scope(pts)
            if not reg:
                continue
            if t.get("waterway") in ("stream", "canal", "river") and (len(pts) < 3 or pts[0] != pts[-1]):
                water.append({"id": e["id"], "name": t.get("name", ""), "kind": "line", "width": 6.0 if t.get("waterway") != "river" else 25.0, "region": reg, "points": [[r2(x), r2(z)] for x, z in simplify(pts, 0.5)]})
            else:
                water.append({"id": e["id"], "name": t.get("name", ""), "kind": "area", "region": reg, "outer": [[r2(x), r2(z)] for x, z in simplify(pts, 0.5)]})
        elif t.get("leisure") or t.get("landuse") or t.get("amenity"):
            pts = rings[0]
            if len(pts) < 4:
                continue
            reg = in_scope(pts)
            if not reg:
                continue
            k = t.get("leisure") or t.get("landuse") or t.get("amenity")
            cat = "park" if k in ("park", "garden", "grass", "recreation_ground", "meadow", "village_green") else ("pitch" if k in ("pitch", "playground", "sports_centre", "golf_course") else ("parking" if k in ("parking", "motorcycle_parking") else ("water_park" if k == "water_park" else ("pool" if k == "swimming_pool" else ("campus" if k in ("university", "college", "school", "kindergarten") else "other")))))
            areas.append({"id": e["id"], "name": t.get("name", ""), "display": DISPLAY_NAME.get(t.get("name", ""), t.get("name", "")), "kind": cat, "tag": k, "region": reg, "area": r2(area(pts)), "outer": [[r2(x), r2(z)] for x, z in simplify(pts, 0.5)]})

    # landmarks used by the builders
    plot = rings_of(els[("way", CAMPUS_PLOT_WAY)])[0]
    ring = rings_of(els[("relation", CAMPUS_RING_REL)])
    hutech_plot = rings_of(els[("way", HUTECH_PLOT_WAY)])[0]
    hutech_bld = rings_of(els[("way", HUTECH_BLD_WAY)])[0]
    # BE6 lobby door: midpoint of the longest edge that faces the internal road (south-west side, towards the canal is north)
    best = None
    for i in range(len(be6_ring) - 1):
        a, b = be6_ring[i], be6_ring[i + 1]
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        if best is None or L > best[0]:
            best = (L, mid, (b[0] - a[0], b[1] - a[1]))
    _, door_mid, edge = best
    # outward normal: away from centroid
    nx, nz = -edge[1], edge[0]
    if (door_mid[0] - be6_c[0]) * nx + (door_mid[1] - be6_c[1]) * nz < 0:
        nx, nz = -nx, -nz
    nl = math.hypot(nx, nz)
    nx, nz = nx / nl, nz / nl
    spawn = {"x": r2(door_mid[0] + nx * 6.0), "z": r2(door_mid[1] + nz * 6.0), "yaw_deg": r2(math.degrees(math.atan2(-nx, -nz))), "note": "6 m outside the BE6 lobby door, facing away from the tower"}

    out = {
        "attribution": "Map data (c) OpenStreetMap contributors, ODbL 1.0 (https://www.openstreetmap.org/copyright). Derived 2026-10-21.",
        "frame": {"origin_lat": LAT0, "origin_lon": LON0, "x": "metres east", "z": "metres south (Godot -Z = north)", "y": "up"},
        "scope": {"campus_radius": CAMPUS_R, "vinhomes_radius": VIN_R, "vinhomes_center": [r2(be6_c[0]), r2(be6_c[1])], "corridor_radius": CORR_R},
        "landmarks": {
            "campus_plot": [[r2(x), r2(z)] for x, z in plot],
            "campus_ring_outer": [[r2(x), r2(z)] for x, z in ring[0]],
            "campus_ring_inner": [[r2(x), r2(z)] for x, z in ring[1]] if len(ring) > 1 else [],
            "campus_main_gate": [16.1, 99.5], "campus_west_gate": [-109.0, -21.5],
            "campus_parking_center": [-5.7, -62.3], "campus_pitch_center": [64.2, 3.5],
            "hutech_plot": [[r2(x), r2(z)] for x, z in hutech_plot], "hutech_building": [[r2(x), r2(z)] for x, z in hutech_bld],
            "be6_outer": [[r2(x), r2(z)] for x, z in be6_ring], "be6_center": [r2(be6_c[0]), r2(be6_c[1])],
            "spawn": spawn,
            "d1_roundabout": [81.5, 214.9], "bus_stop_fpt": [-131.9, -29.4], "bus_stop_hutech": [-149.8, 0.1],
        },
        "route_be6_to_fptu": {"length_m": r2(route_raw["length_m"]), "roads": route_raw["roads"], "points": [[r2(x), r2(z)] for x, z in simplify(route, 0.5)]},
        "roads": roads, "buildings": buildings, "water": water, "areas": areas, "pois": pois,
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with io.open(OUT, "w", encoding="utf-8", newline="\n") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
    from collections import Counter
    print("mapdata.json written: %.1f MB" % (os.path.getsize(OUT) / 1e6))
    print("roads", len(roads), Counter(r["region"] for r in roads), Counter(r["class"] for r in roads).most_common(8))
    print("buildings", len(buildings), Counter(b["region"] for b in buildings), Counter(b["style"] for b in buildings))
    print("water", len(water), "areas", len(areas), Counter(a["kind"] for a in areas), "pois", len(pois))
    print("spawn", spawn)


if __name__ == "__main__":
    main()
