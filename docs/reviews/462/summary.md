# #462 — architectural vs asset classification

Reviewed against the 168-frame TestFlight `1.0.0 (4)` corpus (Godot `4.7.2.stable`, locale `en`, seeds `717` / `17634`, shipping shapes, all four zoom stops, opening and focused poses). This note classifies what the corpus shows. It does not propose generator, camera, material, asset, or layout work.

Owner-supplied TestFlight / device images were not provided. Desktop / Xvfb frames prove engine composition and replayability only. They are not iPhone GPU, safe-area, or TestFlight packaging proof.

## Clearly architectural

These defects follow from how production systems compose the map, not from a single mis-authored GLB:

- Straight road segments and scenery do not share a routing authority. Kits 0 and 1 are the pavement; remaining kits are scattered independently, so trees and mounds can stand on the slabs they do not know about (`F046`, `F032`).
- Node seats are repaired after scenery exists. `MapPinProjection.resolve` shoves pins off footprints and apart from neighbours, then clamps the shove. Occlusion and near-collisions remain when both constraints cannot hold (`F128`, `F007`).
- The 2D PathBand is always painted in front of the 3D world. Child order is `MapScene → path overlay → waystones → veil → chrome`. Dotted route state therefore threads through scenery the 3D road would hide (`F080`).
- Branch graph, 3D pavement, node medallions, and scenery scatter are decided by different systems. Edges can cross or merge on screen even when each system is locally consistent (`F008`).
- Density and negative space have no shared composition contract. Act I focused zoom-3 is overcrowded; Acts II–III leave large empty fog beside a tight node cluster (`F032`, `F080`, `F128`).

## Possibly still asset-related

These remain visible after the composition facts above. They might still need asset work in a later ticket; this packet does not change assets:

- Individual silhouettes are wide or tall enough to cover pavement and nodes even after seat repair (Y-fork trunks in Act I; large polygons in Act III) (`F046`, `F128`).
- The Vigil / hall does not read as a hero landmark under every legal camera profile in this matrix. Opening zoom-0 at `DEFAULT_XZ` does not frame it; focused zoom-3 puts it on the lower-left edge (`F001`, `F008`).
- Act IV resolved 3 of 8 kits and kept black placeholder cones, cubes, and discs, so species variety on the authored road is insufficient (`F152`).
- Repetition / stamping survives different seats: the same Act I Y-fork and mound read as copies, and Act IV placeholders repeat as a set (`F008`, `F152`).

## Not claimed

- No defect class is omitted. All nine rows in `defect-ledger.csv` are `OBSERVED` with a frame reference.
- Pixel-identical PNG hashes are not the acceptance contract across GPU / driver / font rasterisers. Repeatability is the byte-identical manifest and dimensions index on one pinned runner.
- This desktop / Xvfb corpus does not stand in for owner-supplied device images (`docs/reviews/462/device/`).
