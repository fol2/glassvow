# Journey and survey composition study 01

Status: accepted by James as the Step 1 camera and navigation direction.
All four individual concepts and their combined direction are approved.
James authorised autonomous implementation Steps 2–8.

Open [the interactive study](index.html). Select a chapter, reference shape,
40° or 55° pitch, Journey or Whole act, and an inspected location. Encounter
symbols and the type filter support planning. Return to current position
restores the sample's actual current node. Interactions affect this document
only, not a game or save.

## Inputs and scope

- Source HEAD: `2ed6cdb0302ba3aab5845a18d862841165e8aaf7`.
- Engine: Godot `4.7.2.stable.official.ed1daf0bf`.
- Seed 717: Acts I–III each contain 65 nodes and 76 edges; Act IV contains
  five nodes and four edges. These are four chapter samples sharing one seed,
  not four independent random topologies.
- A separate Act I survey of seeds 1–20 found 53–66 nodes and 66–75 edges.
  Seed 4 maximised nodes plus edges in that bounded survey. This was topology
  inspection only; it was not a complete-layout qualification.
- `export-study.gd` regenerates the WorldMap and full compiler input at the
  current source, reads the existing preview cache only at its matching input
  digest, validates the immutable result and re-evaluates its quality. All
  four selected results returned `hard_pass=true` for the existing contracts.
  The cache contains the pure compiled layout; its digest can differ from
  historical screenshots after runtime scenery has been bound.
- Every anchor and complete route centreline is retained in the study data.
  Near-view viewport clipping is deliberate; no graph edge is deleted.
- The export initially attempted a fresh seed-7 compilation. It was stopped
  after several minutes of active CPU use, without a failure or pass conclusion.
  The study instead uses the complete-input-matched seed-717 results. No claim
  of fresh full compilation is made.

## Proposed experience

1. Begin in Journey. Frame the current stone towards the left with room for
   every immediate successor. Use automatic framing when a branch is wide;
   never crop a next choice merely to keep the camera close.
2. Start the greybox with a 55° downward camera. Compare its architecture and
   silhouettes against 40° in-engine before fixing the production profile.
3. Whole act fits the complete graph. Preserve encounter identity, current
   position, route history and all roads. Inspect a location and return to
   Journey for deliberate travel; do not shrink normal travel targets into
   an unreadable overview.
4. Use a physical waystone with a stable screen-space symbol. Current has a
   ring, next choices a strong outline, and history a tick. Environmental
   magenta or amber light must not be the sole state signal.
5. Reserve a compact top run HUD and bottom navigation area. The study uses
   placeholder values and provisional reserves, not the final HUD design.
6. Design landmarks at local encounter scale. A chapter-wide architecture
   reference is not one object to stamp over 65 encounters.

## Observations and verification

`check-study.cjs` drives the rendered page with Playwright. The final geometry
sweep covers 1,224 combinations: every location in all four selected samples,
three reference shapes, two pitches, plus their full-act frames.

- Zero missing nodes or edges in the SVG data across the sweep.
- The inspected location and immediate successors fit the proposed safe area
  with non-overlapping 44 px reserves in every tested close view.
- All node centres fit in every whole-act frame.
- No browser script errors or horizontal page overflow at a 390 px browser width.
- Browser captures were inspected for pad close view, phone close/whole view
  and the Act IV whole view. These are document captures, not Godot renders.

For Acts I–III at 55°, close views showed a median of five node centres on pad
and desktop and six on phone. The count is observed, not a fixed design rule.
Phone orthographic span needed up to 22.3 world units for wider branches,
compared with 17.5 at 40°. Automatic fitting is therefore part of the proposal.

## Limits and next proof

This schematic projects the existing compiled roads. It does not include new
terrain, building footprints, occlusion, depth-sorted crossings, controller
focus, live touch gestures, travel animation, performance or save integration.
The new pitch, automatic framing and HUD proposal have not passed the production
camera or map-quality contract. The local touch check covers the inspected node
and its successors, not every future mark or final artwork silhouette.

Act IV's current binding is a straight five-stop route. Its approved bent
causeway concept is still an art reference: the spatial translation must be
resolved explicitly in the greybox/compiler inputs, retaining the five IDs,
encounter order and every edge. Do not paint a bend over unchanged game geometry.

The next joint decision is whether this framing and information hierarchy express
the agreed close-journey/full-route experience. The playable greybox then needs
to demonstrate how the approved terrain and architectural forms occupy that
space before detailed asset production.
