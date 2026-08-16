#!/usr/bin/env python3
"""Self-contained review page for #283 Keeper cutouts.

    python3 docs/design/2026-08-16-keeper-figures/build_review.py
"""
from __future__ import annotations

import base64
import io
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).parent
CAND = HERE / "candidates"
PLATE = Path("assets/art/scenes/opening-hearth.png")
OUT = HERE / "review.html"

HEARTH_PICK = ("D", "hearth-d.png", "James pick · silhouette master · 98.6%")
BOSS_PASSERS = [
    ("A", "boss-a.png", "98.4% · native 723×1024 · rim light still from the right"),
    ("C", "boss-c.png", "98.5% · inverted light from left · recommended"),
    ("D", "boss-d.png", "98.6%"),
]
BOSS_FAIL = [
    ("B", "boss-b.png", "84.9% · washed, out"),
]

CHECK = 24
CHECK_A, CHECK_B = (48, 46, 52), (32, 30, 36)
CELL = 520


def checker(size: tuple[int, int]) -> Image.Image:
    im = Image.new("RGB", size, CHECK_A)
    d = ImageDraw.Draw(im)
    w, h = size
    for y in range(0, h, CHECK):
        for x in range(0, w, CHECK):
            if ((x // CHECK) + (y // CHECK)) % 2 == 0:
                d.rectangle([x, y, x + CHECK - 1, y + CHECK - 1], fill=CHECK_B)
    return im


def on_checker(cutout: Image.Image, cell: int = CELL) -> Image.Image:
    fig = cutout.convert("RGBA")
    fig.thumbnail((cell - 24, cell - 24), Image.LANCZOS)
    bg = checker((cell, cell))
    bg.paste(fig, ((cell - fig.width) // 2, (cell - fig.height) // 2), fig)
    return bg


def on_plate(cutout: Image.Image, plate: Image.Image) -> Image.Image:
    """Sit the figure on the bare hearth step (right side of plate 1)."""
    scene = plate.convert("RGBA")
    fig = cutout.convert("RGBA")
    target_h = int(scene.height * 0.46)
    fig.thumbnail((int(scene.width * 0.32), target_h), Image.LANCZOS)
    x = int(scene.width * 0.62) - fig.width // 2
    y = int(scene.height * 0.78) - fig.height
    scene.paste(fig, (x, y), fig)
    return scene.convert("RGB")


def data_uri(im: Image.Image, q: int = 82) -> str:
    buf = io.BytesIO()
    im.convert("RGB").save(buf, "JPEG", quality=q, optimize=True)
    b64 = base64.b64encode(buf.getvalue()).decode("ascii")
    return f"data:image/jpeg;base64,{b64}"


def card(letter: str, note: str, cut: Image.Image, plate: Image.Image) -> str:
    chk = data_uri(on_checker(cut))
    ov = data_uri(on_plate(cut, plate), q=78)
    return f"""
<article>
  <h2>{letter}</h2>
  <p class="note">{note}</p>
  <div class="pair">
    <figure><img src="{chk}" alt="hearth {letter} on checkerboard"><figcaption>cutout</figcaption></figure>
    <figure><img src="{ov}" alt="hearth {letter} on opening plate"><figcaption>on opening-hearth</figcaption></figure>
  </div>
</article>"""


def side_by_side(left: Image.Image, right: Image.Image) -> Image.Image:
    cell = 560
    a = on_checker(left, cell)
    b = on_checker(right, cell)
    out = Image.new("RGB", (cell * 2 + 16, cell), (18, 16, 20))
    out.paste(a, (0, 0))
    out.paste(b, (cell + 16, 0))
    return out


def boss_card(letter: str, note: str, cut: Image.Image, master: Image.Image) -> str:
    cmp = data_uri(side_by_side(master, cut))
    return f"""
<article>
  <h2>Boss {letter}</h2>
  <p class="note">{note}</p>
  <figure><img src="{cmp}" alt="hearth D vs boss {letter}"><figcaption>left: hearth D · right: boss {letter}</figcaption></figure>
</article>"""


def main() -> None:
    plate = Image.open(PLATE)
    master = Image.open(CAND / HEARTH_PICK[1])
    hearth = card(HEARTH_PICK[0], HEARTH_PICK[2], master, plate)
    bosses = [boss_card(l, n, Image.open(CAND / f), master) for l, f, n in BOSS_PASSERS]
    fails = []
    for l, f, n in BOSS_FAIL:
        p = CAND / f
        if p.exists():
            fails.append(boss_card(l, n, Image.open(p), master))
    html = f"""<!doctype html>
<meta charset="utf-8">
<title>Keeper figures — #283</title>
<style>
body{{margin:0;background:#120f16;color:#ede4d6;font:16px/1.5 Georgia,serif}}
main{{max-width:1100px;margin:0 auto;padding:32px 20px 80px}}
h1{{font-size:2rem;margin:0 0 8px}}
.dek{{color:#a2968a;max-width:62ch}}
.pair{{display:grid;grid-template-columns:1fr 1.4fr;gap:12px}}
article{{margin:36px 0;padding:20px 0;border-top:1px solid #2a2431}}
img{{width:100%;height:auto;background:#1a171f}}
figcaption{{font:12px ui-monospace,monospace;color:#6e6459;margin-top:6px}}
h2{{margin:0 0 4px}}
.note{{color:#c6a15e;margin:0 0 12px}}
.fail{{opacity:.55}}
</style>
<main>
<h1>Keeper — D locked, boss pick</h1>
<p class="dek">Hearth D is the silhouette master. Boss A, C and D pass the alpha gate.
B is washed (84.9%). Recommended boss: <b>C</b> (inverted light actually lands on the left).</p>
{hearth}
{''.join(bosses)}
<div class="fail">{''.join(fails)}</div>
</main>
"""
    OUT.write_text(html)
    print(OUT, "bytes", OUT.stat().st_size)


if __name__ == "__main__":
    main()
