#!/usr/bin/env python3
"""Install James's picked candidates into assets/art/scenes/ as shipped plates.

The mapping below IS the record of which candidate won; re-running the script
reproduces the shipped bytes from the candidates in this directory.

Each plate is quantized to a 256-colour palette on the way in. That is not a
repo-size tweak: `compress/mode=0` in the .import means Godot stores the texture
losslessly, so the packed .ctex tracks image content. Measured on act4-node5 —
RGB 2,205,462 B, quantized 949,946 B, a 57% cut in the shipped texture. Checked
at full size first: the sunset gradient and cloud sea, the hardest case in the
set, show no visible banding.

Candidates stay lossless so a re-crop or an edit pass never compounds.

    python3 docs/design/2026-08-16-scene-plates/install_plates.py
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

HERE = Path(__file__).parent
CANDIDATES = HERE / "candidates"
SCENES = HERE.parents[2] / "assets" / "art" / "scenes"

# shipped name  ->  winning candidate   [James, 2026-08-16]
PICKS = {
    "unsealing-mirror-queue": "unsealing-mirror-queue-b",
    "unsealing-monuments-push": "unsealing-monuments-push-a",
    "unsealing-door-open": "unsealing-door-open-a",
    "act4-node1": "act4-node1-b",
    "act4-node2": "act4-node2-b",
    "act4-node3": "act4-node3-a",
    "act4-node4": "act4-node4-b",
    "act4-node5": "act4-node5-a",
    "finale-swap": "finale-swap-a",
    "opening-hearth": "opening-hearth-c",
}


def main() -> None:
    total_src = total_out = 0
    for shipped, candidate in PICKS.items():
        src = CANDIDATES / f"{candidate}.png"
        if not src.exists():
            print(f"  SKIP {shipped:<26} {candidate}.png not present")
            continue
        dst = SCENES / f"{shipped}.png"
        im = Image.open(src).convert("RGB")
        im.quantize(
            colors=256, method=Image.MEDIANCUT, dither=Image.FLOYDSTEINBERG
        ).save(dst, optimize=True)
        total_src += src.stat().st_size
        total_out += dst.stat().st_size
        print(
            f"  {shipped:<26} <- {candidate:<28} "
            f"{src.stat().st_size/1e6:5.2f} -> {dst.stat().st_size/1e6:5.2f} MB"
        )
    if total_src:
        print(f"\n  total {total_src/1e6:.2f} MB -> {total_out/1e6:.2f} MB "
              f"({100 - total_out*100//total_src}% cut)")


if __name__ == "__main__":
    main()
