#!/usr/bin/env python3
"""Checkerboard contact sheet for #283 Keeper cutouts.

Checkerboard, not flat RGB — a black-baked figure looks fine on the
scene-plate sheet and is unusable as an overlay. Regenerate after a pass:

    python3 docs/design/2026-08-16-keeper-figures/contact_sheet.py
"""
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).parent
CANDIDATES = HERE / "candidates"

ROWS = [
    ("hearth seated", ["hearth-a", "hearth-b", "hearth-c", "hearth-d", "hearth-e"]),
    ("Act IV boss", ["boss-a", "boss-b", "boss-c", "boss-d"]),
]

CELL, PAD, LABEL_H, GUTTER = 280, 14, 24, 10
BG, FG = (18, 16, 20), (214, 200, 176)
CHECK_A, CHECK_B, CHECK = (42, 40, 46), (28, 26, 32), 16


def checker(size: tuple[int, int]) -> Image.Image:
    im = Image.new("RGB", size, CHECK_A)
    draw = ImageDraw.Draw(im)
    w, h = size
    for y in range(0, h, CHECK):
        for x in range(0, w, CHECK):
            if ((x // CHECK) + (y // CHECK)) % 2 == 0:
                draw.rectangle([x, y, x + CHECK - 1, y + CHECK - 1], fill=CHECK_B)
    return im


def main() -> None:
    cols = max(len(v) for _, v in ROWS)
    width = PAD + cols * (CELL + GUTTER) - GUTTER + PAD
    row_h = LABEL_H + CELL + GUTTER
    sheet = Image.new("RGB", (width, PAD + len(ROWS) * row_h + PAD), BG)
    draw = ImageDraw.Draw(sheet)
    y = PAD
    for title, names in ROWS:
        draw.text((PAD, y + 4), title, fill=FG)
        y += LABEL_H
        for i, name in enumerate(names):
            path = CANDIDATES / f"{name}.png"
            x = PAD + i * (CELL + GUTTER)
            cell = checker((CELL, CELL))
            if path.exists():
                im = Image.open(path).convert("RGBA")
                im.thumbnail((CELL - 8, CELL - 8), Image.LANCZOS)
                ox = (CELL - im.width) // 2
                oy = (CELL - im.height) // 2
                cell.paste(im, (ox, oy), im)
            else:
                ImageDraw.Draw(cell).text((8, 8), f"missing: {name}", fill=(200, 120, 120))
            sheet.paste(cell, (x, y))
            draw.text((x + 6, y + CELL - 16), name.rsplit("-", 1)[-1].upper(), fill=FG)
        y += CELL + GUTTER
    out = HERE / "contact-sheet.png"
    sheet.save(out)
    print(out)


if __name__ == "__main__":
    main()
