"""Author the Act I entrance threshold: the Vigil's rose window, west face.

Story, not invention. `docs/story/01-world.md`: the pilgrimage runs west to east
from 【守夜之爐 Vigil】, and 「彩窗與封門是同一道 threshold 的兩面」 -- the rose
window and the sealed door are two faces of ONE threshold. The west face is the
hearth-side rose window, and it has SIX compartments, because 「火在東面撞碎,
六片歸位嵌回西面六格」: the six shards return into its six panes. Six is load
bearing, not decoration. `assets/art/scenes/opening-hearth.png` -- the still the
player sees at the start of every run -- shows exactly that: six lobes around a
central boss.

Built the way the four termini were (`local-parametric-manifold`), not through
the Studio pipeline: one watertight manifold, welded and indexed, so the gate's
connected-component check is measuring something real rather than passing
because an unindexed mesh trivially returns 1.
"""
import json
import math
import struct
from pathlib import Path

import numpy as np
from manifold3d import Manifold

OUT = Path("/Users/jamesto/Coding/glassvow/.claude/worktrees/map-visual-design-70163b"
           "/assets/art/map/geometry/act1/threshold-rose-window.glb")

SEG = 28          # circular segments: low enough to read faceted, like the termini
WHEEL_R = 2.60
WHEEL_T = 0.52
WHEEL_Y = 3.05
LOBE_RING = 1.55  # centres of the six panes
LOBE_R = 0.62
EYE_R = 0.40


def cyl_z(height, radius, segments=SEG):
    """A cylinder down the Z axis, centred on the origin."""
    return Manifold.cylinder(height, radius, radius, segments, True)


def build() -> Manifold:
    # Plinth and its step. The wheel's rim dips into the plinth so the whole
    # piece is one solid, not three touching ones.
    plinth = Manifold.cube([7.2, 0.55, 1.50], True).translate([0.0, 0.275, 0.0])
    step = Manifold.cube([5.40, 0.34, 1.18], True).translate([0.0, 0.72, 0.0])

    # The wheel, with its six panes and its eye cut through.
    wheel = cyl_z(WHEEL_T, WHEEL_R).translate([0.0, WHEEL_Y, 0.0])
    moulding = cyl_z(WHEEL_T * 0.55, WHEEL_R + 0.18).translate([0.0, WHEEL_Y, 0.0])
    solid = wheel + moulding
    for i in range(6):
        # Panes start at the top and go round, so the six read as a rose rather
        # than as a ring of holes that happens to have six of them.
        a = math.pi * 0.5 + i * math.tau / 6.0
        solid -= cyl_z(WHEEL_T * 3.0, LOBE_R).translate(
            [LOBE_RING * math.cos(a), WHEEL_Y + LOBE_RING * math.sin(a), 0.0])
    solid -= cyl_z(WHEEL_T * 3.0, EYE_R).translate([0.0, WHEEL_Y, 0.0])

    piece = plinth + step + solid

    # Two flanking pylons, echoing the Act IV threshold's.
    for sx in (-1.0, 1.0):
        x = sx * 3.02
        piece += Manifold.cube([0.78, 0.42, 0.78], True).translate([x, 0.62, 0.0])
        piece += Manifold.cube([0.56, 3.05, 0.56], True).translate([x, 2.25, 0.0])
        cap = Manifold.cylinder(0.62, 0.40, 0.001, 4, True).rotate([-90.0, 0.0, 0.0])
        piece += cap.translate([x, 4.05, 0.0])
    return piece


def write_glb(verts: np.ndarray, norms: np.ndarray, tris: np.ndarray, path: Path) -> None:
    pos = verts.astype("<f4")
    nrm = norms.astype("<f4")
    idx = tris.astype("<u4").reshape(-1)
    blob = b"".join([pos.tobytes(), nrm.tobytes(), idx.tobytes()])
    pad = (4 - len(blob) % 4) % 4
    blob += b"\x00" * pad
    n_pos, n_nrm = pos.nbytes, nrm.nbytes
    gltf = {
        "asset": {"version": "2.0", "generator": "glassvow local-parametric-manifold"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"mesh": 0, "name": "ThresholdRoseWindow"}],
        "meshes": [{"name": "ThresholdRoseWindow", "primitives": [
            {"attributes": {"POSITION": 0, "NORMAL": 1}, "indices": 2, "mode": 4}]}],
        "accessors": [
            {"bufferView": 0, "componentType": 5126, "count": len(pos), "type": "VEC3",
             "min": [float(v) for v in pos.min(axis=0)],
             "max": [float(v) for v in pos.max(axis=0)]},
            {"bufferView": 1, "componentType": 5126, "count": len(nrm), "type": "VEC3"},
            {"bufferView": 2, "componentType": 5125, "count": len(idx), "type": "SCALAR"},
        ],
        "bufferViews": [
            {"buffer": 0, "byteOffset": 0, "byteLength": n_pos, "target": 34962},
            {"buffer": 0, "byteOffset": n_pos, "byteLength": n_nrm, "target": 34962},
            {"buffer": 0, "byteOffset": n_pos + n_nrm, "byteLength": idx.nbytes,
             "target": 34963},
        ],
        "buffers": [{"byteLength": len(blob)}],
    }
    js = json.dumps(gltf, separators=(",", ":")).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    total = 12 + 8 + len(js) + 8 + len(blob)
    out = struct.pack("<III", 0x46546C67, 2, total)
    out += struct.pack("<II", len(js), 0x4E4F534A) + js
    out += struct.pack("<II", len(blob), 0x004E4942) + blob
    path.write_bytes(out)


piece = build()
mesh = piece.to_mesh()
verts = np.asarray(mesh.vert_properties)[:, :3].astype(np.float64)
tris = np.asarray(mesh.tri_verts).astype(np.int64)

# Sit it on the ground: the gate wants POSITION min Y within [-0.001, 0.05].
verts[:, 1] -= verts[:, 1].min()

# Smooth normals over the welded vertices. Splitting them per face would read
# crisper, but it would also make every triangle its own island as far as the
# gate's component check is concerned, and that check is worth keeping honest.
norms = np.zeros_like(verts)
tri_n = np.cross(verts[tris[:, 1]] - verts[tris[:, 0]],
                 verts[tris[:, 2]] - verts[tris[:, 0]])
for k in range(3):
    np.add.at(norms, tris[:, k], tri_n)
lens = np.linalg.norm(norms, axis=1, keepdims=True)
norms = np.divide(norms, np.where(lens < 1e-12, 1.0, lens))

OUT.parent.mkdir(parents=True, exist_ok=True)
write_glb(verts, norms, tris, OUT)
lo, hi = verts.min(axis=0), verts.max(axis=0)
print(f"{OUT.name}: {len(tris)} triangles, {len(verts)} verts, {OUT.stat().st_size} bytes")
print(f"  bounds x {lo[0]:.2f}..{hi[0]:.2f}  y {lo[1]:.2f}..{hi[1]:.2f}  z {lo[2]:.2f}..{hi[2]:.2f}")
