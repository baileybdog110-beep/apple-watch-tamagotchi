#!/usr/bin/env python3
"""Sanity checks for egg_case.scad (or a modified copy of it).

    python3 tools/check.py [--scad FILE] [--size 45|41] [--out DIR] [-D name=value ...]

Reports, for the given size and parameter overrides:
  * mesh health of shell / back / fit_test (non-manifold edges)
  * clashes between shell, back and the dummy watch (only the 4 spring
    pads should touch the watch)
  * downward-facing area steeper than 55 deg (print overhangs; flat
    entries are short bridges)
  * thinnest lip around the screen window (front surface above the lip
    underside)
  * how far the crown cove cuts into the front silhouette
  * overall size and 100%-infill PLA weight
Exit code 1 if a hard check fails.

Needs OpenSCAD (OPENSCAD env var or on PATH) and `pip install trimesh
manifold3d shapely networkx rtree`.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
from collections import Counter
from pathlib import Path

import numpy as np
import trimesh
from shapely.geometry import Point, Polygon, box
from shapely.ops import unary_union

ROOT = Path(__file__).resolve().parent.parent
PLA = 1.24  # g/cm3


def openscad():
    exe = os.environ.get("OPENSCAD") or shutil.which("openscad") or shutil.which("openscad-nightly")
    if not exe:
        sys.exit("OpenSCAD not found - set OPENSCAD=/path/to/openscad")
    return exe


class Scad:
    def __init__(self, scad, size, defs, out):
        self.exe, self.scad, self.size, self.defs, self.out = openscad(), scad, size, defs, out
        help_txt = subprocess.run([self.exe, "--help"], capture_output=True, text=True)
        self.backend = ["--backend=manifold"] if "--backend" in help_txt.stdout + help_txt.stderr else []

    def run(self, part, ext="stl"):
        out = self.out / f"{part}_{self.size}.{ext}"
        args = [self.exe] + self.backend + ["-D", f'part="{part}"', "-D", f"watch_size={self.size}"]
        for d in self.defs:
            args += ["-D", d]
        subprocess.run(args + ["-o", str(out), str(self.scad)], check=True, capture_output=True)
        return out

    def mesh(self, part):
        return trimesh.load(self.run(part))

    def info(self):
        txt = self.run("info", "echo").read_text()
        return json.loads(txt[txt.index("{"):txt.rindex("}") + 1])


def nonmanifold_edges(m):
    c = Counter(map(tuple, m.edges_sorted))
    return sum(1 for v in c.values() if v != 2)


def egg_polygon(i, n=720):
    t = np.linspace(0, 2*np.pi, n, endpoint=False)
    return Polygon(np.c_[i["EA"]*np.cos(t)*(1 - i["EK"]*np.sin(t)), i["EB"]*np.sin(t)])


def ring_points(poly, n):
    ring = poly.exterior
    return np.array([ring.interpolate(d).coords[0] for d in np.linspace(0, ring.length, n, endpoint=False)])


def rrect(cx, cy, w, h, r):
    return box(cx - w/2 + r, cy - h/2 + r, cx + w/2 - r, cy + h/2 - r).buffer(r, resolution=32)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--scad", default=str(ROOT / "egg_case.scad"))
    ap.add_argument("--size", type=int, default=45)
    ap.add_argument("--out", default=None, help="scratch dir for meshes (default: temp)")
    ap.add_argument("-D", dest="defs", action="append", default=[])
    a = ap.parse_args()
    out = Path(a.out or (Path(os.environ.get("TMPDIR", "/tmp")) / "egg_check"))
    out.mkdir(parents=True, exist_ok=True)
    sc = Scad(a.scad, a.size, a.defs, out)
    info = sc.info()
    fails, report = [], {"size": a.size, "overrides": a.defs}

    shell, back, fit = sc.mesh("shell"), sc.mesh("back"), sc.mesh("fit_test")
    shell_asm = shell.copy()
    shell_asm.apply_translation([0, 0, info["ZS"]])   # shell STL is exported seam-down

    # 1. mesh health
    for name, m in (("shell", shell), ("back", back), ("fit_test", fit)):
        nm = nonmanifold_edges(m)
        report[f"{name}_nonmanifold_edges"] = nm
        if nm:
            fails.append(f"{name}: {nm} non-manifold edges")

    # 2. clashes (OpenSCAD intersections); expect exactly the 4 spring pads
    clash = sc.mesh("clash")
    blobs = [b for b in clash.split(only_watertight=False) if abs(b.volume) > 0.05] if len(clash.faces) else []
    pads = [b for b in blobs if b.bounds[1][2] <= info["ZS"] + 1.2 + 1.0 and b.extents.max() < 5]
    others = [b for b in blobs if b not in pads]
    report["clash_pads"] = len(pads)
    report["clash_other"] = [{"vol": round(abs(b.volume), 2), "bounds": b.bounds.round(1).tolist()} for b in others]
    if others:
        fails.append(f"{len(others)} unexpected clash volume(s)")

    # 3. overhangs (print orientation: shell seam-down, back outer-face down)
    for name, m in (("shell", shell), ("back", back)):
        n, c, ar = m.face_normals, m.triangles_center, m.area_faces
        down = (n[:, 2] < -np.sin(np.radians(55))) & (c[:, 2] > m.bounds[0][2] + 0.05)
        clusters = []
        if down.any():
            sub = m.submesh([np.where(down)[0]], append=True)
            for part in sorted(sub.split(only_watertight=False), key=lambda p: -p.area):
                if part.area < 2:
                    continue
                flat = float(np.mean(part.face_normals[:, 2] < -0.99))
                clusters.append({"area": round(part.area, 1), "flat_bridge_frac": round(flat, 2),
                                 "bounds": part.bounds.round(1).tolist()})
        report[f"{name}_overhangs_gt55"] = clusters
        sloped = [cl for cl in clusters if cl["flat_bridge_frac"] < 0.6 and cl["area"] > 15]
        if sloped:
            fails.append(f"{name}: {len(sloped)} steep sloped overhang region(s) (not flat bridges)")

    # 4. thinnest lip around the window: front surface just outside the
    #    window edge, measured down to the lip underside
    win = rrect(0, info["YW"], info["W"] - 2*info["LIP"] + 0.6, info["H"] - 2*info["LIP"] + 0.6,
                max(info["WR"] - info["LIP"] + 0.3, 0.5))
    pts = ring_points(win, 240)
    origins = np.c_[pts, np.full(len(pts), 60.0)]
    dirs = np.tile([0, 0, -1.0], (len(pts), 1))
    locs, ray_idx, _ = shell_asm.ray.intersects_location(origins, dirs, multiple_hits=False)
    top = np.full(len(pts), np.nan)
    top[ray_idx] = locs[:, 2]
    lip = top - info["ZLU"]
    report["lip_min_mm"] = round(float(np.nanmin(lip)), 2)
    report["lip_max_mm"] = round(float(np.nanmax(lip)), 2)
    if np.nanmin(lip) < 1.0:
        fails.append(f"lip too thin: {np.nanmin(lip):.2f} mm (< 1.0)")

    # 5. front silhouette vs the egg outline (crown-cove notch)
    egg = egg_polygon(info)
    sil = unary_union([Polygon(t) for t in shell_asm.triangles[:, :, :2] if Polygon(t).area > 1e-6])
    sil = sil.buffer(0.02)
    gaps = [sil.distance(Point(p)) for p in ring_points(egg, 720)]
    report["front_silhouette_max_notch_mm"] = round(float(max(gaps)), 2)
    filled = unary_union([Polygon(g.exterior) for g in getattr(sil, "geoms", [sil])])
    report["front_silhouette_area_loss_mm2"] = round(float(egg.area - filled.intersection(egg).area), 1)

    # 6. size + weight
    asm = trimesh.util.concatenate([shell_asm, back])
    report["overall_mm"] = asm.extents.round(1).tolist()
    report["shell_g_pla100"] = round(shell.volume/1000*PLA, 1)
    report["back_g_pla100"] = round(back.volume/1000*PLA, 1)
    report["case_g_pla100"] = round((shell.volume + back.volume)/1000*PLA, 1)
    report["info"] = info
    report["FAILS"] = fails

    print(json.dumps(report, indent=1))
    print("\nRESULT:", "PASS" if not fails else "FAIL -> " + "; ".join(fails))
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
