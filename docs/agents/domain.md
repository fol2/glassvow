# Domain Documentation Consumption

Use project vocabulary without preloading the whole knowledge base.

## Search before reading

1. Extract the exact domain terms, files, and behaviours named by the task.
2. Search `CONCEPTS.md` for those terms and read only the matching sections plus nearby definitions needed to disambiguate them.
3. Read a `CONTEXT.md`, `CONTEXT-MAP.md`, or ADR only when the changed surface or a found reference points to it.
4. Search `docs/solutions/` by component, error, or behaviour before broad exploration.
5. Stop once the task's acceptance, invariants, and vocabulary are resolved.

Do not read all of `CONCEPTS.md`, every ADR, or historical design packets as an orientation ritual. Missing `CONTEXT.md`, `CONTEXT-MAP.md`, or `docs/adr/` is not a blocker; proceed silently and create documentation only when a real decision needs durable authority.

## Use the governed vocabulary

Use the project term in issue titles, hypotheses, code, tests, and review. Do not drift to a synonym that `CONCEPTS.md` explicitly rejects. When a needed concept is absent, first decide whether the task is inventing unnecessary language. Add a term only after the project has accepted a genuine distinction.

## Conflicts

Surface a contradiction with an active ADR, commercial contract, or glossary definition explicitly. Do not silently override it and do not load unrelated documents in search of permission. The task must either conform, reopen the governing decision, or stop with a concrete blocker.

## Handoff capsule

A domain handoff contains only the relevant definitions, authoritative links or sections, decision, affected boundaries, exact head and evidence state, and unresolved question. It does not copy the full glossary or investigation transcript.
