# The RC Bar — iOS Release Candidate

Written by the grilling on [#164](https://github.com/fol2/glassvow/issues/164), part of the
commercial-push map [#156](https://github.com/fol2/glassvow/issues/156). This document is the
falsifiable bar the release gate ([#108](https://github.com/fol2/glassvow/issues/108)) checks a
build against — `docs/commercial-game-delivery.md` §6 made concrete. It composes decisions made
elsewhere; where a pillar's detail lives in another document or ticket, this file binds it by
reference and does not restate it.

**Scope.** This bar instantiates for the **iOS release candidate**: floor devices **iPhone SE
(2nd generation)** and **iPad (8th generation)** per
[#158](https://github.com/fol2/glassvow/issues/158). The Android phase re-instantiates this same
bar with the Android floor pair (Galaxy A13 LTE, Galaxy Tab A8); nothing in this document
forecloses that, Steam/PC/Mac, or expansion-pack IAP.

## How the bar works

- **Nine pillars, P0–P8. The bar is passed when every pillar passes** and the RC signature
  receipt (below) is signed. There is no partial pass.
- **Evidence tiers.** P2/P3/P4 produce **immutable evidence packets** (house style: evidence
  commit with manifest and offline verifier, bound to exact hashes). P5/P7/P8 record as
  **ticket comments** (the rubric's own sign-off protocol; a linked compliance checklist; the
  defect ledger). P0/P1 evidence is recorded directly in the RC signature receipt.
- **Waivers.** Rubric criteria may be waived only through the rubric's recorded-waiver
  mechanism, on the executing ticket. P1, P2, P4, and P7 are **not waivable**: a miss is not
  argued past the gate — it returns to the map as a new wayfinder decision, per
  [#158](https://github.com/fol2/glassvow/issues/158)'s rule. P8 waivers (per-defect, by James,
  with reason) are part of that pillar's mechanism, not an escape from it.
- **Builds.** The RC artifact is the distribution-signed `glassvow.ipa` (P0). Where
  distribution signing denies evidence access — the app container, byte-level save
  fingerprints — evidence is captured on the **twin build**: the exact RC commit, the exact
  release export configuration (no `dev_tools`, never a Dev Review build), differing **only**
  in signing identity. The twin's equivalence claim is exactly that sentence; each packet that
  uses the twin states it.

### When evidence expires (scoped reset)

The bar binds one exact RC commit. If the RC commit changes:

| Diff since evidenced commit | Consequence |
|---|---|
| Docs-only | All evidence carries |
| Any code, asset, or export-preset change | P1 re-runs; P2, P3, P4 re-run; P5 re-verifies only the surfaces the change touches; P7 re-checks build-config items only (SDK, Info.plist keys, signing) |
| Player-facing-major change (James's judgment) | Additionally, P6 beta round repeats |

## P0 — Build identity

- [ ] The RC commit is named. The distribution-signed `glassvow.ipa` is produced from it per
      `docs/release-signing.md`, from the pinned Godot 4.7.1 templates.
- [ ] The version stamp is honest: marketing version and build number identify this RC, and no
      player-facing surface carries a foreign or benchmark hash.
- [ ] `dev_tools` is absent: no Developer Console entry point is reachable anywhere in the
      build ([#159](https://github.com/fol2/glassvow/issues/159): a store or release-candidate
      build never carries that capability).
- [ ] Fresh-install boot: on each floor device, a clean install (no prior app data) cold-boots
      to the title screen.

## P1 — Repo gates green on the RC commit

All from the repo root, on the exact RC commit, plus CI green on the same head:

- [ ] `godot --version` prints 4.7.1.stable (the engine pin — a PASS from any other editor
      version is not evidence)
- [ ] `tools/check_imports.sh`
- [ ] `tools/check_scripts.sh`
- [ ] `godot --headless -s res://tests/run_all.gd` exits 0 (PASS)
- [ ] `python3 tools/check_anchors.py` and `python3 tools/check_web_anchors.py`
- [ ] CI green on the exact RC head

## P2 — Performance floor

The five gates of [#158](https://github.com/fol2/glassvow/issues/158)'s resolution, bound by
reference, on **both floor devices**, both locales, release/profileable build, unplugged, fixed
50% brightness, controlled room temperature, cold run plus 30-minute heat-soaked run over the named route (cold
launch/save-load, worst visible map transition, act-1 Leviathan workload with 96 sustained VFX
particles):

- [ ] Frame pacing: post-warm-up whole-frame P95 ≤16.67 ms, P99 ≤25.00 ms, ≤1.0% missed display
      deadlines, no frame >50.00 ms. Averages alone do not pass.
- [ ] Sustained performance: final five minutes regress ≤10% vs the first measured five minutes
      (P95 frame time, missed-deadline rate).
- [ ] Thermals: never `serious`/`critical` (iOS/iPadOS); complete platform-native thermal trace
      preserved.
- [ ] Battery: ≤10 percentage points over the 30-minute route, device at ≥80% battery health
      where the OS exposes it; start/end levels and platform-native power trace recorded;
      charging runs invalid.
- [ ] Memory stability: no OS memory-pressure termination, no monotonic retained growth across
      two consecutive route repetitions; platform-native peak and post-route figures reported.
- [ ] **Cold save-load ≤2 s** on each floor device: from tapping Continue to the restored run
      being interactive. Cold launch → title-interactive is
      measured and recorded in the same packet, **report-only** for this RC — gating launch
      time would be a new decision.

Evidence: immutable packet. A miss on one device creates measured optimisation work; if the
gate cannot be met without a renderer, fidelity, frame-rate, or supported-device change, that
trade-off returns to the map ([#158](https://github.com/fol2/glassvow/issues/158)).

## P3 — Full-run QA on device

The [#107](https://github.com/fol2/glassvow/issues/107) protocol (`docs/p8-full-run-qa.md`)
re-instantiated on floor hardware, by touch, on the twin build:

- [ ] **Four full journeys = 2 heroes × 2 locales**, split two per floor device (each device
      plays one hero in en and the other in zh-Hant, covering both aspect classes). A journey
      runs title → full run to the shipped terminus (the Act IV terminus once
      [#175](https://github.com/fol2/glassvow/issues/175)'s arc lands) → Dawn → back to the
      Vigil/title. Touch only; no keyboard, no mouse, no editor.
- [ ] **One spot-check journey on the actual distribution-signed TestFlight build** (either
      device, either locale), demonstrating twin-equivalence in play.
- [ ] Every defect found is filed as a `bug` issue before the pillar closes — P8's ledger is
      the fail-closed net; QA finding things is the protocol working, not the pillar failing.

Evidence: immutable packet (route boundaries, screenshots/recordings, run seeds).

## P4 — Save integrity across process death

The [#107](https://github.com/fol2/glassvow/issues/107) process-kill matrix re-run on the
**iPhone SE 2**, on the twin build (container access requires development signing):

- [ ] All ten checkpoints — rest, event, shop, treasure, eventPending, map, combat, partial
      reward, boss-relic, progressed Dawn — each: true process kill (app terminated by the OS,
      not backgrounded; termination verified), fresh process on relaunch, durable-fingerprint
      equality on the restored state, and a real-input continuation by touch.
- [ ] A save/load comparison inside one process is not substituted for process-kill evidence
      (the [#107](https://github.com/fol2/glassvow/issues/107) rule, unchanged).

Evidence: immutable packet.

## P5 — Rubric sign-offs

`docs/commercial-rubric.md` is the bar's content here; this pillar binds its two tiers:

- [ ] **Tier 1 — sign-off.** Every rubric surface (Global inherited each time, the eight
      surfaces, Onboarding, and the cross-surface Story arc) is signed by James on the primary
      phone, on a release export, both locales, recorded as sign-off comments on the executing
      tickets per the rubric's protocol.
- [ ] **Tier 2 — floor re-verify.** Every surface's full criteria list runs once on floor
      hardware: **iPhone SE 2 in zh-Hant** (smallest screen × riskiest script), **iPad 8 in
      en** (4:3 aspect axis). Both locales are inside the gate across the pair. Recorded as a
      consolidated re-verify table on the release-gate ticket
      ([#108](https://github.com/fol2/glassvow/issues/108)).
- [ ] Any waiver exists only as the rubric's recorded-waiver mechanism prescribes.

## P6 — External beta round

- [ ] One external beta round completed and survived, against the pass criteria defined by
      [#166](https://github.com/fol2/glassvow/issues/166). This bar does not pre-empt that
      design; the receipt links whatever evidence #166 prescribes.

## P7 — Compliance checklist (iOS)

From the store-compliance dossier
(`docs/research/2026-08-13-store-compliance-dossier.md`, [#162](https://github.com/fol2/glassvow/issues/162)):

**Accounts and declarations**

- [ ] Apple Developer Program membership active (Team `V45S7U2LZB`); **Paid Apps Agreement**
      signed by the Account Holder, banking and tax complete.
- [ ] **EU DSA trader status** declared and verified (address/phone/email; shown on the EU
      product page).
- [ ] Updated **age-rating questionnaire** answered honestly — expected 9+ (Cartoon or Fantasy
      Violence); Gambling, Simulated Gambling, Loot Boxes, Contests all No.

**Build and metadata**

- [ ] Built and archived with **Xcode 26 / iOS 26 SDK** (in force since 2026-04-28);
      distribution-signed per `docs/release-signing.md`.
- [ ] `ITSAppUsesNonExemptEncryption = false` in the exported project's Info.plist.
- [ ] **Privacy policy URL live in en and zh-Hant**, set in App Store Connect, **and linked
      inside the app** (settings/about — Apple 5.1.1(i); this is a product feature and ships in
      the build).
- [ ] **Privacy nutrition label** matches the shipped binary:
      - Baseline (no SDK): **"Data Not Collected"**.
      - If the Sentry SDK ([#161](https://github.com/fol2/glassvow/issues/161)) is in the tree
        at RC: declare Diagnostics → Crash Data (plus Performance/Other Diagnostic Data and
        Identifiers as configured), not-linked/not-tracking posture per the SDK configuration,
        a consent posture per Apple 5.1.1(ii), and the privacy policy updated to match.
- [ ] **Store presence complete and compliant**: name ≤30 chars, subtitle ≤30, keywords ≤100,
      description, support URL, 1024×1024 icon in the asset catalog, screenshots for
      **6.9" iPhone and 13" iPad** (1–10 each, real gameplay screens per 2.3.3, all metadata
      appropriate for 4+ per 2.3.8, unique name with no keyword stuffing, trademarks, or
      pricing in metadata per 2.3.7), in **both locales**. Content is produced by its own
      tickets; this pillar checks presence and compliance, not taste.

Evidence: a checklist comment linking each item's proof (screenshots of App Store Connect
state, the policy URL, the Info.plist diff).

## P8 — Fail-closed defect ledger

- [ ] At the RC snapshot, the ledger enumerates **all open `bug` issues** and every held/waived
      item referenced by the map. Zero open bugs, or each remaining one explicitly waived by
      James with a reason, in the ledger comment. Missing, duplicate, or unknown rows fail the
      ledger ([#107](https://github.com/fol2/glassvow/issues/107) house style). The ledger is
      refreshed immediately before the RC is declared.

## The RC signature receipt

The bar's final act, and the only place "RC" is pronounced: a signed comment by James on the
release-gate ticket ([#108](https://github.com/fol2/glassvow/issues/108)) binding:

- the exact product head (the RC commit),
- the `.ipa` artifact hash,
- each pillar's evidence address (packet commits for P2/P3/P4; comment permalinks for
  P5/P7/P8; for P6, whatever evidence #166 prescribes),
- P0/P1 evidence inline (gate log, CI run link),
- and the sentence "this build is the release candidate."

A verifier passing proves the evidence clears the gate; the signature is the distinct PM
approval — the two are never merged (`docs/commercial-game-delivery.md` §5's rule).
