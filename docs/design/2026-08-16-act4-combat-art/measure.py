#!/usr/bin/env python3
"""Alpha gate for #221 combat-art cutouts.

    python3 docs/design/2026-08-16-act4-combat-art/measure.py
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

HERE = Path(__file__).parent
CANDIDATES = HERE / "candidates"
STAGE = HERE.parents[2] / "assets" / "art" / "stage"
ENEMIES = HERE.parents[2] / "assets" / "art" / "enemies"
BAR = 0.90

SHIPPED = [
    STAGE / "act4-backdrop.png",
    STAGE / "act4-mid.png",
    STAGE / "act4-ledge.png",
    ENEMIES / "unwalkedSelf.png",
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
    ok = pct >= BAR * 100 and (all(c == 0 for c in corners) if char else top_clear)
    return {
        "name": path.name, "mode": im.mode, "size": f"{w}×{h}",
        "ge240": pct, "corners": corners,
        "note": "pass" if ok else "fail",
    }


def main() -> None:
    print(f"{'file':26} {'mode':5} {'size':11} {'≥240%':>7}  corners          verdict")
    for p in SHIPPED:
        if not p.exists():
            print(f"{p.name:26} MISSING")
            continue
        m = measure(p)
        print(
            f"{m['name']:26} {m['mode']:5} {m['size']:11} "
            f"{m['ge240']:6.1f}%  {str(m['corners']):16} {m['note']}"
        )


if __name__ == "__main__":
    main()
