#!/usr/bin/env python3
"""Bake a USGS 3DEP lidar tile into a NOCTIS-7 city texture.

The renderer consumes a 256x256 RGBA8 grid (height, palette|style, density,
flags). Procedural generation fills that grid from a seed; the source-city
parser fills it from text. This fills it from a laser survey, so the same
renderer walks a real place with no rendering code changed.

The points themselves are never shipped. What matters is the subtraction:

    DSM (highest return per cell) - DTM (ground surface) = height above ground

which is exactly the height field the renderer already eats. 4.7 billion points
collapse to a 256 KB texture.

Data: https://registry.opendata.aws/usgs-lidar/ (public domain)
Usage: python3 tools/bake_lidar_city.py --lat 40.7530 --lon -73.9860 --out city.png
"""

import argparse
import io
import json
import math
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor

import numpy as np

BASE = "https://s3-us-west-2.amazonaws.com/usgs-lidar-public"
R_EARTH = 6378137.0
GRID = 256                 # renderer grid, cells per side
CELL_M = 4.0               # real metres per cell -> 1024 m across
HSTEP = 1.6                # renderer metres per height byte
MAX_DEPTH = 9

# renderer flag bits
ROAD, ROADX, ROADZ, PARK, WATER, SIGNSTRIP, BEACON, PLAZA = 1, 2, 4, 8, 16, 32, 64, 128

# LAS classification codes we care about
C_GROUND, C_LOWVEG, C_MEDVEG, C_HIGHVEG, C_BUILDING = 2, 3, 4, 5, 6
C_NOISE, C_WATER, C_BRIDGE, C_NOISE2 = 7, 9, 17, 18


def lonlat_to_mercator(lon, lat):
    x = lon * R_EARTH * math.pi / 180.0
    y = R_EARTH * math.log(math.tan(math.pi / 4 + math.radians(lat) / 2))
    return x, y


def fetch(url, tries=4):
    for i in range(tries):
        try:
            with urllib.request.urlopen(url, timeout=60) as r:
                return r.read()
        except Exception as e:
            if i == tries - 1:
                raise
    return None


def node_bounds(ept_bounds, d, x, y, z):
    size = (ept_bounds[3] - ept_bounds[0]) / (2 ** d)
    return (ept_bounds[0] + x * size, ept_bounds[1] + y * size,
            ept_bounds[0] + (x + 1) * size, ept_bounds[1] + (y + 1) * size)


def overlaps(nb, box):
    return not (nb[2] <= box[0] or nb[0] >= box[2] or nb[3] <= box[1] or nb[1] >= box[3])


def collect_nodes(dataset, ept, box, max_depth):
    """Walk the EPT hierarchy, keeping nodes whose XY footprint hits the box.

    A count of -1 means the subtree is described in its own hierarchy file. That
    has to be followed inline: re-queueing the same key against a visited-set
    silently truncates the walk at the first chunk boundary, which caps the whole
    fetch at the root's handful of nodes no matter what depth is requested.
    """
    out = []

    def walk(key, table):
        d, x, y, z = (int(v) for v in key.split("-"))
        if d > max_depth:
            return
        if not overlaps(node_bounds(ept["bounds"], d, x, y, z), box):
            return
        count = table.get(key)
        if count is None or count == 0:
            return
        if count == -1:
            walk(key, json.loads(fetch(f"{BASE}/{dataset}/ept-hierarchy/{key}.json")))
            return
        out.append((key, count))
        if d < max_depth:
            for dx in (0, 1):
                for dy in (0, 1):
                    for dz in (0, 1):
                        walk(f"{d+1}-{2*x+dx}-{2*y+dy}-{2*z+dz}", table)

    walk("0-0-0-0", json.loads(fetch(f"{BASE}/{dataset}/ept-hierarchy/0-0-0-0.json")))
    return out


def main():
    global CELL_M
    ap = argparse.ArgumentParser()
    ap.add_argument("--dataset", default="NY_NewYorkCity")
    ap.add_argument("--lat", type=float, default=40.7530)
    ap.add_argument("--lon", type=float, default=-73.9860)
    ap.add_argument("--depth", type=int, default=MAX_DEPTH)
    ap.add_argument("--cell", type=float, default=CELL_M,
                    help="real metres per cell; 4 m covers 1 km, 32 m covers 8 km")
    ap.add_argument("--out", default="lidar-city.png")
    ap.add_argument("--meta", default=None)
    args = ap.parse_args()
    CELL_M = args.cell

    import laspy
    from PIL import Image

    ept = json.loads(fetch(f"{BASE}/{args.dataset}/ept.json"))
    print(f"dataset {args.dataset}: {ept['points']:,} points, srs {ept['srs'].get('authority')}:"
          f"{ept['srs'].get('horizontal')}")

    # Web Mercator inflates horizontal distance by 1/cos(lat); undo it so a cell
    # is 4 real metres and the city comes out at true scale.
    merc_per_m = 1.0 / math.cos(math.radians(args.lat))
    half = GRID * CELL_M * merc_per_m / 2.0
    cx, cy = lonlat_to_mercator(args.lon, args.lat)
    box = (cx - half, cy - half, cx + half, cy + half)
    print(f"centre {args.lat},{args.lon} -> mercator {cx:.0f},{cy:.0f}")
    print(f"extent {GRID * CELL_M:.0f} m across, {CELL_M} m per cell, "
          f"mercator scale {merc_per_m:.4f}")

    nodes = collect_nodes(args.dataset, ept, box, args.depth)
    total = sum(c for _, c in nodes)
    print(f"octree: {len(nodes)} nodes overlap, {total:,} points to fetch")
    if not nodes:
        sys.exit("no lidar coverage at that location")

    # accumulators
    dsm = np.full((GRID, GRID), -9e9, dtype=np.float64)       # highest return
    gnd = np.full((GRID, GRID), 9e9, dtype=np.float64)        # lowest ground return
    n_pts = np.zeros((GRID, GRID), dtype=np.int64)
    n_bld = np.zeros((GRID, GRID), dtype=np.int64)
    n_veg = np.zeros((GRID, GRID), dtype=np.int64)
    n_wat = np.zeros((GRID, GRID), dtype=np.int64)
    n_gnd = np.zeros((GRID, GRID), dtype=np.int64)
    cls_hist = {}

    def ingest(item):
        key, _ = item
        try:
            raw = fetch(f"{BASE}/{args.dataset}/ept-data/{key}.laz")
        except Exception as e:
            print(f"  skip {key}: {e}")
            return 0
        f = laspy.read(io.BytesIO(raw))
        x, y, z = np.asarray(f.x), np.asarray(f.y), np.asarray(f.z)
        cls = np.asarray(f.classification)

        keep = (cls != C_NOISE) & (cls != C_NOISE2)
        ix = ((x - box[0]) / (box[2] - box[0]) * GRID).astype(np.int64)
        iy = ((y - box[1]) / (box[3] - box[1]) * GRID).astype(np.int64)
        keep &= (ix >= 0) & (ix < GRID) & (iy >= 0) & (iy < GRID)
        if not keep.any():
            return 0
        ix, iy, z, cls = ix[keep], iy[keep], z[keep], cls[keep]
        u, c = np.unique(cls, return_counts=True)
        for k, v in zip(u.tolist(), c.tolist()):
            cls_hist[k] = cls_hist.get(k, 0) + v
        flat = iy * GRID + ix
        np.maximum.at(dsm.reshape(-1), flat, z)
        np.add.at(n_pts.reshape(-1), flat, 1)
        for mask, acc in ((cls == C_BUILDING, n_bld),
                          ((cls == C_HIGHVEG) | (cls == C_MEDVEG), n_veg),
                          (cls == C_WATER, n_wat)):
            if mask.any():
                np.add.at(acc.reshape(-1), flat[mask], 1)
        g = cls == C_GROUND
        if g.any():
            np.minimum.at(gnd.reshape(-1), flat[g], z[g])
            np.add.at(n_gnd.reshape(-1), flat[g], 1)
        return len(z)

    done = 0
    with ThreadPoolExecutor(max_workers=8) as pool:
        for got in pool.map(ingest, nodes):
            done += got
            if done and done % 500000 < got:
                print(f"  ingested {done:,} points")
    print(f"ingested {done:,} points into the grid")
    NAMES = {1:'unclassified',2:'ground',3:'low veg',4:'med veg',5:'high veg',6:'BUILDING',
             7:'noise',9:'water',10:'rail',11:'road surface',17:'bridge',18:'noise'}
    for k in sorted(cls_hist, key=lambda k: -cls_hist[k]):
        print(f"   class {k:<3} {NAMES.get(k,'?'):<14} {cls_hist[k]:>10,}")
    if done == 0:
        sys.exit("no points landed in the target box")

    # ---- ground surface: sparse in a dense city, so fill it from what we have
    have_g = n_gnd > 0
    print(f"ground returns cover {100 * have_g.mean():.1f}% of cells")
    ground = np.where(have_g, gnd, np.nan)
    if have_g.any():
        # coarse median fill, then a couple of smoothing passes over the holes
        base = np.nanmedian(ground)
        filled = np.where(np.isnan(ground), base, ground)
        for _ in range(24):
            pad = np.pad(filled, 1, mode="edge")
            blur = (pad[:-2, 1:-1] + pad[2:, 1:-1] + pad[1:-1, :-2] + pad[1:-1, 2:]) / 4.0
            filled = np.where(have_g, ground, blur)
    else:
        filled = np.zeros((GRID, GRID))

    valid = n_pts > 0
    height = np.where(valid, dsm - filled, 0.0)

    # A max-per-cell DSM takes the highest return, which in an unclassified
    # survey includes birds and scan artefacts. Real towers are many contiguous
    # cells; a spike is one cell far above its neighbours.
    pad = np.pad(height, 1, mode="edge")
    stack = np.stack([pad[:-2, :-2], pad[:-2, 1:-1], pad[:-2, 2:],
                      pad[1:-1, :-2],                pad[1:-1, 2:],
                      pad[2:, :-2],  pad[2:, 1:-1],  pad[2:, 2:]])
    neigh = np.median(stack, axis=0)
    spikes = height > neigh + 45.0
    print(f"despiked {int(spikes.sum())} isolated cells")
    height = np.where(spikes, neigh, height)
    height = np.clip(height, 0.0, 250 * HSTEP)

    # ---- classify each cell
    classified = (n_bld.sum() + n_veg.sum() + n_wat.sum()) > 0.01 * max(done, 1)
    if not classified:
        print("classification channel is sparse; deriving from geometry alone")
    water = (n_wat > n_pts * 0.5) & (n_wat > 0)
    veg = (n_veg > n_bld) & (n_veg > n_pts * 0.25) & (height > 2)
    building = height > 6.0

    # street level: flat, dry, and actually surveyed
    street = valid & ~water & (height < 2.0)

    tex = np.zeros((GRID, GRID, 4), dtype=np.uint8)
    hb = np.clip(np.round(height / HSTEP), 0, 250).astype(np.uint8)
    hb[~building] = 0
    tex[..., 0] = hb

    # colour carries height, not appearance: a real data channel
    bands = np.array([0, 1, 2, 15, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], dtype=np.uint8)
    idx = np.clip((height / 22.0).astype(np.int64), 0, len(bands) - 1)
    pal = bands[idx]
    pal = np.where(veg, 3, pal)

    style = np.full((GRID, GRID), 0, dtype=np.uint8)
    style = np.where(veg, 7, style)                       # vegetation -> foliage facade
    style = np.where(height > 120, 1, style)              # towers -> ribbon glazing
    tex[..., 1] = (pal & 15) | ((style & 15) << 4)

    dens = np.clip(0.22 + (height / 260.0), 0.15, 0.72)
    tex[..., 2] = (dens * 255).astype(np.uint8)

    flags = np.zeros((GRID, GRID), dtype=np.uint8)
    flags |= np.where(water, WATER, 0).astype(np.uint8)
    flags |= np.where(street & ~water, ROAD | ROADX | ROADZ, 0).astype(np.uint8)
    flags |= np.where(veg & ~building, PARK, 0).astype(np.uint8)
    flags |= np.where(building & (height > 90), BEACON, 0).astype(np.uint8)
    flags |= np.where(~valid & ~water, PLAZA, 0).astype(np.uint8)
    tex[..., 3] = flags

    # Canvas backing stores are premultiplied, so a data byte in the alpha
    # channel silently destroys RGB wherever it is small — and flag bits are
    # mostly small. Emit a 256x512 fully opaque image instead: the grid on top,
    # the flag plane underneath.
    out = np.zeros((GRID * 2, GRID, 4), dtype=np.uint8)
    out[:GRID, :, 0:3] = tex[..., 0:3]
    out[GRID:, :, 0] = tex[..., 3]
    out[..., 3] = 255
    Image.fromarray(out, "RGBA").save(args.out, optimize=True)

    built = building.sum()
    stats = {
        "dataset": args.dataset, "lat": args.lat, "lon": args.lon,
        "cell_m": CELL_M, "grid": GRID, "points_ingested": int(done),
        "coverage_pct": round(100 * float(valid.mean()), 1),
        "tallest_m": round(float(height.max()), 1),
        "mean_building_m": round(float(height[building].mean()), 1) if built else 0,
        "building_cells": int(built), "water_cells": int(water.sum()),
        "street_cells": int(street.sum()), "veg_cells": int(veg.sum()),
    }
    print(json.dumps(stats, indent=1))
    if args.meta:
        json.dump(stats, open(args.meta, "w"), indent=1)
    print(f"wrote {args.out}")


if __name__ == "__main__":
    main()
