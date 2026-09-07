# Shared native map study components

These components support chapter studies. They do not own encounters, saves or
campaign progression. Chapter profiles opt into their capabilities; adoption does
not authorise changing an already approved chapter's composition.

| Capability | Contract and owner |
| --- | --- |
| Generated terraces | `presentation/map/map_spatial_profile.gd` resolves stations and levels from a supplied recipe. Existing compiler inputs without a spatial profile retain the lattice route. |
| Walking construction | `resolved_route_surface.gd` resolves level runs and flights; `resolved_flight.gd` owns treads, risers and landings. `walking_surface_union.gd` removes overlapping walking faces before `flight_mesh.gd` builds the mesh. |
| Court contact | `court_surface.gd` subtracts the resolved walking masks from court patches. It must consume the same plans used for the walking mesh. |
| Landscape | `landscape_relief.gd` supplies deterministic `height_at`, reserve-relative broad landforms and the corresponding mesh. Optional faceting changes normals, not contact geometry. |
| Architecture | `architectural_occupancy.gd` uses transformed mesh bounds, swept route widths and building overlap checks. `workshop_hero_binding.gd` binds a generated hero reserve to the actual asset hash and transform. |
| Passage foundations | `passage_masonry.gd` clips supports outside the lower route. It receives both routes and the deck depth; it does not infer chapter IDs or water levels. |
| Surface treatment | `precinct_stone.gdshader` uses quiet world-space courses by default. Model-space architectural courses and the ceremonial inlay are explicit options. No vertex displacement is applied. |
| Inspection | `inspection.gd` retains chapter labels and control/marker size defaults. `overview_groups.gd` groups overlapping targets; `route_travel.gd` bounds linear and angular speed without advancing game state. |
| Visibility | `precinct_sightlines.gd` tests cached rendered triangles. `route_camera_heading.gd` selects and validates camera headings. Their receipts distinguish samples from continuous playback. |
| Evidence | `threshold_mesh_audit.gd` checks actual walking and overhead triangles. Covered passages require overhead samples; open-air mode still requires non-zero walking samples and rejects obstructions. `viewport_profile.gd` reports native timing availability explicitly. |

The shared toon water module and stone bridge kit remain under the existing
`water/` and `stone_bridge/` directories alongside `common/`. Reuse their profiles
for river, sunken city and later chapters rather than copying their implementations.

Act III owns its Gothic kit, palette, generated region recipe, terrain parameters,
sovereign halo and scene composition in `act3/`. The precinct capture entry point
is `act3/precinct_study.gd`; `act3/capture_precinct.py` creates a fresh reference
matrix without overwriting previous candidates. Its default sample paths are
local generation outputs; generated samples are copied into the review artefacts.

Evidence limits matter: sampled width and visibility do not prove every point of
a continuous surface; a desktop viewport does not qualify a physical phone; a
zero GPU timer does not mean zero GPU work. Keep these distinctions in delivery.
