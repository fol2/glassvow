# Shared fitted stone bridges — Step 3 study

The owner requested bridge surfaces, stairs and substantial feet, using the supplied multi-arch and single-arch stone-bridge images and [Creative Trio's bridge pack](https://creativetrio.art/2021/03/11/stone-bridges-pack-01/) as architectural references. No external model is imported.

The module receives fitted deck meshes, continuous surface queries and material/settings values. It does not know chapter IDs, encounter types, saves or generator state. Act II is the first integration. The woodland preset is a starting variation only; the approved Act I study is not migrated by this work.

- `profile.gd`: substantial solid pier intervals and elliptical intrados; crown thickness, arch spacing and pier width are configurable. Raised crossings use a complete segmental arch, qualified against the actual lower route.
- `outline.gd`: extracts the actual deck boundary and simplifies it within 2 cm before decoration. This avoids one masonry box per tiny grid edge.
- `edges.gd`: clips actual boundary runs at shared joins and entrances, and adds deck mouldings plus independently sampled intrados stones.
- `pointed_parapets.gd`: the owner-selected B design. Complete boundary runs are divided into two-opening arch bays, with solid short returns, capped posts and lofted continuous coping. Inclines use upright balusters. The current proportions are the selected Act II sample; other chapter proportions still require their own review.
- `verify_parapets.gd`: probes actual triangles for two open arches, solid mullions/sills/coping and correct surface orientation in both boundary directions.
- `piers.gd`: foundation shoes, pier buttresses and capped newels.
- `flight_grade.gd`: recognises sustained inclines (default trigger grade 0.22, eased shoulders down to 0.09) and fits a uniform grade before the deck is meshed, preserving both endpoint heights. Short rises and sharp turns remain outside the flight treatment.
- `stairs.gd`: complete flights with equal risers (maximum 0.17 m by default), horizontal hard-edged tops and closed risers. The fitted ramp remains structural fill; junctions and crossings are excluded and the whole flight must fit the deck footprint.
- `verify_stairs.gd`: actual mesh checks for gentle slopes, ascent, descent and curved-ramp grading, including horizontal normals and equal riser/tread dimensions. Mesh position comparisons account for 0.1 mm ArrayMesh quantisation.
- `presets.gd`: independent chapter proportions and material colours. City and woodland settings use the same component code.
- `masonry.gdshader` and `paving.gdshader`: shared world-space stone courses and flagstones, restrained block variation and waterline darkening. The Act II forecourt uses the same paving shader to preserve its road contact.

The caller combines its base deck and stair mesh as separate ArrayMesh surfaces for coverage and clearance probes. Indexed box treads must not be appended into the same SurfaceTool index stream as an unindexed fitted deck: only the indexed subset would remain addressable.

The Step 3 proof must include actual deck coverage, crossing-width clearance and the added rail/pier triangles across the walking corridor. A green check of the old deck alone does not establish that decorative masonry leaves the route open. Native near, whole-act, bridge-opening and phone/tablet views remain mandatory before owner review.

Current integration and investigation receipts are in `docs/map/studies/act2-step3/`. This module is under review and is not final production acceptance.
