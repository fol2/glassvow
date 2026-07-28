---
title: Cite the symbol, not the line
date: 2026-07-28
category: conventions
module: docs
problem_type: convention
component: documentation
severity: high
applies_when:
  - "Writing a new citation from prose into code"
  - "Repairing a citation that the anchor checker reports as drifted"
  - "Deciding whether a line number in a document is a pointer or a piece of evidence"
  - "Weighing whether a verification tool is worth the maintenance it demands"
tags:
  - citations
  - file-line-anchors
  - drift
  - check-anchors
  - conventions
  - parallel-lanes
---

# Cite the symbol, not the line

## Context

Citations from prose into code carry two halves, and they have lifetimes an order
of magnitude apart. Measured on this repo across a single day of ordinary work,
over the four most-edited files:

| file | symbols renamed or removed | line numbers that moved |
|---|---|---|
| `presentation/combat/enemy_view.gd` | **0%** | 40% |
| `presentation/combat/combat_screen.gd` | **0%** | 10% |
| `presentation/combat/hud_bar.gd` | **0%** | 0% |
| `presentation/lab/enemy_lab.gd` | **0%** | **99%** |

Zero of roughly nine hundred symbols were renamed or removed. Up to
ninety-nine per cent of their line numbers moved.

The line number is not a fact about the code; it is a cache of one, and it goes
stale on somebody else's commit. `tools/check_anchors.py`'s own `--fix` is the
proof: it regenerates the line **from** the symbol. The symbol is the durable
half, and the tooling has been spending its complexity keeping the perishable
half warm.

## Guidance

**Write citations as file plus symbol, with no line number.**

```markdown
`presentation/combat/enemy_view.gd` (`set_ward_shell`)
```

Both halves backticked. The checker recognises this form
(`tools/check_anchors.py` (`SYMBOL_ANCHOR`)) and asks it one question — does that
file declare that symbol? — with no line arithmetic, no span containment, and
nothing to repair later. The inner backticks are not decoration: they are what
stops prose like ``​`enemy_view.gd` (the actor)`` being read as a citation.

**A line number earns its place only when the line itself is the subject.** Two
cases, and they are narrow:

- The passage is *about* a specific line — quoting a wrong number as evidence,
  or contrasting two numbers. Then the number is data, not a pointer, and
  removing it would remove the argument.
- The thing cited has no symbol at all: a `##` commentary block, a region
  spanning several declarations, a stretch of shader body. Prefer naming the
  nearest symbol and describing the part
  (``​`tools/check_anchors.py`'s module docstring``) over inventing a range.

**Repair a drifted citation by converting it, not by re-numbering it.** A
re-numbered anchor is correct until the next commit touching that file; a
converted one is correct until the symbol is renamed, which is a change you want
to hear about and which `grep` finds in a second.

**Do not convert another lane's citations.** The existing `file:line (symbol)`
form still works and is still checked — the new form is additive, and nothing
that passes today stops passing. Convert what you own, when you touch it.

## Why This Matters

The maintenance is not free and it is not small. On 2026-07-27 the checker
needed six separate fixes in one day, and **five of the silent-failure classes
found were about parsing line-number spellings** — an ambiguous bare basename, a
path-less `:NNN`, a markdown-link form whose annotation landed after the link's
closing paren, an absolute-path skip test that swallowed an entire worktree, and
a language with no declaration form. Every one of them let a clean run certify
work nobody had looked at. Remove line numbers and most of that surface is not
fixed — it stops existing.

The counts say the same thing. Of the findings this repo currently reports,
roughly a third exist only because line numbers exist: path-less citations,
anchors that escaped a symbol's span, and drift itself. The findings that
actually mean *the document is wrong about the code* — a symbol that is not in
the file it is cited from — are a handful, and they survive the change untouched.

The cost that is easiest to miss is the conflict load. Every re-anchoring is a
document edit. Several lanes share this tree, each running `--fix` against its
own checkout, each producing diffs on the same citations — and this branch spent
a working day resolving exactly that. A citation that never needs re-numbering
never generates that diff.

## When to Apply

- Every new citation from prose into code.
- Every citation you are already editing for another reason.
- When the checker reports drift on a citation you own: convert rather than
  re-number.

The honest limits:

- **You lose deep links.** A `#L123` fragment in a markdown link cannot be built
  from a symbol name. That is a real loss and a small one.
- **You lose sub-symbol precision.** "The third branch of this function" has no
  short spelling. Name the symbol and describe the part in prose.
- **Renames still break citations**, and nothing here changes that. They break
  loudly — the checker reports the symbol as missing — which is the failure mode
  worth having, unlike a line number that quietly comes to rest on unrelated code.
- **This does not retire the line-number form.** Both are checked; the old one is
  still the majority of the corpus and is not being swept.

## Examples

Before, and stale within hours of being written:

```markdown
The ward is a cut gem held in front of the mob (`enemy_view.gd:2313-2350`
(`set_ward_shell`)).
```

After, and stale only if somebody renames the function:

```markdown
The ward is a cut gem held in front of the mob
(`presentation/combat/enemy_view.gd` (`set_ward_shell`)).
```

A line number that should stay, because the passage is about the number:

```markdown
`enemy_view.gd:2148` is genuinely inside `_process`; the sentence citing it is
about `set_ward_shell`, 165 lines away.
```

The checker treats the two differently on purpose. The first two are citations
and are verified. The third carries no symbol annotation, so under `--strict` it
is reported as uncheckable — which is correct: it is evidence, and there is
nothing there to check.

## Related

- [Annotate a citation only where structure and prose agree](../workflow-issues/annotate-citations-where-structure-and-prose-agree.md)
  — why the symbol annotation had to exist before this convention could. It is
  also the doc that measured the annotation being the load-bearing half.
- [Check what the shared tree already landed before extending a shared document](../workflow-issues/check-the-shared-tree-before-extending-a-shared-doc.md)
  — the conflict load that re-anchoring generates across lanes.
- `tools/check_anchors.py` (`SYMBOL_ANCHOR`) — the form itself. Its module
  docstring is the short version of why the two citation halves are not equal.
