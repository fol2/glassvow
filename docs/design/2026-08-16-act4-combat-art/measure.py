#!/usr/bin/env python3
"""Alpha gate for #221 combat-art cutouts.

    python3 docs/design/2026-08-16-act4-combat-art/measure.py
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
from install import leftover_magenta, margin_dark  # noqa: E402

STAGE = HERE.parents[2] / "assets" / "art" / "stage"
ENEMIES = HERE.parents[2] / "assets" / "art" / "enemies"
BAR = 0.90

SHIPPED = [
    STAGE / "act4-backdrop.png",
    STAGE / "act4-mid.png",
    STAGE / "act4-ledge.png",
    ENEMIES / "unwalkedSelf.png",
    ENEMIES / "uncrossedSelf.png",
    ENEMIES / "unopenedSelf.png",
    ENEMIES / "eternalKeeper.png",
]


def measure(path: Path) -> dict[str, object]:
    im = Image.open(path)
    w, h = im.size
    if im.mode != "RGBA":
        return {
            "name": path.name, "mode": im.mode, "size": f"{w}×{h}",
            "ge240": 0.0, "corners": "n/a", "note": f"not RGBA ({im.mode})",
        }
    alpha = im.getchannel("A")
    pix = list(alpha.getdata())
    nz = [a for a in pix if a > 0]
    ge = [a for a in nz if a >= 240]
    pct = (100.0 * len(ge) / len(nz)) if nz else 0.0
    corners = [im.getpixel(c)[3] for c in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1))]
    top_clear = corners[0] == 0 and corners[1] == 0
    char = "unwalked" in path.name or "Keeper" in path.name or "self" in path.name
    mag = leftover_magenta(im) if char else 0
    mdark = margin_dark(im) if char else 0
    ok = pct >= BAR * 100 and (all(c == 0 for c in corners) if char else top_clear)
    if "unwalked" in path.name or "uncrossed" in path.name or "unopened" in path.name:
        ok = ok and mag < 32 and mdark < 400
    return {
        "name": path.name, "mode": im.mode, "size": f"{w}×{h}",
        "ge240": pct, "corners": corners, "mag": mag, "mdark": mdark,
        "note": "pass" if ok else "fail",
    }


def main() -> None:
    print(f"{'file':26} {'size':11} {'≥240%':>7}  mag  mdark  corners          verdict")
    for p in SHIPPED:
        if not p.exists():
            print(f"{p.name:26} MISSING")
            continue
        m = measure(p)
        print(
            f"{m['name']:26} {m['size']:11} "
            f"{m['ge240']:6.1f}%  {m['mag']:4d} {m['mdark']:5d}  "
            f"{str(m['corners']):16} {m['note']}"
        )


if __name__ == "__main__":
    main()
