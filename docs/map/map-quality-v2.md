# Map Compiler v2 quality contract

Status: **version 2.0.0, #462 visual baseline bound; quantitative owner calibration pending**  
Machine authority: [`map-quality-v2.json`](map-quality-v2.json)  
Validator: `python3 -B tools/check_map_quality_v2.py`

This contract turns the owner direction in #461 into measurable rules for every later Map Compiler v2 ticket. It defines feasibility, composition scoring, and visual hierarchy only. It does not place a node, route an edge, move a camera, change an asset, or switch production rendering.

The transfer from AFK Journey is **coherent regional mass, landmark framing, readable travel structure, and authored negative space**. It is not an instruction to copy, trace, or reverse-engineer its assets, map, UI, or proportions.

## 1. Evaluation order and evidence

A candidate is evaluated in two stages:

1. **Hard feasibility.** Every hard constraint passes at every governed shipping profile. One violation makes the layout infeasible.
2. **Soft composition.** Only feasible candidates receive a weighted composition total.

The evidence record must retain:

- every raw hard measurement and violating entity/profile ID;
- every raw soft measurement, before normalisation;
- every normalised soft component;
- every explicit `not_applicable` component and the rule that produced it;
- the initial weight vector and weighted total;
- the input, layout, asset-profile, camera-profile, quality-registry, and generator identities.

A weighted total is never calculated as a way to excuse a hard failure. The selector in #471 may compare feasible candidates with

```text
soft_total = Σ(normalised_component_i × initial_weight_i)
```

but it must preserve the complete raw vector. A future weight change is a versioned registry change, not a private implementation constant.

When a soft component's governed empty policy returns `not_applicable`, #471 excludes that component and renormalises the remaining initial weights to sum to 1.0 for that candidate. This is permitted only for the exact registry cases, such as a graph with no decision branch or a legal single-node layout with no routed edges. A missing required entity, profile, denominator, or evidence sample is an `evidence_error`; it is not silently converted to `not_applicable` or zero.

## 2. Units, epsilon, and governed profiles

World geometry is measured in metres on the Godot XZ ground plane. Screen geometry is measured in stage pixels after projection into the selected shipping reference. Touch geometry is the interactive `Control` hit region, not the smaller visible pane.

The canonical machine unit tokens are:

- `m` — world-space distance;
- `px` — projected stage-pixel distance;
- `px2` — projected stage-pixel area;
- `deg` — angle;
- `deg_per_edge` — angle aggregate divided by routed-edge count;
- `count` — integer event/entity count;
- `ratio` — dimensionless ratio.

These spaces must not be collapsed into one radius:

- **world clearance** protects road, node, hero, and scenery occupancy;
- **projected ink clearance** protects what the player can see;
- **touch safety** protects what the player can select.

Numerical contact is governed centrally by `world_m = 0.001`, `screen_px = 0.25`, and `ratio = 0.000001`. A post-epsilon penetration is a violation; implementations may not scatter larger local tolerances.

The governed profile set is the Cartesian expansion owned by #466:

- `pad-landscape` 1180×820, `desktop-landscape` 1458×820, and `phone-landscape` 844×390;
- orthographic zoom stops 12, 16, 20, and 28 m;
- opening pose, `pose_leading` for every occupied row, pan bounds, and pan corners;
- shipping tilt −40°, camera height 18 m, and stage flex cap 0.12.

A layout that passes only the pad reference, one zoom stop, seed 717, or one preferred camera pose does not pass this contract.

## 3. Hard feasibility: zero violation budget

“Zero tolerance” means the measured violation after the governed epsilon is exactly zero over the release corpus. A provisional positive floor may still define how much clear space is required; the permission to violate it remains zero.

| ID | Pass rule | Measurement and later owner |
| --- | --- | --- |
| `node_ink_clearance_px` | minimum ≥ **8 px** *(provisional)* | Signed projected gap from waystone ink to every other node/scenery/hero silhouette, every profile. #466. |
| `node_touch_target_min_px` | width and height ≥ **44 px** | Shipping accessibility floor from `GlassWaystone.set_touch_min` and phone `LayoutBook` data. #466. |
| `node_touch_overlap_area_px2` | maximum = **0 px²** | Distinct hit regions may not overlap after epsilon; one screen point cannot name two nodes. #466. |
| `node_touch_scenery_silhouette_overlap_area_px2` | maximum = **0 px²** | Touch-safety region versus ordinary scenery silhouette. #466, consumed by #470. |
| `node_touch_hero_silhouette_overlap_area_px2` | maximum = **0 px²** | Touch-safety region versus Vigil/terminus silhouette. #466. |
| `node_node_ink_overlap_area_px2` | maximum = **0 px²** | Pairwise projected waystone ink intersection. #466. |
| `node_scenery_silhouette_overlap_area_px2` | maximum = **0 px²** | Waystone ink versus ordinary scenery silhouette. #466, consumed by #470. |
| `node_hero_silhouette_overlap_area_px2` | maximum = **0 px²** | Waystone ink versus Vigil/terminus silhouette. #466. |
| `edge_scenery_corridor_penetration_m` | maximum = **0 m** | Routed corridor versus scenery/hero occupancy after inflation. Single-edge geometry #468; scenery #470; evaluator #466. |
| `edge_nonendpoint_node_penetration_m` | maximum = **0 m** | Endpoint capture is the only node exception. #466/#468. |
| `unrelated_edge_intersection_count` | count = **0** | Proper crossing, positive-length collinear overlap, or corridor-area overlap between edges without a shared graph endpoint. #469. |
| `branch_fanout_separation_px` | minimum ≥ **32 px** at 4 m *(provisional)* | Alternatives may share at most 1 m of deliberate departure, then must clear the screen-space floor in every profile. #469. |
| `row_lane_envelope_excess_m` | maximum = **0 m** | Anchor outside its row/lane envelope. The envelope dimensions are provisional; permission to exceed them is immutable zero. #467. |
| `journey_order_reversal_count` | count = **0** | Every directed edge advances at least 0.25 m along +X. #467. |
| `vigil_protected_zone_intrusion_count` | count = **0** | Unapproved occupancy inside the Vigil profile plus 2.5 m / 16 px reserves *(reserve provisional)*. #470, measured by #466. |
| `terminus_protected_zone_intrusion_count` | count = **0** | Unapproved occupancy inside a terminus profile plus 3 m / 20 px reserves *(reserve provisional)*. #470, measured by #466. |
| `focused_node_safe_frame_margin_px` | minimum ≥ **8 px** *(provisional)* | Complete focused touch region to safe-frame boundary in focused and pan-boundary profiles. #466. |
| `deterministic_identity_mismatch_count` | count = **0** | Equivalent semantic input must agree on all canonical digests and output identity. #464; release corpus #476. |

### 3.1 Ink, touch, and collision are different tests

The visible unlit waystone pane has a 28 px radius. The phone hit region is independently grown to at least 44×44 px. Therefore:

- an asset can clear a world footprint but still hide projected ink or occupy the node’s touch-safety reserve;
- two ink discs can look separate while their hit regions overlap ambiguously;
- a large touch target does not enlarge the painted node silhouette;
- passing any one test does not imply the other two pass.

`node_ink_clearance_px` is a signed boundary gap, not centre distance. The two touch/silhouette metrics independently test the complete interactive region against ordinary and hero silhouettes; ink clearance does not imply touch clearance. Collision-area constraints report the actual clipped polygon intersection, not a shared circular approximation.

### 3.2 Edge corridor

The initial routed-road profile is provisional:

```text
physical road half-width = 1.25 m
world safety clearance   = 0.35 m
reserved sweep radius    = 1.60 m
waylight maximum width   = 0.22 × physical road width
```

#468 inflates supplied polygonal obstacles by the physical half-width plus world clearance. #469 applies the same corridor to previously accepted unrelated edges. #470 places scenery only after these corridors exist. Rendering or smoothing may not cut inside the validated centreline corridor.

### 3.3 Branch fan-out and convergence

A branch is derived from graph topology, never inferred from lines that happen to be close. Alternatives from one source may use a deliberate common departure for at most 1.0 m. At 4.0 m route progress from the source, every pair must be at least 32 px apart in every governed profile. They may converge later only when:

- their graph topology actually merges at a shared target; or
- they remain separated corridors with unambiguous continuation to different targets.

Collinear overlap between unrelated alternatives is not bundling; it is a hard violation.

### 3.4 Row/lane envelope and journey order

The shipping lattice is 15×7, journeying along +X with cells 5.142857 m × 6 m. The first provisional candidate envelope is:

```text
row half-extent  = 2.057142857 m
lane half-extent = 2.4 m
minimum directed forward progress = 0.25 m
```

The envelope is deliberately broader than authored jitter (±0.20 row, ±0.25 lane) so #467 can solve in both axes, yet leaves a gap before the neighbouring authored row/lane. Zero envelope excess and zero order reversals are immutable; the positive envelope dimensions require owner review.

### 3.5 Hero protected zones

The authoritative footprint comes from #465. A protected zone is that footprint inflated in world space plus a projected framing reserve. It is not a guessed circle and it is not ordinary scenery clearance.

The endpoint road, approved entrance/terminus node, and explicitly authored landmark companions may be whitelisted by stable IDs. Everything else is an intrusion. Whitelists are data in the later contract/result, never “closest object” heuristics.

### 3.6 Deterministic identity

#464 owns canonical input/result bytes and digests. The hard rule applies to the tuple:

```text
graph topology + act + run/scenery seed + generator version
+ asset/profile digest + camera-profile digest + this registry digest
```

Dictionary insertion order, engine object IDs, scene-tree order, and unrelated RNG consumption are forbidden identity sources. A replay mismatch is not a visual score penalty; it is infeasible.

### 3.7 Empty and degenerate hard samples

The registry fixes empty-set handling so evaluators do not invent their own vacuous-pass rules:

- a maximum or count over an empty comparison set emits numeric `0`;
- `branch_fanout_separation_px` is the only optional hard minimum: a graph with no decision branch emits explicit `not_applicable` and passes that metric;
- `node_ink_clearance_px`, `node_touch_target_min_px`, and `focused_node_safe_frame_margin_px` require samples; missing nodes, focused profiles, or required comparison geometry is an `evidence_error`;
- deterministic identity requires at least two equivalent evaluations; fewer samples are an `evidence_error`, not a mismatch count of zero.

Every `not_applicable` or evidence error remains visible in the raw report. It may not be omitted from serialised evidence.

## 4. Soft composition score

Every normalisation maps its raw value to `[0, 1]` with a clamped linear transform. For `higher_is_better`, the stated best value maps to 1 and worst to 0; `lower_is_better` reverses that mapping. All anchors and weights below are provisional until calibrated against #462 and owner review.

| ID | Raw unit / direction | Best → worst | Weight | Why it exists / owner |
| --- | --- | --- | ---: | --- |
| `route_length_ratio` | ratio, lower | 1.00 → 1.55 | 0.09 | Avoid arbitrary detours. #468. |
| `bend_angle_deg_per_edge` | degrees/edge, lower | 12 → 110 | 0.07 | Prefer deliberate roads over repair zig-zags. #468. |
| `branch_separation_margin_px` | px, higher | 48 → 0 | 0.14 | Reward readability beyond the hard floor. #469. |
| `route_state_exposure_ratio` | ratio, higher | 0.85 → 0.45 | 0.14 | Keep enough depth-correct waylight visible to follow. #466/#473. |
| `landmark_framing_margin_px` | px, higher | 48 → 8 | 0.10 | Let hero landmarks establish place and destination. #470. |
| `zone_density_error_ratio` | ratio, lower | 0 → 0.35 | 0.10 | Prevent one uniform scatter across unlike zones. #470. |
| `negative_space_error_ratio` | ratio, lower | 0 → 0.40 | 0.10 | Preserve authored breathing room and sight lines. #470. |
| `asset_family_diversity_ratio` | ratio, higher | 0.75 → 0.30 | 0.06 | Use the available regional vocabulary. #470. |
| `asset_repetition_distance_m` | m, higher | 18 → 6 | 0.06 | Keep repeated families from stamping along the route. #470. |
| `stamping_symmetry_ratio` | ratio, lower | 0.05 → 0.45 | 0.05 | Penalise unexplained mirrored/repeated transforms. #470. |
| `node_displacement_rms_m` | m, lower | 0 → 2.0 | 0.05 | Preserve authored node intent after legality is solved. #471. |
| `camera_profile_consistency_ratio` | ratio, higher | 0.95 → 0.65 | 0.04 | Reject “good only on pad/one zoom” composition. #466. |

The precise raw formulas and aggregations are authoritative in the JSON registry. Notable rules:

- route length is a ratio of total routed length to total direct endpoint distance;
- bend economy uses absolute interior turn angle, not polyline point count;
- route-state exposure uses visible projected centreline length after depth/silhouette occlusion;
- family diversity uses effective Shannon family count divided by legal available families;
- stamping excludes explicitly authored symmetry tags;
- camera consistency is the weakest profile subscore divided by the strongest and excludes itself to avoid recursion.

### 4.1 Empty and degenerate soft samples

The registry's per-metric `empty_policy` is part of the score definition:

- a legal zero-edge layout marks `route_length_ratio`, `bend_angle_deg_per_edge`, and `route_state_exposure_ratio` `not_applicable`; the selector excludes them and renormalises the remaining initial weights;
- when routed edges exist, a non-positive direct-distance or projected-length denominator is an `evidence_error`; no governed landmark, no nodes, or fewer than two camera profiles is also an `evidence_error`;
- a graph with no decision branches marks `branch_separation_margin_px` `not_applicable`, then the selector excludes it and renormalises the remaining initial weights;
- zero-legal-area scenery zones and zero-area negative-space reservations are excluded from their area-weighted aggregate; if every item is excluded, the metric is an `evidence_error`;
- zero available asset families is an `evidence_error`; zero placed ordinary assets produces raw diversity `0`;
- fewer than two same-family ordinary instances gives `asset_repetition_distance_m` its raw best value;
- zero ordinary placements gives `stamping_symmetry_ratio = 0`;
- when every per-profile subscore is zero, `camera_profile_consistency_ratio = 1`; this rewards consistency only, while the other raw components still record the poor composition.

No metric is named “looks good”. Each has a unit, formula, direction, aggregation, normalisation, empty policy, owner, and rationale.

## 5. Visual grammar

The fixed hierarchy is:

1. **regional world and landmark** — coherent terrain mass and one dominant regional/goal anchor;
2. **permanent physical road** — neutral topology readable without state colour;
3. **narrow depth-tested waylight** — open/walked/current state inside the world;
4. **waystones and interaction** — unmistakable node identity and touch safety;
5. **chrome** — labels, HUD, and other screen UI subordinate to the world.

Four renderer invariants follow:

- the physical road must remain readable with route-state colour removed;
- state colour must not recolour the whole paving slab;
- a 2D route overlay is forbidden as production route authority;
- the waylight must participate in normal 3D depth testing. Real foreground scenery may occlude a local marker; the compiler must preserve enough other exposure rather than disabling depth.

### 5.1 Accepted and rejected route hierarchy

Accepted — world mass frames a neutral physical road; a narrow in-world state channel sits on it and can pass behind foreground geometry:

```text
        REGIONAL MASS / LANDMARK
      ┌─────────────────────────┐
      │       [VIGIL]           │
      └──────────┬──────────────┘
                 │
        ═══════════════════      permanent neutral road
          ·  ·  ·  ·  ·         narrow depth-tested waylight
             ○       ○          waystones, clear of silhouettes
        [chrome remains last]
```

Rejected — state becomes the road, then a screen overlay paints through the world:

```text
        [ordinary props hide landmark]
        ███████████████████      whole road recoloured by state  ✗
        - - - - - - - - - -     2D overlay in front of props     ✗
          ○██○                  node ink/silhouette collision     ✗
```

### 5.2 Accepted and rejected branch fan-out

Accepted — alternatives identify themselves near the source and preserve continuation:

```text
                         ┌────────────○ A
source ○────≤1 m─────────┤  ≥32 px at 4 m in every profile
                         └────────────○ B
```

Rejected — two graph choices visually remain one line, cross, or separate only at their targets:

```text
source ○═════════════════╦════○ A
                         ╚════○ B      collapsed fan-out          ✗

source ○──────────╲   ╱────────○ A
                   ╳                  unrelated crossing          ✗
source ○──────────╱   ╲────────○ B
```

## 6. Semantic scenery zones

All ranges below are provisional occupied-area targets, measured only over each zone's legal area after node, road, hero, and intentional-empty masks are removed.

| Zone | Density target | Height role | Intended relation to route |
| --- | --- | --- | --- |
| `hero` | 0.00–0.08 | dominant | One authored landmark plus protected negative space; ordinary scatter excluded. |
| `foreground-frame` | 0.08–0.18 | tall/occluding | Sparse stage-edge frame; never crosses node/road reserves. |
| `road-bank` | 0.08–0.20 | low/compact | Nearest ordinary zone; strict corridor and silhouette clearance. |
| `midground` | 0.18–0.34 | low–medium | Coherent regional mass without competing with branch reading. |
| `vista` | 0.08–0.22 | medium–tall | Sparse distant punctuation; tall only when route exposure survives every profile. |

Counts are outcomes, not quotas. If legal space is scarce, #470 records a soft density shortfall rather than placing an illegal asset. “Arch/passable” occupancy and visual occlusion remain separate profile facts.

Intentional negative space is a governed mask, not whatever remains after scattering. It includes entrance/terminus framing, branch decision sight lines, route continuation windows, and region-specific breathing areas. Filling every legal point is a composition error.

## 7. Calibration record

The registry labels every numeric value with one of four classes.

### Bound #462 visual baseline

The TestFlight `1.0.0 (4)` baseline is now available and is a machine-checked input to this calibration record:

- production source `52a56e726da70c2dd57254e8c6618682c7558f90`;
- frozen packet head `4fe17d40b51178fe2f9a1e92d848787b3dc337c7`, workflow run `32790383346`;
- 168 desktop/Xvfb frames: Acts I–III at seeds 717 and 17634, authored Act IV at binding seed 717, all three shipping shapes, all four zoom stops, opening and focused poses, locale `en`;
- checked-in authority under `docs/reviews/462/`, including the README, architectural/asset summary, contact-sheet index, and nine-row defect ledger;
- all nine defect classes `D462-001` through `D462-009` are observed and explicitly mapped into the owner-review items in the registry;
- owner-supplied device evidence was not provided, so this baseline does not claim iPhone GPU, safe-area, touch-interaction, or TestFlight-packaging proof.

The corpus proves reproducible defect presence and supplies exact worst-frame references. It does **not** publish the numeric distributions needed to empirically choose the provisional 8 px, 32 px, corridor, density, or soft-score anchors. Binding the corpus therefore removes the stale “waiting for #462” state without pretending visual examples are quantitative calibration.

### Derived from shipping touch/waystone geometry

- visible waystone pane radius: 28 px (`GlassWaystone.UNLIT_RADIUS`);
- phone touch floor: 44 px (`assets/layout/combat-layout.json`, map/phone-landscape);
- default map layout scale: 0.92;
- current projected node-pair world half-extents: 0.63 m × 0.98 m;
- current scenery-avoidance X half-extent: 0.82 m.

The 44 px touch floor is not provisional and may not be weakened.

### Derived from stage/zoom geometry

- three shipping reference sizes;
- zoom stops 12/16/20/28 m;
- tilt −40°, camera height 18 m, flex cap 0.12;
- 15×7 lattice, 72 m journey span, 5.142857 m × 6 m cells, and authored jitter fractions.

These facts define what profiles must be evaluated. They do not by themselves prove a visual threshold is correct.

### Provisional visual thresholds requiring owner review

Every soft normalisation/weight; 8 px ink and safe-frame margins; 32 px branch separation; corridor dimensions; envelope dimensions; hero framing padding; zone density ranges; and waylight/road width ratio.

#462 is now bound above. Before release sign-off, the named `D462-*` frames must be used in owner review of every provisional ID, alongside quantitative measurements produced by the later evaluator/corpus tickets. Because #462 is a visual defect corpus rather than a threshold-distribution study, this PR does not invent numeric calibration from screenshots. A contradiction creates a separately reviewed contract change with evidence; it does not authorise an implementation ticket to weaken a threshold privately.

### Immutable zero-tolerance rules

Post-epsilon node/touch/silhouette overlap, route-corridor penetration, unrelated crossing/overlap, row/lane envelope excess, journey-order reversal, protected-zone intrusion, and deterministic identity mismatch all have a violation budget of zero.

## 8. Handoff ownership

Later tickets must consume this registry rather than invent equivalents:

- #464 — canonical input/result identity and replay;
- #465 — authoritative asset/hero occupancy and occlusion profiles;
- #466 — governed profiles, projection, raw measurements, and hard verdict;
- #467 — bounded row/lane candidates and monotonic order;
- #468 — single-edge route geometry and route economy;
- #469 — whole-graph crossings, fan-out, and continuation;
- #470 — protected zones, semantic scenery, density, diversity, repetition, and negative space;
- #471 — feasibility-first restart selection and complete raw score vector;
- #472 — neutral permanent road rendering;
- #473/#475 — narrow depth-tested waylight and retirement of the 2D `PathBand` graph authority;
- #476/#477 — release-corpus and rendered evidence gates;
- #481 — final owner review and residual asset-gap decision.

An implementation that cannot satisfy the contract must return a precise infeasibility or evidence blocker. It may not add a fallback authority, omit a bad profile/seed, or reduce a threshold to obtain a pass.

## 9. Validation

Run from repository root:

```bash
python3 -B tools/check_map_quality_v2.py --self-test
python3 -B tools/check_map_quality_v2.py
```

The validator rejects unknown fields, unknown or duplicate metric IDs, missing hard/soft metrics, unit-vocabulary drift, invalid normalisation direction, non-finite values, weight drift, a lowered touch floor, a non-zero immutable violation budget, hierarchy/zone drift, empty-policy drift, and a provisional-list mismatch. CI runs both modes.
