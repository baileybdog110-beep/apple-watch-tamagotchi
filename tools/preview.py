#!/usr/bin/env python3
"""Render preview images of egg_case.scad (or a modified copy).

    python3 tools/preview.py [--scad FILE] [--size 45|41] --out DIR [-D name=value ...]

Writes DIR/<view>.png for hero, front, crown (right side), profile (left
side), back, exploded, plus sections.png (cuts through the crown and the
centre line, shell/back/watch in different colours) and sheet.png (all
views on one page). Needs OpenSCAD, Pillow, trimesh, matplotlib; on a
headless Linux box also xvfb-run.
"""
import argparse
import os
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VIEWS = [  # name, part, camera rotation (x, y, z), projection
    ("hero",     "assembly", (58, 0, 28),  "perspective"),
    ("front",    "assembly", (0, 0, 0),    "ortho"),
    ("crown",    "assembly", (70, 0, 60),  "perspective"),
    ("profile",  "assembly", (90, 0, 270), "ortho"),
    ("back",     "assembly", (180, 0, 0),  "ortho"),
    ("exploded", "exploded", (62, 0, 30),  "perspective"),
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--scad", default=str(ROOT / "egg_case.scad"))
    ap.add_argument("--size", type=int, default=45)
    ap.add_argument("--out", required=True)
    ap.add_argument("-D", dest="defs", action="append", default=[])
    a = ap.parse_args()
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    exe = os.environ.get("OPENSCAD") or shutil.which("openscad") or shutil.which("openscad-nightly")
    help_txt = subprocess.run([exe, "--help"], capture_output=True, text=True)
    backend = ["--backend=manifold"] if "--backend" in help_txt.stdout + help_txt.stderr else []
    xvfb = ["xvfb-run", "-a"] if shutil.which("xvfb-run") and not os.environ.get("DISPLAY") else []
    defs = ["-D", f"watch_size={a.size}"]
    for d in a.defs:
        defs += ["-D", d]

    files = []
    for name, part, rot, proj in VIEWS:
        f = out / f"{name}.png"
        subprocess.run(xvfb + [exe] + backend + defs + ["-D", f'part="{part}"', "--render", "--imgsize=900,900",
                       "--colorscheme=Tomorrow", "--viewall", "--autocenter", f"--projection={proj}",
                       f"--camera=0,0,0,{rot[0]},{rot[1]},{rot[2]},300", "-o", str(f), a.scad],
                       check=True, capture_output=True)
        files.append(f)

    # cross-sections
    import json
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    import trimesh
    from matplotlib.patches import Polygon as MP

    def mesh(part):
        p = out / f"_{part}.stl"
        subprocess.run([exe] + backend + defs + ["-D", f'part="{part}"', "-o", str(p), a.scad],
                       check=True, capture_output=True)
        return trimesh.load(p)
    echo = out / "_info.echo"
    subprocess.run([exe] + defs + ["-D", 'part="info"', "-o", str(echo), a.scad], check=True, capture_output=True)
    t = echo.read_text()
    info = json.loads(t[t.index("{"):t.rindex("}") + 1])
    shell, back, watch = mesh("shell"), mesh("back"), mesh("watch")
    shell.apply_translation([0, 0, info["ZS"]])
    fig, axs = plt.subplots(2, 1, figsize=(12, 9))
    cuts = [([0, info["YW"] + info["CROWN_Y"], 0], [0, 1, 0], [0, 2], "cut through the crown (x across, z up)"),
            ([0, 0, 0], [1, 0, 0], [1, 2], "centre-line cut (y along the egg, z up)")]
    for ax, (o, n, axes, title) in zip(axs, cuts):
        for m, col in ((back, "#5b6168"), (shell, "#d9cfbd"), (watch, "#1c1c1e")):
            s = m.section(plane_origin=o, plane_normal=n)
            if s is None:
                continue
            for ent in s.discrete:
                ax.add_patch(MP(ent[:, axes], closed=True, fc=col, ec="k", lw=0.3, alpha=0.9))
        ax.set_aspect("equal"); ax.autoscale_view(); ax.grid(alpha=0.3); ax.set_title(title, fontsize=10)
    plt.tight_layout()
    plt.savefig(out / "sections.png", dpi=90)
    for p in out.glob("_*"):
        p.unlink()

    from PIL import Image
    ims = [Image.open(f) for f in files]
    w, h = ims[0].size
    sheet = Image.new("RGB", (w*3, h*2), "white")
    for i, im in enumerate(ims):
        sheet.paste(im, ((i % 3)*w, (i // 3)*h))
    sheet.resize((w*3*2//3, h*2*2//3)).save(out / "sheet.png")
    print("wrote", ", ".join(str(f) for f in files + [out / "sections.png", out / "sheet.png"]))


if __name__ == "__main__":
    main()
