---
title: "A typed array produced through a ternary branch throws at runtime, and --check-only is blind to it"
date: 2026-08-01
category: runtime-errors
module: application
problem_type: runtime_error
component: service_object
symptoms:
  - "Abandoning a run did nothing visible — no run-end screen, no route forward; the modal stayed up"
  - "Runtime error: 'Trying to assign an array of type Array to a variable of type Array[Dictionary]'"
  - "godot --headless --check-only (warnings-as-errors) passed clean on the offending file"
  - "Test suite green — no test drives the abandon route, so CI never executed the throwing line"
root_cause: logic_error
resolution_type: code_fix
severity: high
related_components:
  - testing_framework
tags: [godot, gdscript, godot-4-7, typed-array, ternary, silent-failure, engine-trap, parse-gate-blindness, dead-route]
---

# A typed array produced through a ternary branch throws at runtime, and --check-only is blind to it

## Problem

In Godot 4.7.1 GDScript, assigning an untyped array literal to a typed-array
variable **through a ternary expression** is a runtime error, not a parse
error. The parse gate (`godot --headless --check-only`, warnings-as-errors)
passes silently; the throw fires only when the line executes. In
`application/main.gd` this made the abandon-run route — the "THE VOW IS SET
ASIDE" run-end screen (`presentation/run/run_end_screen.gd:334`) — dead from
the commit that introduced the ternary until issue #58 was fixed in PR #59.

## Symptoms

- Abandoning a run did nothing visible: no run-end screen, no route forward.
  Carving a bequest recorded its effect but the offer screen never
  acknowledged it.
- `godot --headless --check-only` on every `.gd` file: clean. Suite: green —
  no test drives the abandon route.
- The break shipped and stayed shipped until a design reviewer physically
  drove the screen during the PR #57 review; the broken code was outside that
  PR's diff. Filed as issue #58, fixed in PR #59.

## What Didn't Work

- **Relying on the parse gate.** `--check-only` with warnings-as-errors sees
  nothing wrong with the ternary; the mismatch is detected only at assignment
  time, at runtime.
- **Relying on the test suite.** No test exercises the abandon route, so a
  runtime-only throw on that path is invisible to CI. Green gates proved
  parseability, not reachability.

## Solution

Before (buggy — introduced by commit 950573f, historical reference):

```gdscript
var choices: Array[Dictionary] = _bequest_choices() \
	if outcome == "death" and not bequest_answered else []
```

After (current, `application/main.gd:1671-1676`):

```gdscript
# No ternary: an untyped `[]` does not convert to Array[Dictionary]
# through one — it throws at runtime and --check-only cannot see it
# (issue #58; the ternary variant of the typed-array .new() trap).
var choices: Array[Dictionary] = []
if outcome == "death" and not bequest_answered:
	choices = _bequest_choices()
```

`_bequest_choices()` returns `Array[Dictionary]`
(`application/main.gd:1722`), so assigning from the call is fine; only the
`else []` branch was fatal.

## Why This Works

GDScript converts untyped array literals to typed arrays only at specific
boundaries. `var choices: Array[Dictionary] = []` is a **direct assignment**
of a literal — the compiler converts it. `choices = _bequest_choices()`
assigns from a call whose declared return type already matches — no
conversion needed. The ternary, by contrast, first resolves both branches to
a common type — untyped `Array`, because one branch is an untyped literal —
and only then assigns, so the typed variable receives an untyped `Array` and
the runtime refuses it.

## Prevention

- **Language rule.** Untyped array literals convert to typed arrays at direct
  assignment and at ordinary method-call boundaries, but **not** through
  `.new(...)` constructor arguments and **not** through ternary branches.
  Both variants throw at runtime only; `--check-only` catches neither. The
  `.new()` variant was hit first (2026-07-26, dead buttons in combat wiring;
  fixed the same day with pre-typed locals — session history). When a
  typed-array variable needs a conditional value, declare it with a typed
  empty literal first and assign inside the branch; never put a bare `[]` in
  a ternary that feeds a typed variable.
- **Process rule.** Routes reachable only by real gameplay need a headed
  drive or a probe — the parse gate proves nothing about them. This bug lived
  on a route no test drives and no gate executes; it was found only because a
  reviewer drove the screen by hand, on code outside the PR under review. If
  a change touches a route the suite does not execute, drive that route
  before calling the change done.

## Related Issues

- Issue #58 (the dead abandon route) and PR #59 (the fix, merged).
- `docs/solutions/logic-errors/const-typed-dictionary-drops-its-packed-array-type.md`
  — sibling silent-failure trap: a typed container that betrays its type at
  runtime while every static gate passes, with the same test-hole lesson
  (a loop over a broken container iterates zero times and the suite still
  reports PASS).
