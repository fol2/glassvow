#!/usr/bin/env python3
"""Seat a full-bleed 1024 icon candidate on the macOS icon grid.

Apple's masters keep an 824px rounded-square live area centred in a 1024
canvas, transparent outside it (measured from Preview.app's own icns, DL
review of PR #53). A full-bleed square reads as a black tile in the Dock —
24% wider than every neighbour, with corners nothing else has.

    tools/make_icon_master.py <candidate.png> <out.png>

The candidate's lit disc (~759px) is scaled up ~10% and centred inside the
live area; the ground is NIGHT_BOT; corners follow Apple's ~22.37% radius.
Run tools/make_icon.sh afterwards to rebuild the icns ladder.
"""
import sys

from PIL import Image, ImageDraw

NIGHT = (4, 5, 11, 255)
CANVAS = 1024
LIVE = 824
RADIUS = round(LIVE * 0.2237)
DISC_SCALE = 1.10


def main() -> int:
    src_path, out_path = sys.argv[1], sys.argv[2]
    art = Image.open(src_path).convert("RGBA")
    if art.size != (CANVAS, CANVAS):
        art = art.resize((CANVAS, CANVAS), Image.LANCZOS)
    scaled = art.resize((round(CANVAS * DISC_SCALE),) * 2, Image.LANCZOS)
    off = (scaled.width - CANVAS) // 2
    art = scaled.crop((off, off, off + CANVAS, off + CANVAS))

    plate = Image.new("RGBA", (CANVAS, CANVAS), NIGHT)
    inset = (CANVAS - LIVE) // 2
    plate.paste(art.resize((LIVE, LIVE), Image.LANCZOS), (inset, inset))

    mask = Image.new("L", (CANVAS, CANVAS), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (inset, inset, inset + LIVE - 1, inset + LIVE - 1),
        radius=RADIUS, fill=255)
    out = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    out.paste(plate, (0, 0), mask)
    out.save(out_path)
    print(f"wrote {out_path} (live {LIVE}px, radius {RADIUS}px)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
