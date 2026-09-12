# Act I painted surface sources

Generated on 5 September 2026 using the built-in image generator, with the
approved `docs/map/concepts/act1-combat-aligned-v2.png` as the palette reference.
These are new workshop sources; they have not been accepted for production.

- `conifer-sprays.png`: four charcoal conifer twig silhouettes on transparent
  quadrants. Source output `exec-8f5ae6be-0bba-4d80-98d2-8fb63a6f0342.png`.
- `ash-twigs.png`: four muted crimson/plum leafy twigs on transparent quadrants.
  Source output `exec-51a36f72-bcd9-46f6-aff0-5c493e2ac7a0.png`.
- `ash-stone-colour.png`: quiet broad mineral colour patches, without masonry,
  cracks or directional shadows. Source output
  `exec-d288e711-6dfd-4128-8aa3-44df87a90b0e.png`.

Both foliage images have native RGBA transparency. `foliage.py` maps each
quadrant onto curved cards among dimensional woody branches. The joined mesh
must preserve leaf coordinates in the first UV layer; the builder asserts this.
The native workshop prepares recognised foliage surfaces for alpha scissor and
MSAA coverage. Gallery captures inspect both forward and reverse orientations.

`stone_finish.py` applies the mineral image only to original stone props, with
world-sized planar coordinates. It is not the map ground texture. This is a
colour source, not a normal map or a baked-light source; seamless tiling has
not been independently qualified.
