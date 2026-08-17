#!/usr/bin/env python3
"""Review contact sheet for #221 combat-art candidates.

    python3 docs/design/2026-08-16-act4-combat-art/contact_sheet.py
"""
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).parent
CANDIDATES = HERE / "candidates"

ROWS = [
    ("backdrop  [C picked]", ["act4-backdrop-a", "act4-backdrop-b", "act4-backdrop-c"]),
    ("mid  [C picked]", ["act4-mid-a", "act4-mid-b", "act4-mid-c", "act4-mid-d"]),
    ("ledge  [B picked]", ["act4-ledge-a", "act4-ledge-b"]),
    ("unwalkedSelf  [D picked]", ["unwalked-self-a", "unwalked-self-b", "unwalked-self-c", "unwalked-self-d"]),
    ("uncrossedSelf  [B proposed]", ["uncrossed-self-a", "uncrossed-self-b"]),
    ("unopenedSelf  [A proposed]", ["unopened-self-a", "unopened-self-b"]),
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
