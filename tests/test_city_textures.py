# -*- coding: utf-8 -*-
"""Checks the code-drawn city textures written by generate_city_textures.py (plan Task 2):
existence + .import "keep" stub, 512 px width, the documented tile sizes, RGBA road overlay,
normal maps mostly facing +Z, seamless tiling along x (and along y where one tile = one storey), and that the
shophouse tile (2 storeys: shopfront + windows) matches the storey height of every shophouse in mapdata.json.
Run from the project root:  python tests/test_city_textures.py   (exit code 0 = OK)
"""
import json
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEX = os.path.join(ROOT, "assets", "textures")

# name -> (width, height, mode, must tile along y)
SPEC = {
    "city_tower_facade.png": (512, 546, "RGB", True),
    "city_tower_facade_n.png": (512, 546, "RGB", True),
    "city_beverly_facade.png": (512, 546, "RGB", True),
    "city_beverly_facade_n.png": (512, 546, "RGB", True),
    "city_mall_facade.png": (512, 273, "RGB", True),
    "city_shophouse_facade.png": (512, 307, "RGB", False),   # 12 m x 2 storeys of 3.6 m = one whole shophouse
    "city_industrial_facade.png": (512, 273, "RGB", True),
    "city_canal_water.png": (512, 512, "RGB", True),
    "city_road_overlay.png": (512, 256, "RGBA", False),
    "city_roof_flat.png": (512, 512, "RGB", True),
}
# Shophouse tile contract (generate_city_textures.TILE_W / TILE_STOREYS, MapBuilder "FACADE UV CONTRACT"): the tile is
# SHOPHOUSE_STOREYS storeys high (shopfront below, windows above); MapBuilder maps the ground storey of a shophouse to
# the lower half and every upper storey to the upper half, so any storey count works as long as every shophouse has
# the tile's storey height. The OSM shophouses are exactly SHOPHOUSE_STOREYS storeys (one tile over the whole
# building, as drawn); the Microsoft tube houses ("source": "msft") have 1-4.
SHOPHOUSE_TILE_W_M = 12.0
SHOPHOUSE_STOREYS = 2


def check_shophouse_fits_data(errors, png_height):
    """Every style == "shophouse" building in mapdata.json must share one storey height (height / levels) and the
    tile must be drawn at SHOPHOUSE_STOREYS of those storeys (px/m = 512 / tile width), or the facade bands land
    off the floors (squashed windows, shutters above the pavement). OSM shophouses must have exactly
    SHOPHOUSE_STOREYS levels."""
    with open(os.path.join(ROOT, "assets", "data", "mapdata.json"), encoding="utf-8") as f:
        shops = [b for b in json.load(f)["buildings"] if b.get("style") == "shophouse"]
    if not shops:
        errors.append("mapdata.json: no shophouse buildings, nothing to fit the tile to")
        return
    osm_levels = sorted({int(b["levels"]) for b in shops if b.get("source", "osm") != "msft"})
    storey_h = sorted({round(float(b["height"]) / max(1, int(b["levels"])), 2) for b in shops})
    if osm_levels and osm_levels != [SHOPHOUSE_STOREYS]:
        errors.append("city_shophouse_facade.png: tile draws %d storeys but OSM shophouses have levels %s"
                      % (SHOPHOUSE_STOREYS, osm_levels))
    if len(storey_h) != 1:
        errors.append("city_shophouse_facade.png: mapdata shophouses have several storey heights %s, one tile cannot fit all"
                      % storey_h)
    ppm = 512 / SHOPHOUSE_TILE_W_M
    want = int(round(storey_h[0] * SHOPHOUSE_STOREYS * ppm))
    if png_height != want:
        errors.append("city_shophouse_facade.png: height %d px, but %d storeys of %.1f m at %.2f px/m are %d px"
                      % (png_height, SHOPHOUSE_STOREYS, storey_h[0], ppm, want))


def seam(a, axis):
    """Mean difference between the two opposite edges vs. the mean difference between ordinary neighbours.
    A tileable image has no bigger step at the wrap-around than inside the image."""
    if axis == 1:
        first, last, adj = a[:, 0], a[:, -1], np.abs(np.diff(a, axis=1)).mean()
    else:
        first, last, adj = a[0], a[-1], np.abs(np.diff(a, axis=0)).mean()
    return float(np.abs(first - last).mean()), float(adj)


def main():
    errors = []
    for name, (w, h, mode, tiles_y) in SPEC.items():
        path = os.path.join(TEX, name)
        if not os.path.exists(path):
            errors.append("%s: missing" % name)
            continue
        stub = path + ".import"
        if not os.path.exists(stub) or 'importer="keep"' not in open(stub, encoding="utf-8").read():
            errors.append("%s: .import keep stub missing" % name)
        im = Image.open(path)
        if im.size != (w, h):
            errors.append("%s: size %s, expected %s" % (name, im.size, (w, h)))
        if im.mode != mode:
            errors.append("%s: mode %s, expected %s" % (name, im.mode, mode))
        if name == "city_shophouse_facade.png":
            check_shophouse_fits_data(errors, im.size[1])
        a = np.asarray(im.convert(mode), dtype=np.float32)
        s, adj = seam(a, 1)
        if s > max(8.0, 2.5 * adj):
            errors.append("%s: visible seam along x (edge diff %.1f, neighbour diff %.1f)" % (name, s, adj))
        if tiles_y:
            s, adj = seam(a, 0)
            if s > max(8.0, 2.5 * adj):
                errors.append("%s: visible seam along y (edge diff %.1f, neighbour diff %.1f)" % (name, s, adj))
        if name.endswith("_n.png"):
            if a[..., 2].mean() < 170.0:
                errors.append("%s: normal map does not face +Z (mean blue %.0f)" % (name, a[..., 2].mean()))
            base = name.replace("_n.png", ".png")
            if base in SPEC and SPEC[base][:2] != (w, h):
                errors.append("%s: size differs from its albedo" % name)
        if mode == "RGBA":
            alpha = a[..., 3]
            if (alpha == 0).mean() < 0.5 or (alpha > 200).mean() < 0.01:
                errors.append("%s: overlay must be mostly transparent with some opaque paint" % name)
        if a.std() < 4.0:
            errors.append("%s: image is flat (std %.1f), nothing drawn" % (name, a.std()))
    for e in errors:
        print("FAIL", e)
    if errors:
        print("FAILED: %d problem(s)" % len(errors))
        return 1
    print("SUCCESS: CITY TEXTURES OK n=%d" % len(SPEC))
    return 0


if __name__ == "__main__":
    sys.exit(main())
