#!/usr/bin/env python3
"""Build the review contact sheet for the #310 scene plates.

One row per plate in scene order; forks sit side by side so a pick is made by
looking, not by opening ten files. Regenerate after any new candidate lands:

    python3 docs/design/2026-08-16-scene-plates/contact_sheet.py
"""
from PIL import Image, ImageDraw
from pathlib import Path

HERE = Path(__file__).parent
CANDIDATES = HERE / "candidates"

# Scene order, not alphabetical — the sheet is read the way the game plays.
ROWS = [
    ("1  opening-hearth", ["opening-hearth-a", "opening-hearth-b"]),
    ("2  unsealing-mirror-queue", ["unsealing-mirror-queue-a", "unsealing-mirror-queue-b"]),
    ("3  unsealing-monuments-push", ["unsealing-monuments-push-a"]),
    ("-  unsealing-door-open (crop of 3)", ["unsealing-door-open-a"]),
    ("4  act4-node1  threshold'", ["act4-node1-a", "act4-node1-b"]),
    ("5  act4-node2  obsidian'", ["act4-node2-a", "act4-node2-b"]),
    ("6  act4-node3  sunken'", ["act4-node3-a"]),
    ("7  act4-node4  ash wood'", ["act4-node4-a", "act4-node4-b"]),
    ("8  act4-node5  gilded gate", ["act4-node5-a"]),
    ("9  finale-swap", ["finale-swap-a"]),
]

CELL_W, CELL_H = 480, 320
PAD, LABEL_H, GUTTER = 12, 22, 8
BG, FG = (18, 16, 20), (214, 200, 176)


def main() -> None:
    cols = max(len(v) for _, v in ROWS)
    width = PAD + cols * (CELL_W + GUTTER) - GUTTER + PAD
    row_h = LABEL_H + CELL_H + GUTTER
    sheet = Image.new("RGB", (width, PAD + len(ROWS) * row_h + PAD), BG)
    draw = ImageDraw.Draw(sheet)

    y = PAD
    for title, names in ROWS:
        draw.text((PAD, y + 5), title, fill=FG)
        y += LABEL_H
        for i, name in enumerate(names):
            path = CANDIDATES / f"{name}.png"
            x = PAD + i * (CELL_W + GUTTER)
            if not path.exists():
                draw.rectangle([x, y, x + CELL_W, y + CELL_H], outline=(90, 40, 40))
                draw.text((x + 8, y + 8), f"missing: {name}", fill=(200, 120, 120))
                continue
            im = Image.open(path).convert("RGB")
            im.thumbnail((CELL_W, CELL_H), Image.LANCZOS)
            sheet.paste(im, (x, y))
            draw.text((x + 6, y + CELL_H - 16), name.rsplit("-", 1)[-1].upper(), fill=FG)
        y += CELL_H + GUTTER

    out = HERE / "contact-sheet.png"
    sheet.save(out)
    print(out)


if __name__ == "__main__":
    main()
