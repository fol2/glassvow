# #421 iteration protocol — Phase A is the gate, landscape is the exam

Issue: [fol2/glassvow#421](https://github.com/fol2/glassvow/issues/421).
RC pillar: [`docs/rc-bar.md`](../rc-bar.md) P9 (not waivable).
Protocol, arm definitions, and C1–C4 / Vow-5 gates remain those of
[`2026-08-14-strategy-landscape.md`](2026-08-14-strategy-landscape.md) — this
file does not rewrite that measurement. Driver: `tools/balance_phase_a.py`.

H1 burned both landscape layers after a probe that left Vow 0 arm 2 at
**78.5% / 86.0%** (C2 needs **<50%**). n=200 Wilson width is ~±5 pp; Ash −2 pp
was noise. That stop rule is revoked. A drop versus the previous SHA counts
only at **≥6 pp**.

## Cost model

Measured on this host during H1 (Godot `4.7.2-stable (official)`; project pin
4.7.1). ~150 ms/run under ten-core CEM contention; controls/holdout are one or
two processes and finish faster.

| Job | Work | Wall (measured) | When |
|---|---|---|---|
| Phase A controls | 4 arms × 2 aspects × 2 vows × 200 seeds = **3,200** runs, one `balance_sweep.gd --mode=controls` process | ~5–10 min | every iteration |
| Phase A holdout | 2 vows × 2 aspects × 200 seeds = **800** runs, `--mix=none`, two `balance_sim.gd` processes | ~2–4 min | every iteration |
| **Phase A total** | **4,000** runs | **~10 min** | many times, until GO |
| Layer 1 sweep | 2,000 policies × 40 seeds × 2 aspects × 2 vows = **320,000** runs | **48 min 41 s** (H1, 10 processes) | Phase B only |
| Layer 2 CEM | 24 islands, training on 4200–4999, published ceilings on 5000–5199 | longest island **~2 h 14 min** (H1, 24 concurrent) | Phase B only |
| **Full landscape** | both layers | **~5 h** (H1) | **once per GO** |

Do not spend the 5-hour exam to learn that arm 2 is still 78%. Phase A exists
so that lesson costs ten minutes.

## Seed table

Do not mix these blocks. Diagnosis, CEM training, and published ceilings are
different claims.

| Block | Seeds | Role |
|---|---|---|
| Digest pin | **1000** | `tests/test_balance_sim.gd` seed-1000 duskblade digest. Re-bind after every content SHA move. |
| Layer 1 CRN | **3000–3039** | 40 common-random-number seeds for the 2,000-policy plurality. Phase B only. |
| Controls | **4000–4199** | Four control arms, n=200 per cell. Phase A every loop. |
| CEM training | **4200–4999** | Layer 2 CRN (`4200 + g×40 … +39`). Never ≥5000. Phase B only. |
| Holdout / exam | **5000–5199** | #204 four cells (`--mix=none`) and every published landscape ceiling. |
| Reserve | **5200–5399** | Unused #204 top-up reserve. Do not spend. |

## Phase A versus Phase B

**Phase A** (minutes, many times): four control arms on 4000–4199 plus the four
#204 holdout cells on 5000–5199 `--mix=none`. Holdout is a **veto**, not a
fitness. No plurality sample on every loop. No layer 1. No layer 2. Command:

```bash
python3 tools/balance_phase_a.py
```

**Phase B** (hours, once): the full two-layer landscape on the SHA that Phase A
just printed **GO**. Same protocol as #412 / H1. Every published ceiling stays
holdout-only (5000–5199).

A landscape is the exam that can close P9. Phase A only decides whether sitting
that exam is worth five hours.

## Verdicts (point estimates, n=200)

Driver exit codes: **GO = 0**, **NO-GO = 2**, **VETO = 3**. Invocation failure
is 1.

| Verdict | Meaning | Next |
|---|---|---|
| **VETO** | any #204 cell leaves V0 **80–97** / V5 **55–85**, or \|Ash−Dusk\| **>20 pp**, or V5 Ash holdout **>85%** | identity split (H10+H11): keep, do not landscape unless all four arm-2 **<50%**, do not claim #204 PASS. Other VETOs: restore the envelope |
| **NO-GO** | bands hold, but any of the four arm-2 cells **≥50%** | keep iterating Phase A; do not landscape |
| **GO** | all four arm-2 cells **<50%** and bands hold | *then* one landscape |

Until #204 bands are re-signed, landscape is **arm-2 only** (all four **<50%**).
Do not claim #204 PASS on the old envelope. Driver may still print VETO.

“Ash dropped a bit” is not GO. Ash −2 pp is inside Wilson noise. C2 needs arm 2
**<50%** on all four grids (Dusk V0 / Dusk V5 / Ash V0 / Ash V5).

## Decision tree after NO-GO

1. Read the four arm-2 deltas versus the previous SHA. Count a move only at
   **≥6 pp**. Smaller than that is noise; do not “follow” it.
2. Keep a knob only if it dropped **at least one** Vow 0 arm-2 cell ≥6 pp
   without VETO. Noise (both V0 arms <6 pp) is dead weight — revert it and go
   next. Do not require both aspects to move on a single common.
3. If a cell moved ≥6 pp the **wrong** way, revert that scalar. Do not add a
   second tax on the same card hoping the sign flips.
4. Holdout is only a veto. Do not pick the SHA that “looks healthier” on V0
   Dusk holdout while arm 2 is still 80%.
5. Do not start layer 1 or layer 2. Ticket stays open.

After **VETO**, restore the signed #204 envelope (revert or a compensating
change that Phase A then re-checks), **except** the signed identity split
(H10 Dusk-only stun + H11 Ash-only Smolder). That pair VETOs the *old*
2026-08-18 bands by design; keep it, do not raise HP, re-sign later. After
**GO**, run **one** landscape. If that landscape still FAILs C1–C3, return
to Phase A with a new hypothesis — do not immediately re-landscape.

## H1 lessons (binding for this campaign)

Readout: [`2026-08-19-421-hypothesis-1.md`](2026-08-19-421-hypothesis-1.md).
SHA `c96ed731…`. Arm 2 78.5 / 39.5 / 86.0 / 50.5. Holdout 89.5 / 94.5 / 67.0 /
75.5. C3 got worse (23/24 islands → shatter).

- **Do not strip more chip.** After the common-chip accident died, unconstrained
  CEM wanted dedicated shatter *more*. Leave `chisel` / `uppercut` /
  `quakeblow` / `oblivionStrike` alone.
- **Do not raise enemy HP or facets this campaign.** HP-up makes shatter more
  mandatory, which is the same C3 trap.
- **Keep Emberbite (`venomStrike`) Smolder at 4 / upgrade 5.** H2 reverted it
  to 3/4 and Dusk V0 arm 2 moved **+10.0 pp the wrong way** (78.5 → 88.5),
  restoring the #412 number. Emberbite 4 is load-bearing for Dusk C2. The
  earlier lesson “do not buff `venomStrike`” is **revoked**. Do not revert
  that common to 3 again without a new measured reason.
- **Do not keep H2's Maul damage tax or Ashcloud +1.** Those knobs rode with
  the Emberbite revert and did not drop Ash; they are not isolated keepers.
- **1-pt common damage/ward taxes are exhausted.** H3–H8 all NO-GO / noise;
  H9 (`deflect`) unrecorded then reverted. Do not 1-pt the same commons again.
- **James signed Dusk-only stun: Ash does not shatter.** H10 gated
  `apply_chips` on `run.aspect != 0`. Identity fired (Ash V0 arm 2 86.0 → 33.0,
  Ash V5 50.5 → 10.0; Dusk arm 2 unchanged 78.5 / 39.5) and **VETO**'d the
  *old* #204 envelope: Ash holdout 72.5% / 42.0%. Restored (`03deb60`). Do
  **not** revert identity because old bands broke. Do **not** raise HP.
  Snapshot: `docs/balance/data/421-h10/phase-a.json`.
- **James signed Ash-only Smolder: Dusk cannot apply poison.** H11 no-ops
  player-sourced enemy `poison` when `run.aspect == 0` (cards, arts,
  venomous, relics, potions). Flare dropped the Smolder effect, kept 7 AoE.
  cinderVeined / ashfall omen still hit the player. Arm 2: Dusk V0 **68.5%
  (−10.0 vs H10)**, Dusk V5 **24.0% (−15.5)**, Ash unchanged 33.0 / 10.0.
  Holdout Dusk V5 67.0 → 52.0 (old 55% floor). Keep H10+H11. Old envelope,
  identity split; re-sign later. Snapshot: `docs/balance/data/421-h11/phase-a.json`.
- **Flicker (`quickSlash`) cost 0→1 is a keeper.** H12 kept 4 dmg + draw.
  Arm 2 vs H11: Dusk V0 **54.0% (−14.5)**, Dusk V5 **14.5% (−9.5)**, Ash V0
  **21.5% (−11.5)**, Ash V5 **7.0% (−3.0)**. Snapshot:
  `docs/balance/data/421-h12/phase-a.json`.
- **Glasstep (`sidestep`) cost 0→1 is a keeper.** H13 kept 3 ward + draw.
  Arm 2 vs H12: Dusk V0 **45.0% (−9.0)**, Dusk V5 **16.0% (+1.5 noise)**,
  Ash V0 **16.5% (−5.0)**, Ash V5 **2.5% (−4.5)**. All four arm-2 **<50%**
  → Phase A **GO** (old #204 still VETO; identity split). Skip H14
  (`surge`) and H15 (`eclipseSlash` 7→5). Snapshot:
  `docs/balance/data/421-h13/phase-a.json`.
- **H13 landscape ran once and FAIL C1–C3.** Readout:
  [`2026-08-20-421-hypothesis-13.md`](2026-08-20-421-hypothesis-13.md).
  Arm 2 45.0 / 16.0 / 16.5 / 2.5. C2 PASS Dusk V5 and Ash V0; miss Dusk V0
  +25.79 and Ash V5 +33.22. Ash top cell is **smolder:fat**; Ash CEM did
  not drift to shatter. Dusk still does. C1 not close. **No second 5h
  loop.** Identity keepers stay. Re-sign #204 later.
- **Smolder decay −2 is a later isolated hypothesis**, not this loop. Ash V5
  arm 2 is already 2.5%. Player-side cinder tick stays −1. Do not decay
  after the cost queue already printed GO.
- **Ash HP 80→88 (H16) and Ashbite 5→6 / 7→8 keep Smolder 2/3 (H17) are
  keepers.** Snapshots: `docs/balance/data/421-h16/phase-a.json`,
  `docs/balance/data/421-h17/phase-a.json`. H17 arm 2 **45.0 / 16.0 / 25.5
  / 5.0**. Holdout 79.0 / 36.5 / 71.5 / 41.0. |Ash−Dusk| V0 **−7.5 pp**.
- **H19 drops the implicit connecting-attack chip on the live catalogue.**
  `per = 0 + card.chip + Beacon` (`content.id == core`); slice goldens still
  pin the old leading 1. Dusk V0 arm 2 **45.0 → 1.0** (−44.0 vs H17);
  Dusk holdout **79.0 → 16.0**. Ash unchanged (already no chip). KEEP by
  the H19 stop rule (Dusk V0 arm 2 down ≥6 pp; revert only if that cell
  *up* ≥6). Old 80/55 VETO is not a revert. All four arm-2 still **<50%**
  (1.0 / 1.5 / 25.5 / 5.0) and the C1 theory is the live SHA → one
  landscape, same protocol as H13. Snapshot:
  `docs/balance/data/421-h19/phase-a.json`.

Out of bounds unless a signed iteration brings one in: map weights, potion
probability, act-transition heal, the five `vows` penalties, mix, `port_fixtures/`.

Locale display strings follow scalar edits so the en-seed hydration gate stays
honest — that is not a locale retune.

## Driver notes

`tools/balance_phase_a.py` orchestrates existing Godot tools; it does not
simulate. Flags to Godot are `--name=value` after `--`. PATH may be 4.7.2;
the project pin remains 4.7.1. Record the version from the sweep/holdout
manifest, not from `godot --version` alone.

`--controls-json`, `--holdout-vow0`, and `--holdout-vow5` reuse already-written
JSON (H1 dry-run, or a finished probe). `--baseline` defaults to
`docs/balance/data/421/phase-a-baseline.json` (H1 numbers). The committed
`docs/balance/data/421/controls.json` array shape is also accepted.
