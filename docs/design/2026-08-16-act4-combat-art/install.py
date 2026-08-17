#!/usr/bin/env python3
"""Key, measure and install #221 Act IV combat-art candidates.

Lossless RGB candidates stay in candidates/. This writes RGBA cutouts next to
them as *-cut.png (so measure.py can gate them) and copies the proposed picks
into assets/. James can swap a pick by editing PICKS and re-running.

    python3 docs/design/2026-08-16-act4-combat-art/install.py
"""
from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image

HERE = Path(__file__).parent
CANDIDATES = HERE / "candidates"
STAGE = HERE.parents[2] / "assets" / "art" / "stage"
ENEMIES = HERE.parents[2] / "assets" / "art" / "enemies"

# Proposed picks pending James. Backdrop-b is the asymmetric road (act1's left
# fragment language). Mid-b is one connected gate (act1-mid). Ledge-b shows a
# thick front face. Unwalked-self-a is the leaded-pane construction, inverted
# light from the left, broken halo.
PICKS = {
    "act4-backdrop": ("act4-backdrop-b", STAGE / "act4-backdrop.png", (1536, 1024)),
    "act4-mid": ("act4-mid-b", STAGE / "act4-mid.png", (1536, 1024)),
    "act4-ledge": ("act4-ledge-b", STAGE / "act4-ledge.png", None),
    "unwalkedSelf": ("unwalked-self-a", ENEMIES / "unwalkedSelf.png", "char"),
}

BLACK = 12  # max channel; generated voids are true (0,0,0)


def key_void(im: Image.Image) -> Image.Image:
    """Flood-fill near-black from every edge into alpha 0. Interior dark stone stays."""
    rgb = im.convert("RGB")
    w, h = rgb.size
    px = rgb.load()
    out = Image.new("RGBA", (w, h))
    dst = out.load()
    seen = bytearray(w * h)
    q: deque[tuple[int, int]] = deque()

    def is_void(x: int, y: int) -> bool:
        r, g, b = px[x, y]
        return r <= BLACK and g <= BLACK and b <= BLACK

    def push(x: int, y: int) -> None:
        i = y * w + x
        if seen[i]:
            return
        if not is_void(x, y):
            return
        seen[i] = 1
        q.append((x, y))

    for x in range(w):
        push(x, 0)
        push(x, h - 1)
    for y in range(h):
        push(0, y)
        push(w - 1, y)

    while q:
        x, y = q.popleft()
        if x > 0:
            push(x - 1, y)
        if x + 1 < w:
            push(x + 1, y)
        if y > 0:
            push(x, y - 1)
        if y + 1 < h:
            push(x, y + 1)

    for y in range(h):
        row = y * w
        for x in range(w):
            r, g, b = px[x, y]
            dst[x, y] = (r, g, b, 0 if seen[row + x] else 255)
    return out


def crop_opaque(im: Image.Image, pad: int = 0) -> Image.Image:
    bbox = im.getbbox()
    if bbox is None:
        return im
    l, t, r, b = bbox
    l = max(0, l - pad)
    t = max(0, t - pad)
    r = min(im.size[0], r + pad)
    b = min(im.size[1], b + pad)
    return im.crop((l, t, r, b))


def harden_alpha(im: Image.Image) -> Image.Image:
    """LANCZOS leaves a 1–239 fringe; cutouts in this tree are binary."""
    bands = list(im.split())
    a = bands[3].point(lambda p: 255 if p >= 128 else 0)
    bands[3] = a
    return Image.merge("RGBA", bands)


def fit_char(im: Image.Image) -> Image.Image:
    """Max-edge 1024, keep aspect, 15% margin by leaving the keyed void."""
    boxed = crop_opaque(im, pad=8)
    w, h = boxed.size
    scale = 1024 / float(max(w, h))
    if scale < 1.0:
        boxed = boxed.resize((max(1, int(w * scale)), max(1, int(h * scale))), Image.LANCZOS)
        boxed = harden_alpha(boxed)
    cw, ch = boxed.size
    canvas_h = 1024
    canvas_w = max(cw, int(round(canvas_h * cw / ch))) if ch else cw
    canvas_w = min(canvas_w, 1024)
    canvas = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    x = (canvas_w - cw) // 2
    y = canvas_h - ch
    canvas.paste(boxed, (x, y), boxed)
    return canvas


def fit_ledge(im: Image.Image) -> Image.Image:
    """Drop empty sky; keep 1536 wide like the shipped act 1–3 ledges."""
    boxed = crop_opaque(im, pad=4)
    w, h = boxed.size
    target_w = 1536
    scale = target_w / float(w)
    nh = max(1, int(round(h * scale)))
    return boxed.resize((target_w, nh), Image.LANCZOS)


def measure(im: Image.Image) -> tuple[float, list[int]]:
    alpha = im.getchannel("A")
    pix = list(alpha.getdata())
    nz = [a for a in pix if a > 0]
    ge = [a for a in nz if a >= 240]
    pct = (100.0 * len(ge) / len(nz)) if nz else 0.0
    w, h = im.size
    corners = [im.getpixel(c)[3] for c in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1))]
    return pct, corners


def process(src: Path, kind: object) -> Image.Image:
    keyed = key_void(Image.open(src))
    if kind == "char":
        return fit_char(keyed)
    if kind is None:
        return fit_ledge(keyed)
    return keyed.resize(kind, Image.LANCZOS)


def main() -> None:
    CANDIDATES.mkdir(exist_ok=True)
    print(f"{'file':22} {'size':11} {'≥240%':>7}  corners          dest")
    for shipped, (candidate, dest, kind) in PICKS.items():
        src = CANDIDATES / f"{candidate}.png"
        im = process(src, kind)
        cut = CANDIDATES / f"{candidate}-cut.png"
        im.save(cut, optimize=True)
        dest.parent.mkdir(parents=True, exist_ok=True)
        im.save(dest, optimize=True)
        pct, corners = measure(im)
        # Character cutouts need all four corners clear. Stage plates paint
        # the bottom edge, so only the top two (sky) must be transparent —
        # act1-backdrop's bottom centre is opaque stone, same as ours.
        top_clear = corners[0] == 0 and corners[1] == 0
        char = kind == "char"
        ok = pct >= 90.0 and (all(c == 0 for c in corners) if char else top_clear)
        print(
            f"{shipped:22} {im.size[0]}×{im.size[1]:<6} {pct:6.1f}%  "
            f"{str(corners):16} {'pass' if ok else 'FAIL'} -> {dest.relative_to(HERE.parents[2])}"
        )


if __name__ == "__main__":
    main()
