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
- **H19 landscape ran once and FAIL C1–C3.** Readout:
  [`2026-08-20-421-hypothesis-19.md`](2026-08-20-421-hypothesis-19.md).
  Arm 2 1.0 / 1.5 / 25.5 / 5.0. Shatter-fat fell (70.79 → 29.61); attrition-fat
  also fell (40.84 → 7.15) — cells did not cluster. Dusk shatter median is
  now **0**. C2 FAIL all four (closest Dusk V0 +28.61). Dusk V5 holdout
  ceiling 4.5%. |Ash−Dusk| V0 **+55.5 pp**. C1 miss is not Ash-only.
  **No second 5h loop. No Smolder decay.** Identity keepers stay.
- **Dusk HP 72→64 (H27) is a keeper.** Snapshot:
  `docs/balance/data/421-h27/phase-a.json`. Arm 2 **36.0 / 12.0 / 25.5 /
  5.0**. Holdout 66.0 / 27.5 / 71.5 / 41.0. |Ash−Dusk| **+5.5 / +13.5 pp**.
  KEEP because Dusk V0 arm 2 dropped ≥6 pp the right way (45.0 → 36.0).
  Old 80/55 VETO is record, not a revert. C1 theory: frailer Dusk drops
  shatter-fat toward mid without deleting implicit chip. One landscape
  next. **Do not raise Ash HP.** H22 (Ash 96) was reverted after Vow-5
  90.5%; Ash stays 88.
- **H27 landscape ran once and FAIL C1–C3.** Readout:
  [`2026-08-20-421-hypothesis-27.md`](2026-08-20-421-hypothesis-27.md).
  Arm 2 36.0 / 12.0 / 25.5 / 5.0. Shatter-fat 65.54% (H22 72.06); mid
  dropped more (−13.0 pp) so the 10 pp window did not open. C2 PASS
  Dusk V5 +38.92; miss Dusk V0 +29.54, Ash V0 +33.97, Ash V5 +32.98.
  C3 FAIL all four. Vow-5 Ash **72.5% ≤ 90%** (H22 90.5% was Ash 96 +
  mix/relic). **No second 5h loop.** Do not revert Dusk 64. Do not
  raise Ash HP. Relic stack still later-phase.
- **H28 (`eclipseSlash` 7→5 / 9→7) is noise — reverted.** Snapshot:
  `docs/balance/data/421-h28/phase-a.json`. Arm 2 **33.0 / 9.5 / 25.5 /
  5.0**. Holdout 61.0 / 25.0 / 71.5 / 41.0. |Ash−Dusk| **+10.5 / +16.0 pp**.
  Dusk V0 arm 2 36.0 → 33.0 (−3.0) under 6 pp. Ash unchanged (Dusk-only
  starter). Working SHA remains H27 `ea5d6cab…`. Do not landscape. Do
  not raise Ash HP. Relic stack still later-phase. Readout:
  [`2026-08-20-421-hypothesis-28.md`](2026-08-20-421-hypothesis-28.md).
- **H29 (`eclipseSlash` cost 1→2, keep 7 / 9 and Cracked 1 / 2) is a
  keeper.** Snapshot: `docs/balance/data/421-h29/phase-a.json`. Arm 2
  **19.0 / 7.0 / 25.5 / 5.0**. Holdout 55.0 / 18.0 / 71.5 / 41.0.
  Ash−Dusk **+16.5 / +23.0 pp**. Dusk V0 arm 2 36.0 → 19.0 (−17.0) ≥6
  the right way. Ash unchanged (Dusk-only starter). V5 |gap| exceeds 20
  because Dusk holdout tanked, not Ash — record; old 80/55 already VETO.
  Locale untouched (text does not mention cost). Do not landscape this
  pass. Do not raise Ash HP. Relic stack still later-phase. Readout:
  [`2026-08-20-421-hypothesis-29.md`](2026-08-20-421-hypothesis-29.md).
- **H30 (`flare` AoE 7→9, keep cost 3 and no Smolder) is a keeper.**
  Snapshot: `docs/balance/data/421-h30/phase-a.json`. Arm 2
  **21.5 / 8.0 / 25.5 / 5.0**. Holdout 55.0 / 22.0 / 71.5 / 41.0.
  Ash−Dusk **+16.5 / +19.0 pp**. V5 |gap| 23.0 → 19.0 (cap met) because
  Dusk V5 holdout rose +4.0 pp; Ash unchanged (Dusk-only art). Dusk V0
  arm 2 19.0 → 21.5 (+2.5) under 6 pp and still <30%. Locale followed.
  Eclipse cost stays 2. Do not landscape this pass. Do not raise Ash HP.
  Relic stack still later-phase. Readout:
  [`2026-08-20-421-hypothesis-30.md`](2026-08-20-421-hypothesis-30.md).
- **H30 landscape ran once and FAIL C1–C3.** Readout:
  [`2026-08-20-421-hypothesis-30.md`](2026-08-20-421-hypothesis-30.md).
  SHA `e5037f30…`. Arm 2 21.5 / 8.0 / 25.5 / 5.0. Eclipse cost 2
  **opened Dusk C2** (V0 +41.46, V5 +41.24) because the pack dropped,
  not because mid closed — C1 window **widened**. Ash C2 miss V0
  **+31.63** (need ≥35). Vow-5 Ash **84.5% ≤ 90%**. **No second 5h
  loop.** Do not revert Eclipse cost 2, Flare 9, or Dusk 64. Do not
  tax more Dusk starters. Relic stack still later-phase.
- **H31 (`ashBite` 6→5 / 8→7, keep Smolder 2/3) is noise — reverted.**
  Snapshot: `docs/balance/data/421-h31/phase-a.json`. Arm 2
  **21.5 / 8.0 / 24.0 / 7.0**. Holdout 55.0 / 22.0 / 65.5 / 40.0.
  Ash−Dusk **+10.5 / +18.0 pp**. Ash V0 arm 2 25.5 → 24.0 (−1.5)
  under 6 pp. Dusk arm 2 bit-identical (Ash-only starter). KEEP
  needed ≤19.5%. Working SHA remains H30 `e5037f30…`. Do not
  landscape. Do not raise Ash HP. Relic stack still later-phase.
  Readout:
  [`2026-08-20-421-hypothesis-31.md`](2026-08-20-421-hypothesis-31.md).
- **H32 (`ashBite` cost 1→2, keep 6 / 8 and Smolder 2 / 3) is a
  keeper.** Snapshot: `docs/balance/data/421-h32/phase-a.json`. Arm 2
  **21.5 / 8.0 / 13.5 / 1.0**. Holdout 55.0 / 22.0 / 53.5 / 23.5.
  Ash−Dusk **−1.5 / +1.5 pp**. Ash V0 arm 2 25.5 → 13.5 (−12.0) ≥6
  the right way. Dusk arm 2 bit-identical (Ash-only starter). V0
  −1.5 is 107 vs 110 wins (Wilson noise of 0); V5 |gap| closed
  19.0 → 1.5 — the Ash-tank REVERT (V5 |gap| >20) did not fire.
  Locale untouched (text does not mention cost). H31 damage tax
  was noise; this is the H29 cost-tax sibling. Do not landscape
  this pass. Do not raise Ash HP. Relic stack still later-phase.
  Readout:
  [`2026-08-20-421-hypothesis-32.md`](2026-08-20-421-hypothesis-32.md).
- **H33 (`arts.ashfall` all-enemies Smolder 3→4, keep cost 3 and
  Ward 5) is a keeper.** Snapshot:
  `docs/balance/data/421-h33/phase-a.json`. Arm 2
  **21.5 / 8.0 / 17.5 / 3.5**. Holdout 55.0 / 22.0 / 65.5 / 26.5.
  Ash−Dusk **+10.5 / +4.5 pp**. V0 Ash-ahead restored (−1.5 → +10.5).
  Ash V0 arm 2 13.5 → 17.5 (+4.0) under 6 pp and still <20% (revert
  bar was ≥19.5). Dusk arm 2 bit-identical (Ash-only art). Locale
  `en` / `zh-Hant` `content.arts.ashfall` followed; omen/affix
  `ashfall` untouched. Same payback as H30 Flare: aspect art lifts
  planned holdout, not random-build. Do not landscape this pass.
  Do not raise Ash HP. Relic stack still later-phase. Readout:
  [`2026-08-20-421-hypothesis-33.md`](2026-08-20-421-hypothesis-33.md).
- **H34 (`ashenChoir` 4→5 / 6→7, keep cost 1) is noise — reverted.**
  Snapshot: `docs/balance/data/421-h34/phase-a.json`. Arm 2
  **21.5 / 8.0 / 17.5 / 3.5**. Holdout 55.0 / 22.0 / 65.5 / 26.5.
  Ash−Dusk **+10.5 / +4.5 pp**. Ash V0 arm 1 67.5 and holdout 65.5
  both +0.0 (bit-identical; KEEP needed ≥6 pp on either). Ash V0
  arm 2 stayed 17.5 (no random clog). Dusk arm 2 bit-identical
  (Ash-locked card). Working SHA remains H33 `585b143b…`. Do not
  landscape. Do not raise Ash HP. Relic stack still later-phase.
  Readout:
  [`2026-08-21-421-hypothesis-34.md`](2026-08-21-421-hypothesis-34.md).
- **H35 (`toxicMist` 3→4 / 5→6, keep cost 1) is noise — reverted.**
  Snapshot: `docs/balance/data/421-h35/phase-a.json`. Arm 2
  **21.5 / 8.0 / 18.0 / 3.5**. Holdout 55.0 / 22.0 / 65.0 / 24.5.
  Ash−Dusk **+10.0 / +2.5 pp**. Ash V0 arm 1 67.5→64.5 (−3.0) and
  holdout 65.5→65.0 (−0.5) both |delta| <6 (KEEP needed ≥6 pp on
  either). Ash V0 arm 2 17.5→18.0 (+0.5; no random clog; still
  <20%). Dusk arm 2 bit-identical (H11 no-ops Smolder). Isolated
  Smolder +1, not H2's Ashcloud cost tax. Working SHA remains H33
  `585b143b…`. Do not landscape. Do not raise Ash HP. Relic stack
  still later-phase. Readout:
  [`2026-08-21-421-hypothesis-35.md`](2026-08-21-421-hypothesis-35.md).
- **H36 (`arts.ashfall` all-enemies Smolder 4→5, keep cost 3 and
  Ward 5) is noise — reverted.** Snapshot:
  `docs/balance/data/421-h36/phase-a.json`. Arm 2
  **21.5 / 8.0 / 21.5 / 4.5**. Holdout 55.0 / 22.0 / 68.5 / 31.0.
  Ash−Dusk **+13.5 / +9.0 pp**. Ash V0 arm 1 67.5→71.0 (+3.5) and
  holdout 65.5→68.5 (+3.0) both |delta| <6 (KEEP needed ≥6 pp on
  either). Ash V0 arm 2 17.5→21.5 (+4.0; still <23.5%; not the
  ≥6 clog). Dusk arm 2 bit-identical (Ash-only art). Same art as
  H33; the second +1 did not repeat +8.5 / +12. H33 landscape
  already FAIL C1–C3 (`fbb92f6`); this is not a second 5h.
  Working SHA remains H33 `585b143b…`. Do not landscape. Do not
  raise Ash HP. Relic stack still later-phase. Readout:
  [`2026-08-21-421-hypothesis-36.md`](2026-08-21-421-hypothesis-36.md).
- **H37 (`smother` cost 1→2, keep 5 Ward and Smolder 2)
  is noise-on-ahead — reverted.** Snapshot:
  `docs/balance/data/421-h37/phase-a.json`. Arm 2
  **21.5 / 8.0 / 8.5 / 1.0**. Holdout 55.0 / 22.0 / 53.0 / 20.5.
  Ash−Dusk **−2.0 / −1.5 pp**. Ash V0 arm 2 17.5→8.5 (−9.0)
  ≥6 the C2 way (≤11.5). Dusk arm 2 bit-identical (Ash-only
  starter). Ash−Dusk V0 +10.5→−2.0 (Ash 53.0 < Dusk 55.0) —
  planned Ash tanked; hard REVERT. Locale untouched (text
  does not mention cost). H32 sibling; two 2-cost starters
  tax random *and* planned. H33 landscape already FAIL
  C1–C3 (`fbb92f6`); this is not a second 5h. Working SHA
  remains H33 `585b143b…`. Do not landscape. Do not raise
  Ash HP. Relic stack still later-phase. Readout:
  [`2026-08-21-421-hypothesis-37.md`](2026-08-21-421-hypothesis-37.md).
- **H38 (`arts.emberveil` Ward 12→15, keep cost 3)
  is noise — reverted.** Snapshot:
  `docs/balance/data/421-h38/phase-a.json`. Arm 2
  **21.5 / 8.0 / 17.5 / 3.5**. Holdout 55.0 / 22.0 / 65.5 / 26.5.
  Ash−Dusk **+10.5 / +4.5 pp**. Ash V0 arm 1 67.5 and holdout 65.5
  both +0.0 (bit-identical; KEEP needed ≥6 pp on either). Ash V0
  arm 2 stayed 17.5 (no random clog). Dusk V0 arm 2 stayed 21.5
  (shared art; +3 Ward never flipped a run). H33 landscape
  already FAIL C1–C3 (`fbb92f6`); this is not a second 5h.
  Working SHA remains H33 `585b143b…`. Do not landscape. Do
  not raise Ash HP. Relic stack still later-phase. Readout:
  [`2026-08-21-421-hypothesis-38.md`](2026-08-21-421-hypothesis-38.md).
- **H39 (`arts.ashfall` all-enemies Smolder 4→6, keep cost 3 and
  Ward 5) is a keeper.** Snapshot:
  `docs/balance/data/421-h39/phase-a.json`. Arm 2
  **21.5 / 8.0 / 17.5 / 6.5**. Holdout 55.0 / 22.0 / 70.5 / 39.5.
  Ash−Dusk **+15.5 / +17.5 pp**. Ash V0 arm 1 67.5→77.5 (+10.0)
  ≥6; holdout 65.5→70.5 (+5.0) under 6 — OR fired on arm 1.
  Ash V0 arm 2 stayed 17.5 (bit-identical; still <20%). Dusk
  arm 2 bit-identical (Ash-only art). H36's +1 was diminishing
  (+3.5 / +3.0); isolated +2 cleared the planned bar without
  a starter tax. H33 landscape already FAIL C1–C3 (`fbb92f6`);
  this is not a second 5h. Working SHA is now H39 `a0d608a5…`.
  Do not landscape. Do not raise Ash HP. Relic stack still
  later-phase. Readout:
  [`2026-08-21-421-hypothesis-39.md`](2026-08-21-421-hypothesis-39.md).
- **H40 (`cards.bulwark` Ward 13→18 / 18→23, keep cost 2)
  is noise — reverted.** Snapshot:
  `docs/balance/data/421-h40/phase-a.json`. Arm 2
  **26.5 / 7.0 / 20.5 / 7.0**. Holdout 59.0 / 22.5 / 69.0 / 36.5.
  Ash−Dusk **+10.0 / +14.0 pp**. Ash V0 arm 1 77.5→79.5 (+2.0)
  and holdout 70.5→69.0 (−1.5) both |delta| <6 (KEEP needed ≥6
  pp on either). Ash V0 arm 2 17.5→20.5 (+3.0; still <23.5%;
  not the ≥6 clog). Dusk V0 arm 2 21.5→26.5 (+5.0; shared
  uncommon; under 6, thin). H38 Emberveil +3 Ward was
  bit-identical; this larger 2-cost wall still did not fire
  planned. H39 landscape already FAIL C1–C3 (`595377b`);
  this is not a second 5h. Working SHA remains H39
  `a0d608a5…`. Do not landscape. Do not raise Ash HP.
  Relic stack still later-phase. Readout:
  [`2026-08-21-421-hypothesis-40.md`](2026-08-21-421-hypothesis-40.md).
- **H41 (`cards.brace` Ward 8→12 / 11→15, keep cost 1)
  is noise — reverted.** Snapshot:
  `docs/balance/data/421-h41/phase-a.json`. Arm 2
  **22.0 / 8.0 / 18.5 / 6.5**. Holdout 57.0 / 21.5 / 70.5 / 41.0.
  Ash−Dusk **+13.5 / +19.5 pp**. Ash V0 arm 1 77.5→78.5 (+1.0)
  and holdout 70.5→70.5 (+0.0) both |delta| <6. Ash V0 arm 2
  17.5→18.5 (+1.0; no clog). Dusk V0 arm 2 21.5→22.0 (+0.5).
  H38 art +3, H40 uncommon +5, H41 common +4: one-shot block
  scalars do not fire the Phase A KEEP bar. H39 landscape
  already FAIL C1–C3 (`595377b`); this is not a second 5h.
  Working SHA remains H39 `a0d608a5…`. Do not landscape. Do
  not raise Ash HP. Relic stack still later-phase. Readout:
  [`2026-08-21-421-hypothesis-41.md`](2026-08-21-421-hypothesis-41.md).
- **H42 (`arts.ashfall` Smolder 6→5, keep cost 3 and Ward 5)
  is a C2-slack revert, not noise.** Snapshot:
  `docs/balance/data/421-h42/phase-a.json`. Arm 2
  **21.5 / 8.0 / 21.5 / 4.5**. Holdout 55.0 / 22.0 / 68.5 / 31.0.
  Ash−Dusk **+13.5 / +9.0 pp**. Ash V0 arm 1 77.5→71.0 (**−6.5**)
  ≥6 the down way; holdout 70.5→68.5 (−2.0) under 6 — OR fired
  on arm 1. Ash V0 arm 2 17.5→21.5 (+4.0; still <23.5%). Dusk
  arm 2 bit-identical. Expected landscape C2 ~28–33 (H39 was
  +38.03; H33 was +30). Do not walk H39's isolated +2 back.
  H39 landscape already FAIL C1–C3 (`595377b`); this is not a
  second 5h. Working SHA remains H39 `a0d608a5…`. Do not
  landscape. Do not raise Ash HP. Relic stack still
  later-phase. Readout:
  [`2026-08-21-421-hypothesis-42.md`](2026-08-21-421-hypothesis-42.md).
- **H43 (`cards.ironSkin` metallicize 3→5 / 4→6, keep cost 1)
  is noise — reverted.** Snapshot:
  `docs/balance/data/421-h43/phase-a.json`. Arm 2
  **25.0 / 8.5 / 20.0 / 6.5**. Holdout 63.5 / 27.0 / 76.0 / 45.0.
  Ash−Dusk **+12.5 / +18.0 pp**. Ash V0 arm 1 77.5→80.5 (+3.0)
  and holdout 70.5→76.0 (+5.5) both |delta| <6. Dusk V0 arm 1
  53.5→60.5 (+7.0) — shared power paid Dusk more than Ash.
  Digest moved (`98d634e7…`); not re-pinned. H39 landscape
  already FAIL C1–C3 (`595377b`); this is not a second 5h.
  Working SHA remains H39 `a0d608a5…`. Do not landscape. Do
  not raise Ash HP. Relic stack still later-phase. Readout:
  [`2026-08-21-421-hypothesis-43.md`](2026-08-21-421-hypothesis-43.md).
- **H44 (`arts.ashfall` Ward 5→8, keep Smolder 6 and cost 3)
  is an arm-2-clog / gap-cap revert.** Snapshot:
  `docs/balance/data/421-h44/phase-a.json`. Arm 2
  **21.5 / 8.0 / 27.0 / 7.5**. Holdout 55.0 / 22.0 / 77.0 / 52.5.
  Ash−Dusk **+22.0 / +30.5 pp** (both over 20). Ash V0 holdout
  70.5→77.0 (+6.5) fires KEEP-OR; Ash V0 arm 2 17.5→27.0
  (**+9.5**) is the ≥6 clog. Extra Ward on the always-present
  Ash art is starter-like. H39 landscape already FAIL C1–C3
  (`595377b`); this is not a second 5h. Working SHA remains
  H39 `a0d608a5…`. Do not landscape. Do not raise Ash HP.
  Relic stack still later-phase. Readout:
  [`2026-08-21-421-hypothesis-44.md`](2026-08-21-421-hypothesis-44.md).
- **H45 (`cards.regrowth` regen 2→4 / 3→5, keep cost 1)
  is an arm-2-clog revert, not noise.** Snapshot:
  `docs/balance/data/421-h45/phase-a.json`. Arm 2
  **27.5 / 10.0 / 28.5 / 9.0**. Holdout 66.0 / 39.5 / 80.0 / 59.0.
  Ash−Dusk **+14.0 / +19.5 pp**. Ash V0 arm 1 77.5→84.5 (+7.0)
  and holdout 70.5→80.0 (+9.5) fire KEEP-OR. Ash V0 arm 2
  17.5→28.5 (**+11.0**) and Dusk V0 arm 2 21.5→27.5 (**+6.0**)
  are both ≥6 clogs. Digest moved (`c717bb36…`); not re-pinned.
  H39 landscape already FAIL C1–C3 (`595377b`); this is not a
  second 5h. Working SHA remains H39 `a0d608a5…`. Do not
  landscape. Do not raise Ash HP. Relic stack still
  later-phase. Readout:
  [`2026-08-21-421-hypothesis-45.md`](2026-08-21-421-hypothesis-45.md).
- **H46 (`cards.toxicMist` cost 1→2, keep Smolder 3 / 5)
  is noise — reverted.** Snapshot:
  `docs/balance/data/421-h46/phase-a.json`. Arm 2
  **21.5 / 8.5 / 17.5 / 6.0**. Holdout 54.5 / 22.5 / 73.0 / 39.0.
  Ash−Dusk **+18.5 / +16.5 pp**. Ash V0 arm 1 77.5→75.5 (−2.0)
  and holdout 70.5→73.0 (+2.5) both |delta| <6. Arm 2
  bit-identical (no clog). Not a 1-cost sustain/ward. H39
  landscape already FAIL C1–C3 (`595377b`); this is not a
  second 5h. Working SHA remains H39 `a0d608a5…`. Do not
  landscape. Do not raise Ash HP. Relic stack still
  later-phase. Readout:
  [`2026-08-21-421-hypothesis-46.md`](2026-08-21-421-hypothesis-46.md).
- **H47 (`cards.leechBlade` leech 9→13 / 13→17, keep cost 2)
  is noise — reverted.** Snapshot:
  `docs/balance/data/421-h47/phase-a.json`. Arm 2
  **22.0 / 9.0 / 17.0 / 6.5**. Holdout 55.5 / 23.0 / 70.5 / 40.5.
  Ash−Dusk **+15.0 / +17.5 pp**. Ash V0 arm 1 77.5→78.0 (+0.5)
  and holdout 70.5→70.5 (+0.0) both |delta| <6. No arm-2 clog.
  Digest moved (`c92be4b3…`); not re-pinned. Not 1-cost
  sustain/ward. H39 landscape already FAIL C1–C3 (`595377b`);
  this is not a second 5h. Working SHA remains H39 `a0d608a5…`.
  Do not landscape. Do not raise Ash HP. Relic stack still
  later-phase. Readout:
  [`2026-08-21-421-hypothesis-47.md`](2026-08-21-421-hypothesis-47.md).
- **H48 (`cards.tempest` all-enemies 4→6 twice / 6→8 twice, keep
  cost 2) is noise — reverted.** Snapshot:
  `docs/balance/data/421-h48/phase-a.json`. Arm 2
  **23.0 / 7.5 / 22.0 / 7.0**. Holdout 54.0 / 22.5 / 69.5 / 38.0.
  Ash−Dusk **+15.5 / +15.5 pp**. Ash V0 arm 1 77.5→73.0 (−4.5)
  and holdout 70.5→69.5 (−1.0) both |delta| <6. Ash V0 arm 2
  +4.5 under clog. Not 1-cost sustain/ward. H39 landscape
  already FAIL C1–C3 (`595377b`); this is not a second 5h.
  Working SHA remains H39 `a0d608a5…`. Do not landscape. Do
  not raise Ash HP. Relic stack still later-phase. Readout:
  [`2026-08-21-421-hypothesis-48.md`](2026-08-21-421-hypothesis-48.md).
- **H49 (`cards.guardedStrike` dmg 5→8 / 7→10, keep 4/6 Ward
  and cost 1) is noise — reverted.** Snapshot:
  `docs/balance/data/421-h49/phase-a.json`. Arm 2
  **24.5 / 10.0 / 19.5 / 2.5**. Holdout 58.5 / 24.0 / 66.5 / 38.0.
  Ash−Dusk **+8.0 / +14.0 pp**. Ash V0 arm 1 77.5→76.0 (−1.5)
  and holdout 70.5→66.5 (−4.0) both |delta| <6. Dusk V0 arm 1
  +3.5 (shared attack paid Dusk more). No V0 arm-2 ≥6 clog.
  Digest moved (`e10ddeea…`); not re-pinned. Damage-only, not
  a ward/sustain buff. H39 landscape already FAIL C1–C3
  (`595377b`); this is not a second 5h. Working SHA remains
  H39 `a0d608a5…`. Do not landscape. Do not raise Ash HP.
  Relic stack still later-phase. Readout:
  [`2026-08-21-421-hypothesis-49.md`](2026-08-21-421-hypothesis-49.md).
- **H50 (`cards.aegis` Ward 30→40 / 40→50, keep cost 2 and
  Kindle) is noise — reverted.** Snapshot:
  `docs/balance/data/421-h50/phase-a.json`. Arm 2
  **21.0 / 7.5 / 16.5 / 7.0**. Holdout 55.5 / 22.0 / 72.5 / 40.0.
  Ash−Dusk **+17.0 / +18.0 pp**. Ash V0 arm 1 77.5→76.5 (−1.0)
  and holdout 70.5→72.5 (+2.0) both |delta| <6. No arm-2 clog
  (rare). Digest moved (`2563eee6…`); not re-pinned. Not
  1-cost sustain. H39 landscape already FAIL C1–C3 (`595377b`);
  this is not a second 5h. Working SHA remains H39 `a0d608a5…`.
  Do not landscape. Do not raise Ash HP. Relic stack still
  later-phase. Readout:
  [`2026-08-21-421-hypothesis-50.md`](2026-08-21-421-hypothesis-50.md).
- **H51 (`cards.cleave` all-enemies 6→9 / 9→12, keep cost 1)
  is noise — reverted.** Snapshot:
  `docs/balance/data/421-h51/phase-a.json`. Arm 2
  **21.5 / 8.0 / 17.5 / 6.5** (bit-identical). Holdout
  55.0 / 21.0 / 71.5 / 39.0. Ash−Dusk **+16.5 / +18.0 pp**.
  Ash V0 arm 1 77.5→76.5 (−1.0) and holdout 70.5→71.5 (+1.0)
  both |delta| <6. Digest unchanged. Not 1-cost sustain/ward.
  H39 landscape already FAIL C1–C3 (`595377b`); this is not a
  second 5h. Working SHA remains H39 `a0d608a5…`. Do not
  landscape. Do not raise Ash HP. Relic stack still
  later-phase. Readout:
  [`2026-08-21-421-hypothesis-51.md`](2026-08-21-421-hypothesis-51.md).
- **H52 (`cards.ashBite` dmg 6→8 / 8→10, keep cost 2 and
  Smolder 2/3) is reverted.** Snapshot:
  `docs/balance/data/421-h52/phase-a.json`. Arm 2
  **21.5 / 8.0 / 21.5 / 6.5**. Holdout 55.0 / 22.0 / 70.5 /
  43.5. Ash−Dusk **+15.5 / +21.5 pp** (V5 cap 20 **broken**).
  Ash V0 arm 1 77.5→69.0 (**−8.5**, wrong way). Arm 2 +4.0
  under clog. Dusk bit-identical. Digest unchanged. Not
  1-cost sustain/ward. Do not retune Ashbite damage again
  this loop. H39 landscape already FAIL C1–C3 (`595377b`);
  this is not a second 5h. Working SHA remains H39
  `a0d608a5…`. Do not landscape. Do not raise Ash HP. Relic
  stack still later-phase. Readout:
  [`2026-08-21-421-hypothesis-52.md`](2026-08-21-421-hypothesis-52.md).
- **H53 (`cards.flurry` 2→4 ×3 / 3→6 ×3, keep cost 1) is
  noise — reverted.** Snapshot:
  `docs/balance/data/421-h53/phase-a.json`. Arm 2
  **26.5 / 7.0 / 18.5 / 6.5**. Holdout 56.5 / 23.5 / 70.0 /
  40.0. Ash−Dusk **+13.5 / +16.5 pp**. Ash V0 arm 1
  77.5→75.0 (−2.5) and holdout 70.5→70.0 (−0.5) both |delta|
  <6. Dusk V0 arm 2 +5.0 (shared 1-cost attack paid random
  Dusk). Digest moved (`52cff022…`); not re-pinned. Not
  1-cost sustain/ward. H39 landscape already FAIL C1–C3
  (`595377b`); this is not a second 5h. Working SHA remains
  H39 `a0d608a5…`. Do not landscape. Do not raise Ash HP.
  Relic stack still later-phase. Readout:
  [`2026-08-21-421-hypothesis-53.md`](2026-08-21-421-hypothesis-53.md).
- **H54 (`cards.empower` cost 1→2, keep 2/3 Fervor) is
  reverted.** Snapshot: `docs/balance/data/421-h54/phase-a.json`.
  Arm 2 **23.5 / 7.5 / 20.0 / 5.0**. Holdout 54.0 / 19.0 /
  68.0 / 40.0. Ash−Dusk **+14.0 / +21.0 pp** (V5 cap 20
  **broken**). Ash V0 arm 2 17.5→20.0 (**+2.5**, wrong way;
  KEEP wanted −6). Ash V0 arm 1 −4.5. Digest moved
  (`4608c2d6…`); not re-pinned. Locale untouched. H39
  landscape already FAIL C1–C3 (`595377b`); this is not a
  second 5h. Working SHA remains H39 `a0d608a5…`. Do not
  landscape. Do not raise Ash HP. Relic stack still
  later-phase. Readout:
  [`2026-08-21-421-hypothesis-54.md`](2026-08-21-421-hypothesis-54.md).
- **H55 (`cards.catalyst` cost 1→2, keep double/triple) is
  reverted — C2 spend, same class as H42.** Snapshot:
  `docs/balance/data/421-h55/phase-a.json`. Arm 2
  **21.5 / 7.5 / 16.0 / 5.0**. Holdout 55.0 / 22.0 / 66.0 /
  34.5. Ash−Dusk **+11.0 / +12.5 pp**. Ash V0 arm 1
  77.5→67.5 (**−10.0**, real). Arm 2 no clog. Dusk
  bit-identical. Digest unchanged. Do not tax Bellows 1→2
  again this loop. Relic-stack coal/Core is the same
  smolder-top family — still later-phase. H39 landscape
  already FAIL C1–C3 (`595377b`); this is not a second 5h.
  Working SHA remains H39 `a0d608a5…`. Do not landscape.
  Do not raise Ash HP. Readout:
  [`2026-08-21-421-hypothesis-55.md`](2026-08-21-421-hypothesis-55.md).
- **H56 (`cards.risingLitany` ritual 2→4 / 3→5, keep cost 3)
  is reverted.** Snapshot:
  `docs/balance/data/421-h56/phase-a.json`. Arm 2
  **23.0 / 8.0 / 18.5 / 7.0**. Holdout 49.0 / 20.0 / 66.5 /
  35.5. Ash−Dusk **+17.5 / +15.5 pp**. Ash V0 arm 1
  77.5→73.0 (−4.5) and holdout −4.0. Dusk V0 holdout
  **−6.0** (wrong way). Digest moved (`3989243b…`); not
  re-pinned. H39 landscape already FAIL C1–C3 (`595377b`);
  this is not a second 5h. Working SHA remains H39
  `a0d608a5…`. Do not landscape. Do not raise Ash HP. Relic
  stack still later-phase. Readout:
  [`2026-08-21-421-hypothesis-56.md`](2026-08-21-421-hypothesis-56.md).
- **H57 (`cards.bastion` cost 3→2, upgrade 2→1, keep
  barricade) is noise — reverted.** Snapshot:
  `docs/balance/data/421-h57/phase-a.json`. Arm 2
  **21.5 / 7.0 / 18.5 / 7.0**. Holdout 58.0 / 22.5 / 69.0 /
  41.0. Ash−Dusk **+11.0 / +18.5 pp**. Ash V0 arm 1
  77.5→76.0 (−1.5) and holdout 70.5→69.0 (−1.5) both |delta|
  <6. Digest moved (`d461b851…`); not re-pinned. Locale
  untouched. Not 1-cost sustain/ward. H39 landscape already
  FAIL C1–C3 (`595377b`); this is not a second 5h. Working
  SHA remains H39 `a0d608a5…`. Do not landscape. Do not
  raise Ash HP. Relic stack still later-phase. Readout:
  [`2026-08-21-421-hypothesis-57.md`](2026-08-21-421-hypothesis-57.md).
- **H58 (`cards.momentum` 6→10 grow 4→6 / 8→12 grow 6→8,
  keep cost 1) is noise — reverted.** Snapshot:
  `docs/balance/data/421-h58/phase-a.json`. Arm 2
  **26.5 / 7.5 / 19.0 / 7.5**. Holdout 55.5 / 23.0 / 70.0 /
  38.5. Ash−Dusk **+14.5 / +15.5 pp**. Ash V0 arm 1
  77.5→76.0 (−1.5) and holdout −0.5 both |delta| <6. Dusk V0
  arm 2 +5.0 (shared 1-cost attack paid random Dusk; H53
  pattern). Digest moved (`0308276c…`); not re-pinned. Not
  1-cost sustain/ward. H39 landscape already FAIL C1–C3
  (`595377b`); this is not a second 5h. Working SHA remains
  H39 `a0d608a5…`. Do not landscape. Do not raise Ash HP.
  Relic stack still later-phase. Readout:
  [`2026-08-21-421-hypothesis-58.md`](2026-08-21-421-hypothesis-58.md).
- **H59 (`cards.cripple` Fervor snuff −2→−4 / −3→−5, keep
  cost 1 exhaust) is noise — reverted (bit-identical).**
  Snapshot: `docs/balance/data/421-h59/phase-a.json`. Arm 2
  **21.5 / 8.0 / 18.0 / 6.5**. Holdout 55.0 / 22.0 / 70.5 /
  39.5 (bit-identical). Ash−Dusk **+15.5 / +17.5 pp**. Ash V0
  arm 1 77.5→77.5 (+0.0). Digest unchanged. Exhaust uncommon
  did not fire n=200 planned. Not relic-stack, not Dusk chip,
  not 1-cost sustain/ward. H39 landscape already FAIL C1–C3
  (`595377b`); this is not a second 5h. Working SHA remains
  H39 `a0d608a5…`. Do not landscape. Do not raise Ash HP.
  Relic stack still later-phase. Readout:
  [`2026-08-21-421-hypothesis-59.md`](2026-08-21-421-hypothesis-59.md).
- **H60 (`cards.lunge` Dimmed 1→2 / 2→3, keep 6/9 dmg and
  cost 1) is reverted — Ash V0 arm 2 clog + paid Dusk.**
  Snapshot: `docs/balance/data/421-h60/phase-a.json`. Arm 2
  **23.5 / 7.5 / 24.0 / 7.0**. Holdout 62.5 / 30.5 / 74.5 /
  44.0. Ash−Dusk **+12.0 / +13.5 pp**. Ash V0 arm 2
  17.5→24.0 (**+6.5 clog**). Ash V0 arm 1 +4.5 and holdout
  +4.0 both under 6. Dusk V0 arm 1 **+8.5** and holdout
  **+7.5** (shared Dimmed paid Dusk more). Digest moved
  (`8964337a…`); not re-pinned. Do not buff Dimmed on a
  1-cost common again this loop (H44/H45 take-less-damage
  family). Not relic-stack, not Dusk chip, not H55
  smolder-top. H39 landscape already FAIL C1–C3 (`595377b`);
  this is not a second 5h. Working SHA remains H39
  `a0d608a5…`. Do not landscape. Do not raise Ash HP. Relic
  stack still later-phase. Readout:
  [`2026-08-21-421-hypothesis-60.md`](2026-08-21-421-hypothesis-60.md).
- **H61 (`cards.heavyBlow` 12→16 / 16→20, keep cost 2 and no
  base chip) is reverted — Ash V0 arm 1 −6.0 wrong way.**
  Snapshot: `docs/balance/data/421-h61/phase-a.json`. Arm 2
  **21.5 / 8.5 / 18.5 / 5.0**. Holdout 56.5 / 23.5 / 69.5 /
  37.5. Ash−Dusk **+13.0 / +14.0 pp**. Ash V0 arm 1
  77.5→71.5 (**−6.0**, wrong way; H52 class). No arm-2 clog.
  Digest moved (`1f796b9c…`); not re-pinned. Do not buff
  2-cost common smash again this loop. Not relic-stack, not
  Dusk chip, not 1-cost Dimmed/ward/regen, not H55
  smolder-top. H39 landscape already FAIL C1–C3 (`595377b`);
  this is not a second 5h. Working SHA remains H39
  `a0d608a5…`. Do not landscape. Do not raise Ash HP. Relic
  stack still later-phase. Readout:
  [`2026-08-21-421-hypothesis-61.md`](2026-08-21-421-hypothesis-61.md).
- **H62 (`arts.mendglass` heal 8→16, keep cost 4) is noise —
  reverted (bit-identical, H38 art pattern).** Snapshot:
  `docs/balance/data/421-h62/phase-a.json`. Arm 2
  **21.5 / 8.0 / 17.5 / 6.5** (bit-identical). Holdout
  55.0 / 22.0 / 70.5 / 39.5 (bit-identical). Ash−Dusk
  **+15.5 / +17.5 pp**. Ash V0 arm 1 77.5→77.5 (+0.0).
  Digest unchanged. Optional lantern arts do not fire Phase A
  planned (pilots keep aspect art). Do not retune Emberveil,
  Mendglass, Stoke, or Beacon this loop. Not relic-stack, not
  Dusk chip, not 1-cost Dimmed/ward/regen, not 2-cost common
  smash, not H55 smolder-top. H39 landscape already FAIL
  C1–C3 (`595377b`); this is not a second 5h. Working SHA
  remains H39 `a0d608a5…`. Do not landscape. Do not raise
  Ash HP. Relic stack still later-phase. Readout:
  [`2026-08-21-421-hypothesis-62.md`](2026-08-21-421-hypothesis-62.md).
- **H63 (`cards.uppercut` Dimmed 1→2 / 2→3, keep 10/13 dmg,
  cost 2, chip 1/2) is reverted — paid Dusk planned.**
  Snapshot: `docs/balance/data/421-h63/phase-a.json`. Arm 2
  **23.0 / 8.5 / 20.5 / 7.5**. Holdout 54.5 / 26.0 / 71.5 /
  40.5. Ash−Dusk **+17.0 / +14.5 pp**. Ash V0 arm 1 +1.0 and
  holdout +1.0 both under 6. Ash V0 arm 2 +3.0 (no clog —
  cost-2 theory held). Dusk V0 arm 1 53.5→63.0 (**+9.5**,
  H60 pattern). Digest unchanged. Do not buff Dimmed on
  shared attacks this loop. Not relic-stack, not Dusk chip,
  not 1-cost Dimmed/ward/regen, not 2-cost common smash, not
  H55 smolder-top, not lantern arts. H39 landscape already
  FAIL C1–C3 (`595377b`); this is not a second 5h. Working
  SHA remains H39 `a0d608a5…`. Do not landscape. Do not
  raise Ash HP. Relic stack still later-phase. Readout:
  [`2026-08-21-421-hypothesis-63.md`](2026-08-21-421-hypothesis-63.md).
- **Relic stack is a later-phase binding lesson, not this loop.** Do not
  retune these now. `ashenCore` (Ash starter) = 3 start Smolder;
  `smolderingCoal` (uncommon, `ashSermon`) = +2; together **5**; triangular
  tick 5+4+3+2+1 = **15** DoT with zero Ashbite. H11 already no-ops both
  for Dusk (`_player_smolder_blocked` in `domain/rules/combat.gd`).
  `hollowCrown` = +1 energy/turn, −10 max HP. H21 starter energy 4 failed
  C2 (Ash arm 2 56.5%) and |gap| +29.5. Crown can re-apply energy on the
  mixed landscape. Phase A holdout is `--mix=none`. Landscape mix
  `A_modest_linear` is 15% elite 2nd relic; Ash pilot prefers coal
  (`relicAshBonus`). H22 gap: Phase A Ash V5 holdout 50% vs landscape
  Vow-5 Ash **90.5%**. If a later landscape trips Vow-5, that is
  relic-stack/mix, not a reason to revert H27 Dusk 64 or to raise Ash HP.
  Later isolated loop: coal 2→1 and/or ashenCore 3→2, Crown energy, and/or
  smolder decay-2. James confirmed 2026-08-20 this is next-phase.

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
