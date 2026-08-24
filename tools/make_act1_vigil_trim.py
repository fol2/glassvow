"""The Vigil's trim sheet: one texture whose V axis IS the building's height.

Why a trim sheet and not an unwrap. A real unwrap needs seams; seams split
vertices; and split vertices read to `map_asset_checks._connected_components` as
disconnected islands, which is the check that catches hidden internals. Rather
than weaken that check, the mesh keeps welded topology and takes UVs that need
no seams at all: V is world height over the building's height, U is whichever
horizontal axis the face points away from. Height means the same thing on every
surface, so the bands below land where they should without any face needing to
be cut out of the sheet.

U repeats, V does not. Everything the eye reads as "this is a building" -- the
plinth course, the coursed wall, the corbel under the eaves, the slate above --
is a horizontal band, which is exactly what V buys.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))

W = H = 512
OUT = Path(__file__).resolve().parent.parent / (
    "assets/art/map/materials/act1-vigil-trim.png")

rng = np.random.default_rng(1174)
u = (np.arange(W) + 0.5) / W          # around the building, repeating
v = (np.arange(H) + 0.5) / H          # 0 at the ground, 1 at the ridge
U, V = np.meshgrid(u, v)

# Bands, bottom to top. Kept as fractions of the height so the sheet survives
# the model being re-proportioned.
from vigil_bands import PLINTH, WALL_TOP, CORBEL, ROOF_TOP  # noqa: E402


def courses(rows: float, offset: float, jitter: float) -> np.ndarray:
    """Ashlar: horizontal beds, every other course shifted half a block."""
    row = V * rows
    band = np.floor(row)
    stagger = (band % 2.0) * 0.5
    col = np.floor(U * 9.0 + stagger + offset)
    key = np.sin(band * 12.9898 + col * 78.233) * 43758.5453
    tone = (key - np.floor(key)) * jitter
    bed = np.minimum(np.abs(row - np.round(row)), 0.5) * 2.0
    joint = np.clip(bed * 7.0, 0.0, 1.0)
    seam = np.abs((U * 9.0 + stagger + offset) % 1.0 - 0.5) * 2.0
    joint = np.minimum(joint, np.clip(seam * 9.0, 0.0, 1.0))
    return tone, joint


val = np.zeros_like(V)

# Plinth: fewer, heavier blocks, and darker so the hall sits down on the ground.
tone, joint = courses(2.0, 0.31, 0.22)
plinth = 0.24 + tone + joint * 0.40
val = np.where(V < PLINTH, plinth, val)

# Wall: the main ashlar field.
tone, joint = courses(9.0, 0.0, 0.30)
wall = 0.52 + tone + joint * 0.44
val = np.where((V >= PLINTH) & (V < WALL_TOP), wall, val)

# Corbel band under the eaves: a run of small blocks, brighter, to catch the eye
# where the roof meets the wall.
tone, joint = courses(2.0, 0.17, 0.14)
corbel = 0.92 + tone * 0.5 + joint * 0.20
val = np.where((V >= WALL_TOP) & (V < CORBEL), corbel, val)

# Roof: slate, laid in finer rows and darker than the stone so the silhouette
# reads roof-over-wall at a distance rather than one grey mass.
row = (V - CORBEL) / max(ROOF_TOP - CORBEL, 1e-6) * 13.0
band = np.floor(row)
col = np.floor(U * 13.0 + (band % 2.0) * 0.5)
key = np.sin(band * 31.7 + col * 17.3) * 9137.17
slate = 0.10 + (key - np.floor(key)) * 0.13
lip = np.clip(np.abs(row - np.round(row)) * 5.0, 0.0, 1.0)
val = np.where(V >= CORBEL, slate + lip * 0.16, val)

# Above the ridge is smoke, so the top of the sheet is soft and pale rather
# than another course of anything.
smoke = 0.58 + (rng.random((H, W)) - 0.5) * 0.10
val = np.where(V >= ROOF_TOP, smoke, val)

# A little grain over everything, so flat faces are not dead flat.
val += (rng.random((H, W)) - 0.5) * 0.035
val = np.clip(val, 0.0, 1.0)

# Cool stone, warmer as it climbs toward the smoke — the one hint that something
# is burning inside, without drawing light the unshaded map cannot justify.
warm = np.clip((V - 0.55) / 0.45, 0.0, 1.0) * 0.06
rgb = np.dstack([
    np.clip(val * (0.94 + warm * 1.8), 0.0, 1.0),
    np.clip(val * (0.96 + warm * 0.9), 0.0, 1.0),
    np.clip(val * 1.04, 0.0, 1.0),
])
OUT.parent.mkdir(parents=True, exist_ok=True)
Image.fromarray(np.rint(rgb * 255).astype(np.uint8)).save(OUT)
print(f"{OUT.name}: {W}x{H}, mean {val.mean():.3f}, {OUT.stat().st_size} bytes")
