"""Author the Vigil: the hall at the west end of the road, seen from outside.

WHAT THIS DELIBERATELY DOES NOT SHOW. An earlier version of this asset put the
rose window on the road-facing face. That was wrong twice over.

It was a spoiler. `docs/story/01-world.md` grades 「彩窗成鏡,隊伍現形」 as
**L3, the single reveal point**, and `docs/story/05-foreshadow-ledger.md` rule 2
says anything that discloses before its tier gets toned down or deferred. The
window's six panes are the shard count; standing them at the start of every run
hands the player an L3 fact at L0. That the fiction says the west face HAS six
compartments does not mean the player may SEE them yet -- the ledger exists to
keep those two apart, and row 10 shows the discipline: mirror.png ships as L0 art
whose meaning is withheld, 「資產不改,文案圍繞它寫」.

It was also the wrong side of the wall. 爐邊彩窗 -- the window is the HEARTH-side
face, turned in at the fire. From the road you stand outside it. What faces the
road is the hall's blank east gable and the door you walked out of.

So: a gabled hall seen end-on, blank gable, a shallow pointed doorway, and a
chimney with its smoke. The chimney is the one identity cue -- it says hearth,
which is what the place is named for, without saying window.

Built like the four termini (`local-parametric-manifold`), welded and indexed so
the gate's connected-component check is measuring something real.
"""
import json
import math
import struct
from pathlib import Path

import numpy as np
from manifold3d import CrossSection, Manifold

OUT = Path(__file__).resolve().parent.parent / (
    "assets/art/map/geometry/act1/vigil-hall.glb")

SEG = 24
LENGTH = 10.4     # west-east, the hall running back from the road
HALF_W = 3.10     # north-south half width
EAVES = 4.60
RIDGE = 7.60


def build() -> Manifold:
    # The end profile, in (across, up). Extruded along the hall's length, so the
    # walls and the pitched roof are one solid rather than a box wearing a hat.
    profile = [(-HALF_W, 0.0), (HALF_W, 0.0), (HALF_W, EAVES),
               (0.0, RIDGE), (-HALF_W, EAVES)]
    # extrude runs along +Z; the rotate swings that length onto +X, so the hall
    # already sits at x 0..LENGTH and needs no further move. Translating it
    # again is what left the plinth behind and split the piece into islands.
    hall = CrossSection([profile]).extrude(LENGTH).rotate([0.0, 90.0, 0.0])

    # A plinth course, so the hall meets the ground with a lip rather than a seam.
    hall += Manifold.cube([LENGTH + 0.5, 0.42, HALF_W * 2.0 + 0.5], True).translate(
        [LENGTH * 0.5, 0.21, 0.0])

    # Two shallow buttresses down the road-facing flank. They read at a distance
    # as a building rather than as an extruded shape.
    for k in (0.34, 0.70):
        hall += Manifold.cube([0.55, EAVES * 0.82, 0.45], True).translate(
            [LENGTH * k, EAVES * 0.41, HALF_W + 0.10])

    # The doorway: a pointed arch, cut as a RECESS and not a hole. A hole would
    # need an interior, and the gate refuses hidden internals.
    jamb = Manifold.cube([0.9, 2.05, 1.30], True).translate([0.30, 1.02, 0.0])
    head = Manifold.cylinder(1.30, 0.65, 0.001, 4, True).rotate([90.0, 0.0, 0.0])
    door = jamb + head.rotate([0.0, 0.0, 45.0]).translate([0.30, 2.05, 0.0])
    hall -= door

    # The chimney, and its smoke. The one thing on the piece that says hearth.
    stack = Manifold.cube([1.05, 2.60, 1.05], True).translate(
        [LENGTH * 0.76, RIDGE - 0.40, 0.0])
    cap = Manifold.cube([1.35, 0.30, 1.35], True).translate(
        [LENGTH * 0.76, RIDGE + 1.00, 0.0])
    hall += stack + cap

    # Smoke as geometry, since the map has no particles and no lights: a few
    # tapering lobes leaning downwind, each overlapping the last so the whole
    # piece stays one connected component.
    x = LENGTH * 0.76
    y = RIDGE + 1.15
    r = 0.62
    for i in range(5):
        hall += Manifold.sphere(r, SEG).translate([x, y, 0.0])
        step_x = 0.26 + 0.06 * i
        step_y = r * 1.15
        nxt = r * 0.90
        # The taper must not outrun the step, or the last lobe floats free and the
        # piece is two islands. It did: at 0.86 taper and a 0.10 drift the fifth
        # lobe cleared the fourth by 0.05 m, which the gate reads as a hidden
        # internal. Checked here rather than discovered in the gate.
        gap = math.hypot(step_x, step_y)
        assert gap < (r + nxt) * 0.94, f"smoke lobe {i} detaches: {gap:.3f} vs {r + nxt:.3f}"
        x += step_x
        y += step_y
        r = nxt
    return hall


def write_glb(verts: np.ndarray, norms: np.ndarray, tris: np.ndarray, path: Path) -> None:
    pos, nrm = verts.astype("<f4"), norms.astype("<f4")
    idx = tris.astype("<u4").reshape(-1)
    blob = pos.tobytes() + nrm.tobytes() + idx.tobytes()
    blob += b"\x00" * ((4 - len(blob) % 4) % 4)
    gltf = {
        "asset": {"version": "2.0", "generator": "glassvow local-parametric-manifold"},
        "scene": 0, "scenes": [{"nodes": [0]}],
        "nodes": [{"mesh": 0, "name": "VigilHall"}],
        "meshes": [{"name": "VigilHall", "primitives": [
            {"attributes": {"POSITION": 0, "NORMAL": 1}, "indices": 2, "mode": 4}]}],
        "accessors": [
            {"bufferView": 0, "componentType": 5126, "count": len(pos), "type": "VEC3",
             "min": [float(v) for v in pos.min(axis=0)],
             "max": [float(v) for v in pos.max(axis=0)]},
            {"bufferView": 1, "componentType": 5126, "count": len(nrm), "type": "VEC3"},
            {"bufferView": 2, "componentType": 5125, "count": len(idx), "type": "SCALAR"},
        ],
        "bufferViews": [
            {"buffer": 0, "byteOffset": 0, "byteLength": pos.nbytes, "target": 34962},
            {"buffer": 0, "byteOffset": pos.nbytes, "byteLength": nrm.nbytes, "target": 34962},
            {"buffer": 0, "byteOffset": pos.nbytes + nrm.nbytes,
             "byteLength": idx.nbytes, "target": 34963},
        ],
        "buffers": [{"byteLength": len(blob)}],
    }
    js = json.dumps(gltf, separators=(",", ":")).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(blob))
    out += struct.pack("<II", len(js), 0x4E4F534A) + js
    out += struct.pack("<II", len(blob), 0x004E4942) + blob
    path.write_bytes(out)


piece = build()
mesh = piece.to_mesh()
verts = np.asarray(mesh.vert_properties)[:, :3].astype(np.float64)
tris = np.asarray(mesh.tri_verts).astype(np.int64)
verts[:, 1] -= verts[:, 1].min()          # the gate wants POSITION min Y at ~0
verts[:, 0] -= verts[:, 0].max()          # gable (the road-facing end) at x = 0

norms = np.zeros_like(verts)
face = np.cross(verts[tris[:, 1]] - verts[tris[:, 0]], verts[tris[:, 2]] - verts[tris[:, 0]])
for k in range(3):
    np.add.at(norms, tris[:, k], face)
lens = np.linalg.norm(norms, axis=1, keepdims=True)
norms = np.divide(norms, np.where(lens < 1e-12, 1.0, lens))

OUT.parent.mkdir(parents=True, exist_ok=True)
write_glb(verts, norms, tris, OUT)
lo, hi = verts.min(axis=0), verts.max(axis=0)
print(f"{OUT.name}: {len(tris)} triangles, {len(verts)} verts, {OUT.stat().st_size} bytes")
print(f"  x {lo[0]:.2f}..{hi[0]:.2f}   y {lo[1]:.2f}..{hi[1]:.2f}   z {lo[2]:.2f}..{hi[2]:.2f}")
