#!/usr/bin/env python3
"""Key, measure and install #221 Act IV combat-art candidates.

Lossless RGB candidates stay in candidates/. This writes RGBA cutouts next to
them as *-cut.png (so measure.py can gate them) and copies the signed picks
into assets/. Swap a pick by editing PICKS and re-running.

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

# James picked plates + unwalkedSelf on 2026-08-17 (#221). The other selves
# are proposed pending James.
PICKS = {
    "act4-backdrop": ("act4-backdrop-c", STAGE / "act4-backdrop.png", (1536, 1024)),
    "act4-mid": ("act4-mid-c", STAGE / "act4-mid.png", (1536, 1024)),
    "act4-ledge": ("act4-ledge-b", STAGE / "act4-ledge.png", None),
    "unwalkedSelf": ("unwalked-self-d", ENEMIES / "unwalkedSelf.png", "char"),
    "uncrossedSelf": ("uncrossed-self-b", ENEMIES / "uncrossedSelf.png", "char"),
    "unopenedSelf": ("unopened-self-a", ENEMIES / "unopenedSelf.png", "char"),
    "unlitSelf": ("unlit-self-b", ENEMIES / "unlitSelf.png", "char"),
    "unsunkSelf": ("unsunk-self-a", ENEMIES / "unsunkSelf.png", "char"),
}

BLACK = 16  # max channel for plate voids
ENCLOSED_MAGENTA = 200  # arm-gap blobs; gem sparkles stay


def is_bg_magenta(r: int, g: int, b: int) -> bool:
    """Generator field is ~ (248, 4, 247), never true black, never purple glass."""
    return min(r, b) >= 180 and g <= 60 and abs(r - b) <= 50


def is_magenta_fringe(r: int, g: int, b: int) -> bool:
    """Anti-aliased magenta/figure mix. Bright enough that a void hood cannot match."""
    if min(r, b) < 140 or g > 70:
        return False
    d_mag = (r - 255) ** 2 + g * g + (b - 255) ** 2
    d_blk = r * r + g * g + b * b
    return d_mag < d_blk


def _flood_void(px: object, w: int, h: int, predicate: object, seeds: object) -> bytearray:
    seen = bytearray(w * h)
    q: deque[tuple[int, int]] = deque()

    def push(x: int, y: int) -> None:
        i = y * w + x
        if seen[i]:
            return
        r, g, b = px[x, y]
        if not predicate(r, g, b):
            return
        seen[i] = 1
        q.append((x, y))

    for x, y in seeds:
        push(x, y)
    while q:
        x, y = q.popleft()
        if x:
            push(x - 1, y)
        if x + 1 < w:
            push(x + 1, y)
        if y:
            push(x, y - 1)
        if y + 1 < h:
            push(x, y + 1)
    return seen


def _apply_void(rgb: Image.Image, void: bytearray) -> Image.Image:
    w, h = rgb.size
    px = rgb.load()
    out = Image.new("RGBA", (w, h))
    dst = out.load()
    for y in range(h):
        row = y * w
        for x in range(w):
            r, g, b = px[x, y]
            dst[x, y] = (r, g, b, 0 if void[row + x] else 255)
    return out


def key_void(im: Image.Image) -> Image.Image:
    """Flood-fill near-black from every edge. Interior dark stone stays."""
    rgb = im.convert("RGB")
    w, h = rgb.size
    px = rgb.load()
    seeds = [(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)]
    seeds += [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)]

    def pred(r: int, g: int, b: int) -> bool:
        return r <= BLACK and g <= BLACK and b <= BLACK

    return _apply_void(rgb, _flood_void(px, w, h, pred, seeds))


def key_magenta(im: Image.Image) -> Image.Image:
    """Magenta field → alpha 0. Black hood stays: it is not magenta.

    Exterior flood first (magenta + bright fringe). Then punch enclosed
    magenta blobs large enough to be arm-gaps, without expanding them into
    neighbouring purple glass.
    """
    rgb = im.convert("RGB")
    w, h = rgb.size
    px = rgb.load()
    mag = bytearray(w * h)
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            if is_bg_magenta(r, g, b):
                mag[y * w + x] = 1
    seeds = [(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)]
    seeds += [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)]

    def pred(r: int, g: int, b: int) -> bool:
        return is_bg_magenta(r, g, b) or is_magenta_fringe(r, g, b)

    void = _flood_void(px, w, h, pred, seeds)
    seen = bytearray(w * h)
    for y in range(h):
        for x in range(w):
            i = y * w + x
            if not mag[i] or void[i] or seen[i]:
                continue
            q: deque[tuple[int, int]] = deque([(x, y)])
            seen[i] = 1
            cells: list[tuple[int, int]] = [(x, y)]
            while q:
                cx, cy = q.popleft()
                for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
                    if nx < 0 or ny < 0 or nx >= w or ny >= h:
                        continue
                    j = ny * w + nx
                    if seen[j] or not mag[j] or void[j]:
                        continue
                    seen[j] = 1
                    q.append((nx, ny))
                    cells.append((nx, ny))
            if len(cells) >= ENCLOSED_MAGENTA:
                for cx, cy in cells:
                    void[cy * w + cx] = 1
    return _apply_void(rgb, void)


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
    boxed = crop_opaque(im, pad=4)
    w, h = boxed.size
    target_w = 1536
    scale = target_w / float(w)
    nh = max(1, int(round(h * scale)))
    return boxed.resize((target_w, nh), Image.LANCZOS)


def leftover_magenta(im: Image.Image) -> int:
    w, h = im.size
    px = im.load()
    n = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a and is_bg_magenta(r, g, b):
                n += 1
    return n


def margin_dark(im: Image.Image, band: int = 8) -> int:
    """Opaque near-black in the canvas frame — the boxed-sprite failure."""
    w, h = im.size
    px = im.load()
    n = 0
    for y in range(h):
        for x in range(w):
            if x >= band and y >= band and x < w - band and y < h - band:
                continue
            r, g, b, a = px[x, y]
            if a and max(r, g, b) <= 24:
                n += 1
    return n


def measure(im: Image.Image) -> tuple[float, list[int], int, int]:
    alpha = im.getchannel("A")
    pix = list(alpha.getdata())
    nz = [a for a in pix if a > 0]
    ge = [a for a in nz if a >= 240]
    pct = (100.0 * len(ge) / len(nz)) if nz else 0.0
    w, h = im.size
    corners = [im.getpixel(c)[3] for c in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1))]
    return pct, corners, leftover_magenta(im), margin_dark(im)


def process(src: Path, kind: object) -> Image.Image:
    raw = Image.open(src)
    if kind == "char":
        return fit_char(key_magenta(raw))
    keyed = key_void(raw)
    if kind is None:
        return fit_ledge(keyed)
    return keyed.resize(kind, Image.LANCZOS)


def main() -> None:
    CANDIDATES.mkdir(exist_ok=True)
    print(f"{'file':22} {'size':11} {'≥240%':>7}  mag  mdark  corners          dest")
    for shipped, (candidate, dest, kind) in PICKS.items():
        src = CANDIDATES / f"{candidate}.png"
        im = process(src, kind)
        cut = CANDIDATES / f"{candidate}-cut.png"
        im.save(cut, optimize=True)
        dest.parent.mkdir(parents=True, exist_ok=True)
        im.save(dest, optimize=True)
        pct, corners, mag, mdark = measure(im)
        top_clear = corners[0] == 0 and corners[1] == 0
        char = kind == "char"
        ok = pct >= 90.0 and (all(c == 0 for c in corners) if char else top_clear)
        if char:
            ok = ok and mag < 32 and mdark < 400
        print(
            f"{shipped:22} {im.size[0]}×{im.size[1]:<6} {pct:6.1f}%  "
            f"{mag:4d} {mdark:5d}  {str(corners):16} "
            f"{'pass' if ok else 'FAIL'} -> {dest.relative_to(HERE.parents[2])}"
        )


if __name__ == "__main__":
    main()
