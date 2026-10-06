#!/usr/bin/env python3
"""Regenerate every printable file (and optionally the preview images)
from egg_case.scad.

    python3 tools/build.py              # STL + 3MF for 41 mm and 45 mm
    python3 tools/build.py --previews   # also re-render images/*.png

Needs OpenSCAD (set OPENSCAD=/path/to/openscad if it is not on PATH; a
2024+ nightly with the Manifold backend is ~100x faster than 2021.01) and,
for the 3MF plates, `pip install trimesh lxml`. Previews also need
matplotlib and Pillow (and xvfb-run on a headless Linux box).
"""
import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCAD = ROOT / "egg_case.scad"
SIZES = (45, 41)
BACKEND = []   # filled in by main()

# file name -> (part, extra -D overrides)
PARTS = {
    "shell":        ("shell", []),
    "back":         ("back", []),
    "back_tighter": ("back", ["pad_offset=0.5"]),
    "back_looser":  ("back", ["pad_offset=-0.5"]),
    "fit_test":     ("fit_test", []),
}


def openscad():
    exe = os.environ.get("OPENSCAD") or shutil.which("openscad") or shutil.which("openscad-nightly")
    if not exe:
        sys.exit("OpenSCAD not found - install it or set OPENSCAD=/path/to/openscad")
    return exe


def backend_args(exe):
    """Use the fast Manifold backend when this OpenSCAD build has it."""
    out = subprocess.run([exe, "--help"], capture_output=True, text=True)
    return ["--backend=manifold"] if "--backend" in (out.stdout + out.stderr) else []


def stl_path(size, name):
    return ROOT / "stl" / f"{size}mm" / f"egg_{size}mm_{name}.stl"


def build_stls(exe):
    for size in SIZES:
        for name, (part, extra) in PARTS.items():
            out = stl_path(size, name)
            out.parent.mkdir(parents=True, exist_ok=True)
            args = [exe] + BACKEND + ["-D", f'part="{part}"', "-D", f"watch_size={size}"]
            for d in extra:
                args += ["-D", d]
            if BACKEND:
                args += ["--export-format", "binstl"]
            subprocess.run(args + ["-o", str(out), str(SCAD)], check=True, capture_output=True)
            print("wrote", out.relative_to(ROOT))


def build_plates():
    try:
        import trimesh
        from trimesh.exchange import threemf
    except ImportError:
        print("skipping 3MF plates (pip install trimesh lxml)")
        return
    (ROOT / "3mf").mkdir(exist_ok=True)
    for size in SIZES:
        scene = trimesh.Scene()
        parts = {n: trimesh.load(stl_path(size, n)) for n in ("shell", "back")}
        gap = 14.0
        # shell + back side by side, centred on the 256 mm P1S plate
        x = 128 - (sum(m.extents[0] for m in parts.values()) + gap) / 2
        for name, m in parts.items():
            lo, hi = m.bounds
            m.apply_translation([x - lo[0], 128 - (lo[1] + hi[1]) / 2, -lo[2]])
            scene.add_geometry(m, node_name=name, geom_name=name)
            x += (hi[0] - lo[0]) + gap
        out = ROOT / "3mf" / f"egg_{size}mm_plate.3mf"
        out.write_bytes(threemf.export_3MF(scene))
        print("wrote", out.relative_to(ROOT))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--previews", action="store_true", help="also render images/*.png")
    a = ap.parse_args()
    exe = openscad()
    BACKEND[:] = backend_args(exe)
    build_stls(exe)
    build_plates()
    if a.previews:
        env = dict(os.environ, OPENSCAD=exe)
        subprocess.run([sys.executable, str(ROOT / "tools" / "preview.py"), "--out", str(ROOT / "images")],
                       check=True, env=env)


if __name__ == "__main__":
    main()
