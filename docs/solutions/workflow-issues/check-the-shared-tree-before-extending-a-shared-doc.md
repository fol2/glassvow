---
title: Check what the shared tree already landed before extending a shared document
date: 2026-07-27
last_refreshed: 2026-07-29
category: workflow-issues
module: docs
problem_type: workflow_issue
component: documentation
severity: medium
applies_when:
  - "About to add a paragraph to CONCEPTS.md, AGENTS.md or a docs/solutions entry from a branch that is not at the tip of main"
  - "A long-running session is about to write a finding that another lane could plausibly have hit too"
  - "Reporting how badly a branch conflicts, before anyone has run a merge"
  - "Deciding whether a branch should merge now or keep accumulating documentation edits"
tags:
  - parallel-lanes
  - merge-conflicts
  - shared-documents
  - duplicate-discovery
  - branch-hygiene
  - concepts-md
---

# Check what the shared tree already landed before extending a shared document

## Context

This repo is worked by several lanes at once, and `CONCEPTS.md`, `AGENTS.md`
and `docs/` are the files every lane wants to append to. `docs/session-ownership.md:69-70`
already names the hazard in one line: those files are "append-only in practice.
Two lanes appending in the same minute will conflict."

What that line does not say, and what this session ran into twice, is that the
cost is not only the conflict. A lane working from a branch cannot see what the
shared tree has learned since it forked, so it can spend real effort
rediscovering a finding that landed hours ago — and then land its own worse
version of that finding directly on top of the better one.

On 2026-07-27 a documentation branch sat at `ebe2ad2` from roughly 09:00. At
13:07 a commit on `main` recorded that `md` is absent from the anchor checker's
`CODE_SUFFIXES`, so "a citation from one document into another is not recognised
as an anchor at all. The citations documents make about each other are the least
checked in the corpus." At 13:14 this session's own session-history search
surfaced the same gap, independently, and it was verified from scratch against
`tools/check_anchors.py:48`. Seven minutes apart, two lanes, one finding, two
lots of work.

The second half was the near-miss. The branch was about to extend the
`Anchor` glossary entry with two facts — that only annotated anchors are
checked, and that doc→doc citations are invisible. The `main` commit had already
added both, in cleaner prose, and had also scrubbed the implementation specifics
out of the same entry. Adding the branch's version would have duplicated the
content *and* deepened a conflict that already existed in that exact paragraph.

(auto memory [claude]: "Parallel sessions in glassvow — six lanes share the tree;
ownership lives in `docs/session-ownership.md`, never git reset, gate per file."
The ownership file gates *who writes what*. This is the other half — what to read
before you write it.)

## Guidance

**Before appending to a shared document from a branch, fetch and read what the
shared tree already says there.** Not the file as your branch has it — the file
as `main` has it now. The two diverge silently, and the divergence is largest in
exactly the files every lane edits.

```bash
git fetch --quiet
UPSTREAM=origin/main
MB=$(git merge-base HEAD "$UPSTREAM")
git log --oneline "$MB".."$UPSTREAM" -- CONCEPTS.md # has this entry moved?
git show "$UPSTREAM":CONCEPTS.md | sed -n '/^### Anchor/,/^### /p'
```

**When the shared tree already carries your finding, do not land your version.**
Duplicated prose in a glossary is worse than absent prose, because the reader now
has to decide which of two entries is authoritative. If your version genuinely
adds something the landed one lacks, the cheap move is to record that one
sentence as a follow-up for whoever resolves the merge, not to write it into a
paragraph that is already conflicted.

**Measure conflicts, do not infer them from the changed-file set.** "Both lanes
touched this file" is the cheap signal and it over-reports badly. Two lanes
editing different regions of the same file merge cleanly. Get the real answer
per file:

```bash
UPSTREAM=origin/main
MB=$(git merge-base HEAD "$UPSTREAM")
for f in $(comm -12 <(git diff --name-only "$MB" "$UPSTREAM" | sort) \
                    <(git diff --name-only "$MB" HEAD | sort)); do
  git show "$MB:$f" > /tmp/base; git show "HEAD:$f" > /tmp/ours; git show "$UPSTREAM:$f" > /tmp/theirs
  if git merge-file -p --quiet /tmp/ours /tmp/base /tmp/theirs >/dev/null 2>&1
  then echo "CLEAN     $f"
  else echo "CONFLICT  $f  ($(git merge-file -p /tmp/ours /tmp/base /tmp/theirs 2>/dev/null | grep -c '^<<<<<<<') hunk)"
  fi
done
```

**Treat the conflict count as a clock, not a constant.** It grows on its own
while the branch waits, and nothing tells you. Re-measure before reporting it.

## Why This Matters

Duplicated discovery is the visible cost and the smaller one. Seven minutes of
overlap is cheap; the same collision on a multi-hour investigation is not, and
nothing in the branch's own view of the world would have revealed it. The search
that found it here was a session-history sweep run for an unrelated reason.

The larger cost is that a branch's picture of its own merge risk is stale by
construction, and stale in the direction that flatters it. Between this branch's
last commit at 13:05 and a check at 22:23 — no branch activity at all in between
— `main` gained five commits and the set of files touched by both lanes went from
four to six. The branch did nothing and got worse.

Reporting that number carelessly is its own small failure. "Six files changed in
both lanes" was true and sounded like six conflicts; the merge says three files
conflict, across four hunks, and the other three auto-merge cleanly. The cheap
signal over-reported by half. That matters because the number drives a decision —
whether to merge now or keep going — and a doubled estimate argues for the wrong
one.

## When to Apply

- Before adding an entry or paragraph to `CONCEPTS.md`, `AGENTS.md`, or any
  `docs/solutions/` file, when your branch is not at the tip of `main`.
- Before quoting how conflicted a branch is. Measure it; do not read it off the
  changed-file list.
- Whenever a long session surfaces a finding about shared tooling — check
  whether it already landed before writing it up as new.
- Generalised: **the longer a branch holds documentation edits, the more it
  should re-read the shared tree, and the less its own view of the tree is
  worth.** A new file is safe at any age; an edit to a shared file is not.

The honest limits:

- **This does not remove the conflict, it removes the duplicate.** The
  `CONCEPTS.md` conflict this session found still has to be resolved by hand;
  what the check bought was not writing a third version into it.
- **A clean `merge-file` is not a clean merge.** It says the text reconciles,
  not that the result is coherent — two lanes can edit different paragraphs of
  one entry and produce a contradiction that no tool flags.
- **`git fetch` is required for any of this to mean anything.** The commands
  above deliberately compare against the fetched remote-tracking ref
  `origin/main`; comparing against a stale local `main` would report reassuring
  nonsense.

## Examples

The near-miss, in full. What `main` had already landed on the `Anchor` entry:

> A green run is also quieter than it looks, because two whole classes of Anchor
> go unexamined. A citation carrying no symbol annotation is not validated at all
> by default, so it may point anywhere and still pass. And an Anchor into another
> prose document is invisible to the check entirely.

What this branch was about to add, from its own independent investigation: that
only annotated anchors are checked, and that doc→doc citations are invisible.
The same two facts, in weaker prose, into a paragraph the other lane had just
rewritten — which would have been both a duplicate and a worse conflict.

The measurement, on this branch at 22:23:

```
6 files changed in both lanes
  CONFLICT  CONCEPTS.md                                       (1 hunk)
  CONFLICT  dom-node-per-layer-in-godot.md                    (1 hunk)
  CONFLICT  long-lived-capture-host-not-process-per-shot.md   (2 hunks)
  CLEAN     fracture-model.md
  CLEAN     glass-crack-rendering.md
  CLEAN     audit-port-by-enumerating-reference-css.md
```

Three of six. The two files that joined the changed-in-both set latest — at
18:10, five hours after this branch's last commit — are both in the clean
column: `main` edited them near the top of the file while this branch had edited
them near the bottom. Arrival in the set is not arrival in the conflict.

## Related

- [`docs/session-ownership.md`](../../session-ownership.md) — the per-file
  ownership gate, and the one-line warning near the top of its shared-files section that this doc is the
  practical follow-through for.
- [Annotate a citation only where structure and prose agree](annotate-citations-where-structure-and-prose-agree.md)
  — written by the same branch; the shared-tree check above is what kept its
  `CONCEPTS.md` half from being written twice.
- [Audit a port by enumerating the reference's CSS](audit-port-by-enumerating-reference-css.md)
  — one of the six files in the changed-in-both set, and one that merges cleanly.
