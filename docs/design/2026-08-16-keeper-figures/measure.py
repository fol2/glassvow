#!/usr/bin/env python3
"""Alpha gate for #283 Keeper cutouts. Same bar as hollow-lamplighter.

    python3 docs/design/2026-08-16-keeper-figures/measure.py
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

HERE = Path(__file__).parent
CANDIDATES = HERE / "candidates"
BAR = 0.90


def measure(path: Path) -> dict[str, object]:
    im = Image.open(path)
    w, h = im.size
    mode = im.mode
    if mode != "RGBA":
        return {
            "name": path.name, "mode": mode, "size": f"{w}×{h}",
            "ge240": 0.0, "corners": "n/a", "ok": False,
            "note": f"not RGBA ({mode})",
        }
    alpha = im.getchannel("A")
    pix = list(alpha.getdata())
    nz = [a for a in pix if a > 0]
    ge = [a for a in nz if a >= 240]
    pct = (100.0 * len(ge) / len(nz)) if nz else 0.0
    corners = [im.getpixel(c)[3] for c in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1))]
    ok = pct >= BAR * 100 and all(c == 0 for c in corners) and max(w, h) <= 1024
    return {
        "name": path.name, "mode": mode, "size": f"{w}×{h}",
        "ge240": pct, "corners": corners, "ok": ok,
        "note": "pass" if ok else "fail",
    }


def main() -> None:
    files = sorted(CANDIDATES.glob("*.png"))
    if not files:
        print("no candidates yet")
        return
    print(f"{'file':22} {'mode':5} {'size':11} {'≥240%':>7}  corners          verdict")
    for p in files:
        m = measure(p)
        print(
            f"{m['name']:22} {m['mode']:5} {m['size']:11} "
            f"{m['ge240']:6.1f}%  {str(m['corners']):16} {m['note']}"
        )


if __name__ == "__main__":
    main()
