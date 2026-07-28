---
title: Annotate a citation only where structure and prose agree, never from the tree alone
date: 2026-07-27
category: workflow-issues
module: docs/anchors
problem_type: workflow_issue
component: documentation
severity: high
applies_when:
  - "Retro-fitting symbol annotations onto a backlog of existing file:line citations in bulk"
  - "A checker reports items as uncheckable and the obvious fix is to annotate every one of them"
  - "The evidence for a check is derived from the same tree the check is meant to verify"
  - "Writing a new file:line citation in docs/ while several lanes move the same tree"
  - "Deciding whether a mechanical pass may close a gate whose real question the tool cannot see"
symptoms:
  - "--strict reported 226 anchors carrying no (symbol); the audit worked a set of 225"
  - "Roughly a third of those anchors had already drifted, and a mechanical annotation pass would have stamped each broken one as verified"
  - "enemy_view.gd:2148 really is inside _process, but the sentence citing it is about set_ward_shell, 165 lines away"
  - "enemy_view.gd:496-526 opens on NAME_BOSS while its paragraph means IDLE_PROFILES, twenty-one lines in"
  - "The checker fell back to any line mentioning the name, so a call site satisfied an (in set_profile) annotation in a file declaring no such symbol"
related_components:
  - "tooling"
  - "development_workflow"
tags:
  - "docs-citations"
  - "file-line-anchors"
  - "drift-detection"
  - "check-anchors"
  - "verification"
  - "annotation"
  - "false-confidence"
  - "parallel-sessions"
root_cause: inadequate_documentation
resolution_type: documentation_update
---
# A structural annotation cannot contradict the prose, so annotating in bulk makes docs worse

## Context

`tools/check_anchors.py` exists because six lanes move `presentation/`
concurrently and a line number written today is routinely wrong by tomorrow.
The script says so in its own opening: a refresh on 2026-07-26 found 14 of 15
anchors in one cluster had drifted within hours of being written, and every one
had been correct at its own shipping commit (`tools/check_anchors.py:4-8`).
Discipline does not fix that. The anchors are snapshots of a moving target, so
they are checked mechanically instead. (auto memory [claude]: "Parallel sessions
in glassvow — six lanes share the tree" is the same observation from the other
side; ownership lives in `docs/session-ownership.md`.)

The checker can only verify an anchor that carries a symbol. A bare
`enemy_view.gd:752` is a coordinate and nothing else — the script has nothing to
compare it against, so under `--strict` it is reported `UNANCHORED` and no more
(`tools/check_anchors.py:235-239`). Two annotated forms are checkable. A bare
`(symbol)` asserts the cited line *is* the declaration, which has one right
answer and is repairable with `--fix`. An `(in symbol)` asserts only that the
cited line falls inside that symbol's span, which is the form that catches the
dangerous case (`tools/check_anchors.py:18-28`).

Before this work, `--strict` reported **226** anchors carrying no symbol. I ran
the pre-change checker from a throwaway worktree at `ca841a0~1` to confirm the
number rather than take it from a commit message; it prints
`226 anchor(s) carry no symbol and cannot be drift-checked`. On the current
branch it prints **88**. (The audit's own working set was 225 — per the
`cef9c99` commit message — one fewer than the checker's finding count.)

Adding the missing annotations reads like pure coverage improvement: 226
unverifiable citations become 226 verifiable ones, nobody's prose changes, and
the tool gets stronger. **It is not.** Forty of those anchors had already drifted
— counted as the multiset difference of whole `file:start-end` tokens between
`ebe2ad2` and this branch, 40 out of 226 (38 if you compare start lines only:
two anchors moved just their range end), not the "roughly a third" this session estimated
in passing — and the annotation is exactly the wrong instrument to discover that, because a structural annotation is *derived from the tree*. Whatever
declaration encloses line N, that is what gets written, and the resulting
annotation is true of the tree no matter how far the citation moved. It cannot
contradict the prose, because it never reads the prose. A mechanical pass would
therefore have stamped a green `check_anchors.py` on citations that point at
plausible unrelated code — and both a human reader and the next audit would then
trust them. The docs would end up **more** misleading once annotated than they
were bare.

The clearest instance is verifiable in the tree today. `docs/actor-animation-checklist.md`
carried `enemy_view.gd:2148+` in a sentence about the ward shell. Line 2148 is
genuinely inside `_process`, which is declared at
`presentation/combat/enemy_view.gd:2108`. The function the sentence is about,
`set_ward_shell`, is declared at `presentation/combat/enemy_view.gd:2313` — 165
lines away. A structural annotation would have written `(in _process)`, the
checker would have passed it, and the citation would have been certified while
pointing at the idle loop. It now reads `enemy_view.gd:2313-2350`
(`set_ward_shell`) at `docs/actor-animation-checklist.md:338`.

This is the same evidence-over-assumption family the project already paid for
once on the rendering side (auto memory [claude]: "Matching constants prove
nothing — the reference's call may draw nothing, the port's may never run; count
pixels, and grep the call sites"). There the trap was inferring behaviour from a
function's existence. Here it is inferring correctness from a checker's silence.

## Guidance

**Gate every proposed annotation on two independent derivations, and only write
where they agree.**

1. **Structural gate.** Scan upwards from the cited line for the enclosing
   top-level declaration, take its name, then **round-trip it through the
   checker's own `find_symbol`** and require the name to resolve back to the same
   line. The round-trip is not ceremony. Without it a prefix or a stray match
   names a symbol the checker will later resolve elsewhere, and the annotation
   fails or — worse — passes against the wrong span. Per this session's notes the
   concrete bite was `_process` matching `func _process_hit`; I could not
   reproduce that pair, because neither `_process_hit` nor `_rng_seed` exists in
   this tree at either commit. They are illustrative names in the script's own
   comment (`tools/check_anchors.py:165-167`), not live symbols. The hazard the
   round-trip closes is real regardless: use the resolver that will grade you.

2. **Prose gate.** Collect the backticked identifiers from the anchor's whole
   **paragraph**, look each one up in the *cited file*, and keep those that
   either are declared inside the cited range or have a span containing it.

Write the annotation only where both gates agree. **Where they name different
symbols, write the prose one.** `enemy_view.gd:496-526` really did open on
`NAME_BOSS` (`presentation/combat/enemy_view.gd:496`), but the sentence was
about `IDLE_PROFILES`, declared twenty-one lines further down at
`presentation/combat/enemy_view.gd:517`. The annotation a reader trusts is the
one the sentence meant, so the citation was re-anchored rather than annotated:
`docs/actor-animation-checklist.md:85` now reads `enemy_view.gd:517-537`
(`IDLE_PROFILES`).

**Scope the prose window to the paragraph, not the line.** A one-line window
reads legitimate citations as drift, because prose habitually names the symbol at
the top of a paragraph and the line number arrives two lines later. Per this
session's tally the first run at it reported 54 drifted, which fell to a verified
30 once the window widened to the paragraph and the containment test was
corrected. Half the alarm was the instrument.

**Harden the applier against text shapes it cannot edit, and make it skip rather
than guess.** A first mechanical applier was run and reverted; per this session's
account it corrupted 4 of 55 edits. Three of the four failures are shapes you can
still find in the tree and should special-case by hand:

- an anchor inside a markdown **link label**, where naive insertion lands
  outside the brackets and breaks the link. The fix is to move the annotation
  *inside* the label, so the anchor and its symbol finally meet and the link
  still resolves. `docs/solutions/design-patterns/dom-node-per-layer-in-godot.md:30`
  now reads:

  ```markdown
  At [hud_bar.gd:104 (`FAN_FACES`)](../../../presentation/combat/hud_bar.gd) the fan is capped at 16
  ```

  and `FAN_FACES` is indeed declared at `presentation/combat/hud_bar.gd:104`.
- a code span with a trailing `+` — `` `vfx_layer.gd:591+` `` — where the
  annotation lands inside the span. The symbol's span states "and following"
  more precisely than the `+` did, so the `+` goes:
  `docs/actor-animation-checklist.md:436` now reads `vfx_layer.gd:591`
  (`archetype_hit`), matching `presentation/combat/vfx_layer.gd:591`.
- an **en-dash range**, `73–79`. The regex takes a single ASCII hyphen between
  the two numbers (`tools/check_anchors.py:57`), so it does not fail loudly — it
  matches the start and *silently discards the end*. That one was rewritten to
  ASCII and annotated: `docs/assembly-integration-plan.md:204` cites
  `rewards.gd:73-79` (in `gen_combat_rewards`), declared at
  `domain/rules/rewards.gd:60`. A second en-dash citation survives untouched at
  `docs/assembly-integration-plan.md:149`, and `--strict` reports it as
  `content_db.gd:45` — it *is* among the 88, but the `–62` half of it has never
  been checked by anything.

The fourth failure was not typographic: the applier wrote the **structural**
symbol where the prose meant a different one. That is the trap this whole
document is about, and it is why the two gates exist.

The hardened applier skipped those shapes rather than mangling them: per this
session's account it skipped 10 and wrote 39 cleanly. All ten skips were later
fixed by hand, **and none of them was a wrong citation** — every one was
typographic. Four already carried a correct annotation that had *wrapped onto
the following line*, where the regex never looks: the checker reads documents
line by line (`tools/check_anchors.py:217`), so a symbol in the next line's text
does not exist as far as the anchor is concerned.

**Fix the checker before you trust its verdicts.** Four changes had to land in
`tools/check_anchors.py` before the annotations meant anything. (The commits
named throughout — `ca841a0`, `cef9c99`, `1149731`, `4ed334a` — are local to
`jamesto/youthful-kirch-54418b` and unpushed at the time of writing; a rebase or
squash merge will rewrite these SHAs, and this repo has no PR to cite instead.)

- **`symbol_head()`** (`tools/check_anchors.py:124-144`) — a declaration's
  contiguous `##` doc block now counts as part of its span, and the `(in symbol)`
  containment test starts from it (`tools/check_anchors.py:245-252`). This repo
  carries the ported CSS spec in the commentary *above* a symbol, so citing that
  commentary is the point rather than an accident. Without this, per `ca841a0`,
  roughly seventy anchors were structurally unannotatable.
- **Word-boundary matching in `find_symbol`** (`tools/check_anchors.py:163-172`).
  The previous test was a bare `stripped.startswith(needle)`, so a prefix could
  pass for a name.
- **An explicit shader-declaration form** (`tools/check_anchors.py:185-190`),
  because a GLSL function leads with its return type — `void fragment()` — and no
  prefix in `DECLARATIONS` can reach it. The return types are spelled out rather
  than left as `\w+`, so a GDScript `return foo(...)` cannot pass for a
  declaration of `foo`.
- **The any-mention fallback was removed** (`tools/check_anchors.py:192-199`).
  It answered for symbols the file never declares, and an anchor whose symbol
  cannot be located is now reported `missing`, which is the honest answer.
  Removing it surfaced that its one legitimate use was covering a gap in the
  declaration forms rather than a need for guessing, so `static var` and
  `@export var` were added to `DECLARATIONS`
  (`tools/check_anchors.py:68-69`); `static var oversample` is real, at
  `presentation/combat/enemy_view.gd:308` and `presentation/combat/card_view.gd:173`.

## Why This Matters

The asymmetry is the whole point and it is worth stating plainly: **a check
derived from the tree can only ever fail on the tree.** `find_symbol` reads
source; it has never read a sentence. So an annotation minted from the enclosing
declaration is, by construction, unfalsifiable by the prose it is meant to
certify. The tool's green light then means "this citation points inside *some*
function" — which is nearly always true and almost never what the reader wants
to know. Coverage went up; trustworthiness went down. That is the failure mode
worth remembering, because every mechanical documentation pass has the same
shape available to it.

The sharpest evidence is that this audit committed the error against itself
before catching it. Per the `1149731` and `4ed334a` commit messages, two
annotations *written by this pass* were green only because of the any-mention
fallback: `(tscn)`, verified against the `.tscn` inside a path literal — `tscn`
being a file extension the sentence mentioned, not a symbol at all — and
`(in set_profile)`, verified against `view.set_profile(...)`, a method on
another class in a file declaring no such symbol.

The `(tscn)` case is verifiable end to end. `4ed334a` rewrites
`docs/solutions/tooling-decisions/long-lived-capture-host-not-process-per-shot.md:201`
from a citation into `tools/live.gd` line 24 annotated `` (`tscn`) `` to the
same citation annotated `` (`GAME_SCENE_PATH`) ``, and `tools/live.gd:24`
(`GAME_SCENE_PATH`) really is
`const GAME_SCENE_PATH: String = "res://application/main.tscn"` — the string
whose extension the old resolver had been matching.

The `(in set_profile)` case I could **not** confirm, and the honest thing is to
say so rather than repeat it. There is no `(in set_profile)` annotation in
`docs/` or `CONCEPTS.md` at any of the four commits; the only `set_profile`
annotation on the branch is `` `enemy_view.gd:2449` (`set_profile`) `` at
`docs/solutions/tooling-decisions/drive-the-lab-the-way-the-game-drives-it.md:172`,
and that one is correct — `func set_profile` is at
`presentation/combat/enemy_view.gd:2449`. The likeliest reading is that the
false annotation existed transiently in the working tree during the audit and
was corrected inside `cef9c99` before it was ever committed, which would leave
no before-and-after in git. Treat it as attested by the commit messages, not by
the tree.

Either way the point survives on the verified half: an auditor with the right
method, mid-audit, still shipped a certified-false annotation. The rule earns
its place on that alone.

There is a measurable, re-derivable version of the same claim. Of the 118
distinct `(file, symbol)` pairs currently annotated across the checked documents
(`docs/`, `CONCEPTS.md`, `AGENTS.md`), exactly one resolves differently under the
old resolver than the new one:
`card_surface.gdshader` / `fragment`. The old fallback put `fragment` at line 10
— a comment reading "…so every fragment has a" — while the declaration
`void fragment() {` is at `presentation/combat/card_surface.gdshader:260`. That
annotation is live at `docs/solutions/conventions/per-recipe-shader-knobs.md:117`,
which cites `card_surface.gdshader:360` (in `fragment`). Under the old resolver
the anchor would have been graded against a comment; under the new one it is
graded against the function. One line of prose, two entirely different meanings
of "verified".

**A correction to this session's own record, arrived at by doing what this
document asks.** The `ca841a0` commit message states that prefix matching was
what let one live citation stay wrong: `docs/glass-crack-rendering.md` put
`_rng` at `:200`, and it is at `:460`. The citation was indeed wrong —
`presentation/combat/enemy_view.gd:200` is `const WARD_OPACITY` and
`var _rng` is at `presentation/combat/enemy_view.gd:460`. But the attribution
does not hold. Running the *pre-change* `find_symbol` against the *pre-change*
`enemy_view.gd` returns 460 for `_rng`, and running the pre-change checker over
the pre-change docs reports that line as
`docs/glass-crack-rendering.md:633 UNANCHORED enemy_view.gd:200 — no (symbol)`.
What hid that drift was not the prefix test at all: the `` (`_rng`) ``
annotation had **wrapped onto the following line**, so the regex never saw an
annotated anchor. The prefix fix and the wrapped-annotation sweep both landed,
the citation is right now, and the outcome is unaffected — but the causal story
in the commit message is wrong, and it was wrong for exactly the reason this
document exists: it was inferred from a plausible mechanism rather than measured.

## When to Apply

Apply this whenever a documentation-hygiene task is framed as "add the missing
annotations", "raise the coverage", or "make the checker strict". The framing
itself is the warning sign: it presumes the uncovered items are merely
unverified, when the reason they are uncovered is precisely that nothing has
been checking them, which is also the condition under which they rot.
Generalised: **before bulk-adding a machine-derived assertion to human prose,
establish that the assertion can disagree with the prose. If it cannot, adding
it launders staleness into confidence.**

Apply it specifically in this repo when touching `file:line` citations, because
the drift rate here is not incidental. Six lanes share the tree and anchors go
stale within hours.

The honest limits:

- **Leave anchors that span more than one declaration unannotated.** This is a
  decision, not a gap. `combat_screen.gd:14-27` covers four consts — `GROUND_Y`
  (`presentation/combat/combat_screen.gd:21`), `LEDGE_LIP` (`:23`), `STAGE`
  (`:26`) and `STAGE_ART` (`:27`) — and has no single symbol to name. It is
  cited twice, at `docs/actor-animation-checklist.md:547` and `:696`. Forcing an
  annotation would mean picking one const arbitrarily and certifying a range that
  is mostly about the other three.
- **`--strict` is not a target to drive to zero.** 88 anchors remain uncheckable
  on this branch. Re-running the two gates over them (see Examples) shows why:
  60 have a structural answer but no backticked symbol in their paragraph to
  corroborate it, 25 have neither, and 3 span more than one declaration in the
  `combat_screen.gd:14-27` shape. Every one of those is a case where writing an
  annotation would be guessing.
- **A green `check_anchors.py` never means the prose is right.** It means the
  cited line is where the *named symbol* is or lives. The name is supplied by the
  document, so the check is only as good as the pass that wrote it — which is why
  the `(tscn)` annotation above was green.
- **The regex is the real coverage boundary, and it degrades quietly rather
  than failing.** None of the three awkward shapes is invisible, which is what I
  first assumed and had to correct: a wrapped annotation and an anchor inside a
  link label both land in the unannotated count, and an en-dash range matches on
  its start line with the end silently dropped. That is worse than invisible in
  one respect — each looks like an ordinary counted item while a different part
  of the claim goes unchecked. Grep for the shapes; the tool's own count will not
  distinguish them.
- **`.py` anchors cannot be annotated at all**, which is a gap rather than a
  decision. `py` is in `CODE_SUFFIXES` (`tools/check_anchors.py:48`), so a
  citation into a Python file is recognised as an anchor and counted — but
  `DECLARATIONS` (`tools/check_anchors.py:63-79`) carries GDScript and shader
  forms only. There is no `def` form, and a module-level constant matches
  nothing either, so `find_symbol` returns `None` for every Python symbol and
  any annotation on a `.py` anchor would be reported `missing`. Thirteen
  distinct `.py` anchors sit in the corpus, including every citation this
  document makes into the checker itself. The same shape as the shader-function
  gap fixed in `ca841a0`, and it wants the same remedy.
- **Do not `--fix` an `(in symbol)` finding.** The script refuses to, and says
  why: nothing in the document states how far an interior line should have moved,
  and guessing would launder a wrong number into a confident one
  (`tools/check_anchors.py:25-28`).

## Examples

### The two gates, as a runnable sketch

This is a reconstruction of the shape, not a committed tool — the audit's own
scripts were scratch and are not in the tree. It reuses `check_anchors.py`
deliberately, so the structural gate is answered by the very resolver that will
later grade the annotation. It reports; it never writes.

```python
import importlib.util, re
spec = importlib.util.spec_from_file_location("ca", "tools/check_anchors.py")
ca = importlib.util.module_from_spec(spec); spec.loader.exec_module(ca)

TOP_DECL = re.compile(
    r"^(?:@export\s+)?(?:static\s+)?"
    r"(?:func|const|var|class|class_name|signal|enum)\s+(?P<name>[A-Za-z_]\w*)")
BACKTICKED = re.compile(r"`([A-Za-z_]\w*)`")

def structural(lines, start):
    """Enclosing top-level declaration, round-tripped through find_symbol."""
    for i in range(min(start, len(lines)), 0, -1):
        line = lines[i - 1]
        if line[:1].isspace() or not line.strip():
            continue
        m = TOP_DECL.match(line)
        if not m:
            continue
        name = m.group("name")
        # Round-trip. Without it, a prefix or a stray match names a symbol
        # find_symbol will later resolve to a different line entirely.
        return (name, i) if ca.find_symbol(lines, name) == i else None
    return None

def paragraph_of(doc_lines, doc_line):
    """Blank-line-delimited block. A one-line window reads legitimate
    citations as drift: the symbol is named at the top of the paragraph
    and the line number arrives two lines later."""
    lo = hi = doc_line - 1
    while lo > 0 and doc_lines[lo - 1].strip():
        lo -= 1
    while hi + 1 < len(doc_lines) and doc_lines[hi + 1].strip():
        hi += 1
    return doc_lines[lo:hi + 1]

def prose(lines, para, start, end):
    """Backticked identifiers that actually live where the anchor points."""
    out = []
    for name in dict.fromkeys(BACKTICKED.findall("\n".join(para))):
        decl = ca.find_symbol(lines, name)
        if decl is None:
            continue
        inside = start <= decl <= end
        contains = (ca.symbol_head(lines, decl) <= start
                    and end <= ca.symbol_body(lines, decl))
        if inside or contains:
            out.append((name, decl, "in" if contains and not inside else "decl"))
    return out
```

The decision rule on top of those two is three lines of English. Both gates
name the same symbol → write it. They disagree → write the **prose** one. Only
one answers, or neither → leave the anchor bare and move on.

Run over the 88 anchors that remain unannotated on this branch, the sketch
reports:

```
DISAGREE  docs/actor-animation-checklist.md:362  enemy_view.gd:41-43
          structural=(PREVIEW_WARM) prose=(PREVIEW_PULSE)  -> write prose
DISAGREE  docs/actor-animation-checklist.md:484  enemy_view.gd:3076-3085
          structural=(ANYWHERE) prose=(crack)  -> write prose
DISAGREE  docs/actor-animation-checklist.md:544  combat_screen.gd:1175-1196
          structural=(_slots) prose=(_stand)  -> write prose

agree 0 | disagree 3 | structural-only 60 | prose-only 0 | neither 25
```

`agree 0` is the expected residue and a good sign: everything the two gates
could agree on was already written. The three disagreements are instructive
rather than actionable. `enemy_view.gd:41-43` is a worked case — the structural
scan from `:41` hits `const PREVIEW_WARM` at
`presentation/combat/enemy_view.gd:40` first, because `:41` is the `##` line
belonging to the *next* const; the prose says `PREVIEW_PULSE`, declared at
`:42`. But `PREVIEW_PULSE`'s span is only `:41-42`, and the anchor runs to `:43`
(`PREVIEW_DIP`). Neither annotation verifies, because the range covers two
declarations, so this one belongs in the deliberately-bare set rather than in the annotate
pile. It is not quite the `combat_screen.gd:14-27` shape — that range *encloses*
four whole declarations, while these three *straddle* a boundary — but the
governing fact is the same: no single symbol's span contains the range. That is the gates doing
their job: refusing to produce an answer where there is no single right one.

### The four shapes a mechanical applier gets wrong

Each of these is a real edit that had to be made by hand, and each is checkable
in the tree now.

```markdown
<!-- link label: the annotation must go INSIDE the brackets -->
At [hud_bar.gd:104 (`FAN_FACES`)](../../../presentation/combat/hud_bar.gd) the fan is capped at 16
```

```gdscript
# presentation/combat/hud_bar.gd:104
const FAN_FACES: int = 16      # PILE_FAN_MAX_LAYERS
```

```markdown
<!-- trailing `+`: drop it; the symbol's span says "and following" precisely -->
(`vfx_layer.gd:591` (`archetype_hit`), `combat_screen.gd:2098` (`_hit_enemy`))

<!-- en-dash: the regex takes ASCII `-` only, so the range END is dropped
     silently — this is read as `content_db.gd:45` and the `–62` is never
     checked. Live at docs/assembly-integration-plan.md:149 -->
(`content_db.gd:45–62` has no `themes`)
```

The fourth shape has no distinguishing typography at all — it is a correctly
formed annotation naming the wrong symbol, and only the prose gate catches it.

### A green annotation that was false

```gdscript
# tools/live.gd:24 — what the old fallback matched for the symbol `tscn`
const GAME_SCENE_PATH: String = "res://application/main.tscn"
```

`find_symbol` used to end in "return the first line that mentions this name", so
a citation into `tools/live.gd` line 24, annotated `` (`tscn`) ``, went green
against the extension inside that path literal. `tscn` is not a symbol; it is a word the sentence happened to
contain. The annotation had been written by this audit, and it is now
`(GAME_SCENE_PATH)` at
`docs/solutions/tooling-decisions/long-lived-capture-host-not-process-per-shot.md:201`.
The fallback is gone (`tools/check_anchors.py:192-199`) and an unlocatable
symbol is now reported `missing`.

The unit check recorded in `1149731` is the one to repeat if the fallback is ever
tempting again: `tscn` and `set_profile` must return `None` against a file
holding only a matching string and a matching call, while `GAME_SCENE_PATH`,
`_actor` and `oversample` still resolve to their declaration lines.

### An annotation nobody could see

```markdown
<!-- before: the anchor ends the line, the symbol starts the next one -->
`view.set_profile(_foe_kind(e.idx))` for every foe, and `combat_screen.gd:1049`
(in `start_encounter`) calls `_hero.set_profile("rogue")` for the player.

<!-- after: they meet, and the checker can finally grade it -->
`view.set_profile(_foe_kind(e.idx))` for every foe, and
`combat_screen.gd:1049` (in `start_encounter`) calls `_hero.set_profile("rogue")` for the player.
```

Four of the ten hand-fixed skips were this shape, and this one is
`docs/solutions/tooling-decisions/drive-the-lab-the-way-the-game-drives-it.md:50-51`.
The annotation was correct all along — `start_encounter` is declared at
`presentation/combat/combat_screen.gd:1022` and `:1049` is
`_hero.set_profile("rogue")`, comfortably inside it — but because the checker
walks documents line by line (`tools/check_anchors.py:217`), the symbol on the
next line did not exist as far as the anchor was concerned. It was counted among
the 226 uncheckable and would have been "fixed" by a bulk pass that had nothing
to fix. Reflowing a paragraph is enough to silently un-verify a citation here,
which is worth knowing before anyone runs a prose formatter over `docs/`.

### Outcome

Measured against the tree rather than taken from the running commentary: the
repo holds **280** anchors the regex can see, before and after — none added,
none deleted. **40** had their line number repaired. **138** became checkable,
which is the `--strict` count falling from **226** at `ca841a0~1` to **88** at
`4ed334a`. The default run prints `anchors OK`.

That **88** is the figure for the branch as this document found it, and this
document does not leave it there: its own citations add several dozen more the
moment the file lands. Most of those are deliberate — an illustration
of a *wrong* citation must stay bare, or annotating it would assert the very
claim the passage is disputing — and the rest are the `.py` case in the limits
below. This paragraph deliberately does not quote the resulting total: the first
draft did, and the figure was already stale two edits later, because adding two
citations to the limits section moved it. Quoting a live tool count inside the
document that changes that count is the same error in miniature — true when
written, false one commit later.

Those are not the numbers this session quoted to itself while working ("30
repaired, 57 annotated"); both halves were undercounts, and the corrected
figures come from re-deriving them at the end rather than accumulating them as
they went. Worth recording, because a running tally is exactly the kind of claim
that never gets re-checked. The
work is four commits on `jamesto/youthful-kirch-54418b`, **local and unpushed**:
`ca841a0` (checker: doc-block spans, word boundaries, shader declarations),
`cef9c99` (the 30 repairs and 57 annotations), `1149731` (fallback removed,
`static var` / `@export var` added), `4ed334a` (the ten hand-fixed skips, and the
false annotations discussed under *Why This Matters*).

## Related

- `tools/check_anchors.py` — the tool itself. Its module docstring is the short
  version of why the `(in symbol)` form exists and why it is never auto-fixed.
  Read it before changing the regex; the four shapes above are all regex
  boundaries.
- [`docs/session-ownership.md`](../../session-ownership.md) — six lanes share
  this tree, which is the reason anchors drift within hours of being written
  rather than over months. The drift rate is what makes mechanical checking
  worth having, and what makes a bulk annotation pass dangerous.
- [Audit a port by enumerating the reference's CSS](audit-port-by-enumerating-reference-css.md)
  — sibling method with the same core rule: a verdict with no quoted `file:line`
  evidence is rejected even when the auditor is sure. That doc's citations were
  among the ones repaired here.
- [`docs/wrong-reference-audit.md`](../../wrong-reference-audit.md) — the
  rendering-side version of the same error: a function existing in source is not
  evidence it renders (`ring` / `slashArc`). Here, a checker passing is not
  evidence a citation is right. (auto memory [claude]: "Matching constants prove
  nothing — count pixels, and grep the call sites.")
- [Drive the lab the way the game drives it](../tooling-decisions/drive-the-lab-the-way-the-game-drives-it.md)
  — carries the wrapped `combat_screen.gd:1049` annotation repaired here, and is
  a third instance of the family: an instrument that answers confidently without
  driving the thing you meant to measure.
- [Long-lived capture host, not process per shot](../tooling-decisions/long-lived-capture-host-not-process-per-shot.md)
  — home of the `(tscn)` annotation that went green against a path literal, now
  `(GAME_SCENE_PATH)` at `tools/live.gd:24`.
