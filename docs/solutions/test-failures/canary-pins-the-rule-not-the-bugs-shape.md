---
title: A canary for a platform-dependent engine bug pins the rule, never the bug's shape
date: 2026-08-01
category: test-failures
module: tests/layout-book
problem_type: test_failure
component: testing_framework
severity: high
symptoms:
  - "Hosted CI red for two days on test_layout_book while the local suite passed 13/13"
  - "CI failure text names the canary's own assertion: 'a const typed Dictionary still hands back an empty-looking packed array'"
  - "The same official Godot build (4.7.1.stable a13da4feb) reports size() 0 on macOS and size() 24 on Linux for the same two-item array"
root_cause: logic_error
resolution_type: test_fix
tags: ["canary", "engine-bug", "platform-dependent", "ci", "packed-string-array", "typed-dictionary"]
---

# A canary for a platform-dependent engine bug pins the rule, never the bug's shape

## Problem

`tests/test_layout_book.gd` carries a canary for a Godot 4.7.1 hazard: a
`PackedStringArray` taken out of a `const` typed Dictionary through a
runtime-built `StringName` key lies about itself (`has()` false, `size()` 0 on
the machine that discovered it), which is why `LayoutBook.fields()` routes
around the subscript. The canary asserted the lie's exact shape —
`size() == 0`. Hosted CI (Linux) had been red since 2026-07-29 while every
local (macOS) run passed, because the same official build wears the bug
differently per platform.

## Root cause

The engine bug is platform-dependent, and its costumes do not even agree with
each other: macOS answers `size() == 0` for the two-item array; Linux answered
`size() == 24` (CI runs 30672164735 and 30673205223) — a third shape, neither
the pinned lie nor the truth. Any assertion that enumerates observed shapes is
a bet that the set is closed, and a platform the author never ran becomes a
permanent red gate.

## Solution

Pin the rule the workaround depends on, not the shapes the bug has been seen
wearing. The portable assertion in `tests/test_layout_book.gd` is now: the raw
subscript's output must differ from the workaround's known-good output
(`LayoutBook.fields()`), element for element. First landed as a two-shape
enumeration (0 or the truth) in the same fix series — Linux's 24 broke that
within one CI round, which is what forced the rule form.

```gdscript
var real: PackedStringArray = LayoutBook.fields(&"stage")
var raw_matches_truth: bool = raw_order.size() == real.size()
if raw_matches_truth:
    for i: int in range(real.size()):
        if raw_order[i] != real[i]:
            raw_matches_truth = false
            break
_check(fails, not raw_matches_truth,
    "the raw subscript still cannot be trusted (raw size %d, real size %d)"
        % [raw_order.size(), real.size()])
```

## Why this works

The canary's real question was never "is size() zero?" — it was "may
`fields()` go back to a plain subscript?". The answer is yes only when the
subscript returns exactly the truth, and that predicate is platform-portable
by construction. The day a platform hands back the real array, the canary
fails THERE, which is the alert working as intended — and the workaround may
only be removed when every shipped platform fails it, which is the rule the
original comment stated and the original assertion did not implement.

## Prevention

- When pinning an engine bug, write the assertion as the INVARIANT the
  workaround needs ("raw output ≠ trusted output"), never as the observed
  wrong value — observed wrong values are per-platform costumes.
- A canary that has only ever run on one platform is unproven: hosted CI is
  the second platform, and its first run against a new pin is part of the
  pin's verification, not an afterthought.
- When a canary fires on a platform where the bug seems fixed, treat it as
  the designed signal to re-evaluate the workaround everywhere — not as a
  test to loosen on the platform that fired.
