---
title: A borrowed shader const with splice markers is a two-part loan — take the string AND its splice chain
date: 2026-08-01
category: ui-bugs
module: presentation/reward
problem_type: ui_bug
component: tooling
severity: high
symptoms:
  - "The reward husk rendered as a white unshaded glowing square instead of the enemy's painted body"
  - "No error at the call site — a shader that fails to compile falls back silently to a default material"
  - "The borrowing code looked correct and had once been reviewed as correct"
root_cause: wrong_api
resolution_type: code_fix
tags: ["shader", "splice-marker", "cross-lane-borrowing", "silent-failure", "source-existing-is-not-rendering"]
---

# A borrowed shader const with splice markers is a two-part loan

## Problem

`RewardStage` borrowed `EnemyView.BODY_SHADER` (a public const, sanctioned as
a tracked dependency) and fed the RAW string to its husk material. That
shader's fragment calls `eaten()` and `variant_tint()` — functions that only
exist after the lender's `with_erode()` / `with_tint()` splices replace the
`//__ERODE__` and `//__TINT__` markers. The unspliced shader never compiled,
and the husk stood as a glowing square through an entire build stage whose
one judge question was "does this read as a solid object in a lit room?".

## Symptoms

A shader compile failure is silent at the call site: Godot renders the mesh
with a white unshaded fallback, pushes the error to a console nobody is
watching during a lab session, and everything else on screen stays normal.
The borrower's code reads plausibly — the const exists, the parameter names
match — which is this repo's `source-existing-is-not-rendering` lesson
wearing a materials costume.

## What didn't work

Nothing was "tried and failed" — the failure mode is that nothing LOOKED
broken at the code level, so nothing was tried at all until the capture was
actually looked at. The marker set had also GROWN after the borrower was
written (the TINT splice arrived with the variant-cast work in PR #14), so
even a borrower that was once whole can be broken later without any edit to
its own file.

## Solution

Borrow through the lender's own composition call, exactly as the lender's
own compile site does — never the raw const:

```gdscript
# WRONG — the raw string still contains //__ERODE__ and //__TINT__ markers,
# and its fragment calls functions those splices provide:
sh.code = EnemyView.BODY_SHADER

# RIGHT — the same composition the lender's own compile site uses:
sh.code = EnemyView.with_tint(EnemyView.with_erode(EnemyView.BODY_SHADER))
```

Fixed in PR #19 (`presentation/reward/reward_stage.gd`, `_build_husk`); the
lender's splice helpers and compile sites live in
`presentation/combat/enemy_view.gd` (`with_erode`, `with_tint`).

## Why this works

The spliced form is the only form the lender itself ever compiles — the raw
const is an implementation detail of the splice system, not a public
surface. Composing through the lender's helpers also means a NEW marker
added by the lender flows to every borrower automatically, because the
helper chain is the same one the lender's compile site grows through.

## Prevention

- When borrowing a shader const across lanes, grep the string for `//__`
  markers first; a marker means the const is HALF of a contract and the
  splice helpers are the other half.
- Borrow the lender's composition call, not the const. If the lender has no
  single composition helper, that is the thing to ask the owning lane for.
- When ADDING a splice marker to a shared shader const, grep the repo for
  every consumer of that const — each raw-string borrower is a silent break
  the moment the marker's function is called from the fragment.
- A 3D surface that renders as a flat white/glowing plate is the shader
  compile failure signature — check the shader before the lighting.
