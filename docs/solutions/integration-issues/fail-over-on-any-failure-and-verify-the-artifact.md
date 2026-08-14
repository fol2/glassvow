---
title: "Fail over on any backend failure, and verify the artifact not the exit code"
date: 2026-08-14
category: integration-issues
module: developer-tools/run-imagegen
problem_type: integration_issue
component: tooling
severity: high
symptoms:
  - "44 of 60 requested illustrations never arrived while the delegation chain reported no chain-level failure"
  - "The cursor-agent fallback ran zero times across 60 attempts, although Cursor was healthy and later produced 43/43 on re-run"
  - "24 codex attempts died on OpenAI content-filter false positives and 14 on OAuth `invalid_grant: Grant not found`, none of which match RATE_RE"
  - "codex exited 0 after printing a success line without writing any image file"
root_cause: logic_error
resolution_type: code_fix
related_components:
  - "development_workflow"
  - "testing_framework"
tags: [subagent-delegation, image-generation, failover, codex-cli, cursor-agent, whitelist-gate, silent-failure, exit-code-verification]
---

# Fail over on any backend failure, and verify the artifact not the exit code

**Every path in this document is an absolute path in the user's global `~/.claude/`
tooling, not a repo-relative path.** `run-imagegen.sh` and `models.env` live in
`/Users/jamesto/.claude/scripts/subagents/`, which is **not a git repository**
(`git rev-parse` there returns `fatal: not a git repository`). There is therefore no
commit or PR to cite for this fix: it is a working-tree edit to files outside any
repo, and the only durable record of it is this learning plus the state of the two
files themselves. Line citations below are against those files as they stand today
(2026-08-14).

## Problem

`run-imagegen.sh` is a two-backend chain for quality image generation: `codex exec`
against the ChatGPT image tool first, `cursor-agent` second. Its own header states the
intent — Cursor is "the fallback for ANY codex failure while the subscription
date-guard allows" (`/Users/jamesto/.claude/scripts/subagents/run-imagegen.sh:2-4`).

Before the fix the script did not implement that intent. The decision to fall back was
gated on a whitelist regex of failure strings:

```bash
RATE_RE='429|rate.?limit|too many requests|usage.?limit|quota'
```

Cursor was reached only when codex failed *for quota reasons*. Every other way codex
can fail — and it has several — terminated the run with no second attempt, while a
healthy, paid-for backend sat unused.

A whitelist is the wrong shape for a fallback trigger. It requires the author to have
enumerated, in advance, every string a third-party CLI and its upstream provider will
ever emit on failure. The set of things that can go wrong is open; the set of strings
in `RATE_RE` was five. Everything outside those five was silently treated as
"unfallbackable" rather than as "unknown failure, try the other backend".

A second defect compounded it, in the opposite direction: the wrapper had no success
check beyond exit status. `codex` can exit 0 without writing the image — the comment
now in the script records the observed behaviour, "codex has been observed printing
'已生成' and exiting 0 without writing anything"
(`/Users/jamesto/.claude/scripts/subagents/run-imagegen.sh:15-18`). So the chain both
refused to retry real failures and reported success for non-failures that produced no
file.

## Symptoms

Measured across one batch of 60 image-generation attempts. These counts are as
recorded during the generation run itself, not something re-measured while writing
this document; treat the breakdown as the run's own log rather than an independent
observation.

- **16 of 60 succeeded.** 44 failed.
- **24 failures were an OpenAI content-filter false positive.** Ordinary dark-fantasy
  art prompts were flagged as a "cybersecurity risk"; agent-visible text included
  `Content flagged by image generation provider's safety filter (cybersecurity risk)`.
  One agent recorded the trigger terms as "(lantern, mask, cloaked figure, flail)".
- **14 failures were OAuth/credential errors** — `invalid_grant: Grant not found`.
- **6 failed other ways**, including the distinct and more dangerous case
  `Image generation returned success message ("已生成") but the file was not created at
  the specified path` — a *reported success* with no artifact.
- **Zero fallbacks fired**, across all 44. None of those strings match `RATE_RE`.
  Cursor was healthy for the entire batch.

The last two bullets are the load-bearing ones. The bug was not that images failed —
upstream providers fail. The bug was that a working second backend was never asked,
and that one class of failure was being counted as a success.

## What Didn't Work

**1. Re-routing the 44 to a different backend agent.** The first response was to
re-run the failures through `grok-media` (`run-grok-media.sh`, which execs the Grok
Build CLI —
`/Users/jamesto/.claude/scripts/subagents/run-grok-media.sh:11`). All 44 returned HTTP
`402 Payment Required`; the balance was exhausted. This was a genuine dead end and
unrelated to the bug — but it was also the thing that forced the actual diagnosis. With
credits available, the batch would have been re-routed around the defect and
`run-imagegen.sh` would still be shipping a whitelist today. The route-around being
blocked is why the root cause got looked at at all.

**2. Grok as a substitute on quality grounds.** An earlier style probe had already
shown the same Grok backend rendering the wrong art style for this task. Even fully
funded it was not an acceptable substitute, so "just use the other agent" was not a
fix even in principle.

**3. Widening the regex.** The obvious small diff — add
`content.?filter|flagged|safety|invalid_grant|unauthorized` to `RATE_RE` — was
considered and **rejected**. See *Why This Works*; this rejection is the centre of the
learning.

## Solution

Three changes to `/Users/jamesto/.claude/scripts/subagents/run-imagegen.sh`.

**1. The whitelist no longer gates the fallback.** The fallback now fires on any codex
failure, subject only to the `CURSOR_ENABLED_UNTIL` date guard
(`run-imagegen.sh:37-38`). `RATE_RE` survives at `run-imagegen.sh:13`, but its only
remaining job is choosing the wording of the terminal "re-route to run-grok-media.sh"
note once the date guard has already closed the Cursor path
(`run-imagegen.sh:51-55`) — it selects a message, never a behaviour. The rationale is
recorded in the file at `run-imagegen.sh:32-36`, ending: "A genuinely bad request now
costs one extra call instead of the whole image."

**2. A real success check.** The wrapper extracts a single image path from the task
text and requires that file to exist and be non-empty before either backend counts as
successful (`run-imagegen.sh:19-22`):

```bash
WANT="$(grep -oiE '/[^[:space:]"]+\.(png|jpg|jpeg|webp)' <<<"$TASK" | sort -u)"
if [ "$(printf '%s' "$WANT" | grep -c .)" -ne 1 ]; then WANT=""; fi

produced() { [ -z "$WANT" ] || [ -s "$WANT" ]; }
```

Deliberately conservative. Zero paths or two-or-more paths in the task text set
`WANT=""`, which makes `produced()` unconditionally true and drops the wrapper back to
plain exit status. Under-verifying beats false-failing: a check that occasionally
misses a bad run is tolerable, one that occasionally rejects a good image is not.

**3. Cursor is verified by the same gate.** `exec cursor-agent` became a normal call so
its status can be captured and tested against `produced()`
(`run-imagegen.sh:43-46`); failure now prints
`FAILED: cursor imagegen wrote no file${WANT:+ at $WANT}` and exits 1
(`run-imagegen.sh:47-48`). Under `exec`, the shell was replaced and no post-check was
possible — the second backend was exempt from the very check the first one had just
gained.

**Outcome.** Of the 44 lost images, one was recovered by a single manual `cursor-agent`
invocation, run to prove the backend was healthy at all; the remaining 43 were
regenerated in a batch, 43/43, zero failures. 16 + 1 + 43 = 60. Independently
checkable today: the run's output directory holds 106 files — 60 story images, 3 style
probes, and 43 per-attempt logs — and not one of them is zero-byte.

## Why This Works

**A fallback trigger must be a blacklist of "don't bother", never a whitelist of
"allowed to retry".** Widening `RATE_RE` was rejected because it fixes this incident
and leaves the shape intact — the next unenumerated failure string loses its image the
same way, and the fix is invisible until it has already cost a batch. The failure modes
of a third-party CLI are not knowable in advance, so the only sound default is: unknown
failure means try the other backend. The cost asymmetry settles it. A wrong fallback
costs one extra API call. A missed fallback costs the artifact, and costs it silently.

**Exit status is not a success signal for a tool whose product is a file.** The real
postcondition is "the file exists and has bytes in it", and that is what `produced()`
asserts. Checking the actual artifact rather than the process's self-report is what
catches the `已生成`-with-no-file class, which no amount of string-matching on output
ever could — the output there claims success.

**This is the same disease the repo has already documented once.** `CLAUDE.md` in this
repo records a structurally identical incident under *Verification*: `godot --headless
--check-only -s FILE` "writes its diagnostics to **stderr and exits 0 whatever it
found**", so the `|| exit 1` loop guarding the tree "could not fail and never once
caught a defect" until `tools/check_scripts.sh` replaced it with a grep of stderr
(`/Users/jamesto/Coding/glassvow/.claude/worktrees/kind-gliding-hejlsberg/CLAUDE.md:45-55`).
Both bugs are a check wired to the wrong signal, and both stayed invisible because the
wrong signal reads green. That is the family resemblance worth carrying forward: a
guard that cannot fail and a guard that passes look identical from outside.

## Prevention

**The test harness, and why it nearly lied.** A 7-case suite now covers every branch,
stubbing `codex` and `cursor-agent` as executables on `PATH`:

1. codex succeeds and writes the file → exit 0, no fallback
2. codex claims success but writes nothing → fallback fires
3. codex rejected by content filter → fallback fires
4. codex rate-limited → fallback fires
5. both backends produce nothing → exit 1, `FAILED: cursor imagegen wrote no file`
6. past the date guard, generic failure → the re-route note names the failure
7. past the date guard, rate-limit → the rate-limit wording is preserved

Cases 2 and 3 are the regression tests for this bug; 6 and 7 exist so the surviving
`RATE_RE` keeps its one remaining job. Measured 2026-08-14: **7 passed, 0 failed.**

**The trap inside the test — the most transferable part.** The first version of the
harness set `PATH="$STUB_DIR:$PATH"` on the invocation. It did not take effect.
`models.env` re-prepends its own directories when the script sources it:

```bash
PATH="${SUBAGENT_PATH_PREFIX:+$SUBAGENT_PATH_PREFIX:}$HOME/.local/bin:$HOME/.grok/bin:$HOME/.bun/bin:$PATH"
```

(`/Users/jamesto/.claude/scripts/subagents/models.env:9`) — and the real `cursor-agent`
lives in `~/.local/bin`, one of them. So the caller's prefix was shadowed, the stubs
never ran, **and the first test run went green while calling the real, paid backends.**
A test that reported success without testing anything.

Both forms measured directly, sourcing `models.env` and resolving the binary:

```
# BROKEN — shadowed by models.env:9
PATH="$STUB_DIR:$PATH"            → /Users/jamesto/.local/bin/cursor-agent   (the real one)

# WORKING — models.env keeps this ahead of its own additions
SUBAGENT_PATH_PREFIX="$STUB_DIR"  → $STUB_DIR/cursor-agent                   (the stub)
```

`SUBAGENT_PATH_PREFIX` is the supported hook, and `models.env:6-8` says so explicitly:
it "stays in front of them so tests' fake binaries are not shadowed by the real CLIs".
Use it for any test of these wrappers.

**Rules that follow.**

- When stubbing binaries for a script that sources a config file, **verify the stub was
  actually called** — assert on stub-only output, or check `command -v` inside the
  sourced environment. A passing test proves nothing until you have proof it ran
  against your substitute.
- A green gate covers less than it claims; check the coverage set and watch it fail in
  the target environment before trusting it (auto memory [claude]).
- Before believing a reported success from any automated run, verify the raw artifacts —
  files on disk, non-zero sizes, wall-clock plausibility — not the summary
  (auto memory [claude]). This bug produced exactly that failure mode twice: `已生成`
  with no file, and a test suite green against live backends.
- Never gate a fallback on an enumerated list of upstream error strings.
- When a tool's product is a file, assert on the file.

**Test-harness location caveat.** The suite currently lives at
`.../scratchpad/test_imagegen.sh` in an ephemeral session scratchpad, and the wrappers
it tests are in a non-versioned directory. Neither is under version control, so nothing
re-runs these cases automatically and nothing preserves the harness. If these wrappers
matter, both they and the suite need a home in a real repository — until then the
7-case suite is a one-off measurement, not a standing gate.

## Related Issues

**This defect family has bitten this project repeatedly** — the capture-host learning
below records another instance of it. The two closest relatives, though, were never
written up here at all; they live only in issues and in `CLAUDE.md`:

- **[#82](https://github.com/fol2/glassvow/issues/82)** (closed 2026-08-09) — "The
  per-file parse gate cannot fail: `--check-only` exits 0 on every parse error". The
  strongest relative. Four seeded error classes all measured `raw exit=0`, so a clean
  file and a broken file were indistinguishable to the gate. Same two-part fix shape:
  stop trusting the one narrow signal, grade the real evidence instead. Surfaced only
  by accident.
- **[#128](https://github.com/fol2/glassvow/issues/128)** (closed 2026-08-09) — asset
  import emits font ERRORs and exits 0. Its own body names the pattern: "the same
  defect family as #82".
- `tools/check_scripts.sh` — the fix for #82, and the closest code precedent. Its
  header states the conclusion this wrapper independently rediscovered: grade both
  signals independently, stderr for errors and process status for invocation failures.
  It took three commits to settle, which is evidence that this defect class is rarely
  fixed in one pass.

Related learnings:

- [Annotate citations where structure and prose agree](../workflow-issues/annotate-citations-where-structure-and-prose-agree.md)
  — closest on the primary root cause: a regex that *is* the coverage boundary and
  "degrades quietly rather than failing". That doc removed an over-permissive
  fallback; this one removes an over-restrictive whitelist, for the mirror reason.
- [Capture through a long-lived host, not a process per screenshot](../tooling-decisions/long-lived-capture-host-not-process-per-shot.md)
  — closest on the artifact check. Records `Script.reload()` as "a silent no-op that
  still returns OK", caught only by a deliberately planted, visually checkable
  artefact. Same fix shape: grade the artefact, not the status code.
- [Build save fixtures via domain APIs, not JSON](../workflow-issues/build-save-fixtures-via-domain-apis-not-json.md)
  — the generic form of the artifact check: round-trip through the production path and
  assert on the property downstream behaviour keys on.
- [Put the gate where the change is deterministic](../conventions/put-the-gate-where-the-change-is-deterministic.md)
  — the project's gate-design convention. It covers gates whose *variance* stops them
  detecting an effect; this learning adds the case where the gate's *trigger condition*
  cannot match the real failure signal.
- [Typed array from ternary branch throws at runtime](../runtime-errors/typed-array-from-ternary-branch-throws-at-runtime.md)
  — the existing home for "a green gate proves less than it claims".
- [Canary pins the rule, not the bug's shape](../test-failures/canary-pins-the-rule-not-the-bugs-shape.md)
  — method precedent for the 7-case suite: pin the invariant rule, not the two error
  strings that happened to be observed.
