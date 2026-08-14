# Findings from dramatising the 15 stories — ticket #175

Measured, not inferred. Every path below was read on 2026-08-14 from the
worktree `kind-gliding-hejlsberg`.

## 1. "Spire" is load-bearing in shipped copy — 17 locations

James retired the name. It is welded into strings the player meets constantly.
`content/full-content.json`:

| Path | Surface |
|---|---|
| `whispers[0]` | the first line of story any player ever reads |
| `quests.ownShade.fragments[1]` | Own Shade quest prose |
| `variants.ownShade2.deathDialogue` | same sentence, second home |
| `quests.hollowLamplighter.meetings[2].ask` | the third price |
| `themes.act3.name`, `acts[2].name` | the act name itself |

`locale/zh-Hant.json` — 11 more, all UI chrome:
`ui.dawn.unlock.lamplighter`, `ui.embark.noVows`, `ui.embark.subChoose`,
`ui.embark.subWait`, `ui.end.ascendedSub`, `ui.end.fallenSub`,
`ui.help.climbBody`, `ui.lamp.sub`, `ui.map.survey`, `ui.rest.sub`,
and **`ui.menu.leaveSpireTitle`** — where the retired name is in the *key*,
so the rename is a code change, not only a copy change.

The 15 pages substitute the placeholder 【the Last Place】/【終境】 throughout,
including inside otherwise-verbatim quotes. That substitution is recorded by
`normalise.py`; the table above is the work-order.

## 2. The two locales already tell different stories

| | en | zh |
|---|---|---|
| run-start boon-giver | "The Lamplighter" | 掌燈人 |
| quest collector | "The Hollow Lamplighter" | 空燈掌燈人 |
| `meetings[3].ask` | "The **first keeper** gave you a boon." | 「**最初的掌燈人**曾贈你恩賜。」 |

In Chinese the collector puts himself in the boon-giver's lineage *by name*.
In English "keeper" is a different word from "Lamplighter", so the link is not
asserted. Stories 1, 10 and 13 all build their turn on exactly that link — in
zh they are half-shipped already; in en they need one word changed.

## 3. "Climb" outnumbers "pilgrimage" in the shipped fiction

The horizontal-pilgrimage decision (Q2) is not yet reflected in copy: shipped
strings say climb (6), Spire (4), pilgrim (2). Across the 15 story halves the
narration inherits it — 120 uses of "climb". Going horizontal is a copy pass
over every death, embark, help and dawn screen, not a map change alone.

## 4. What the writers independently converged on

Fourteen of fifteen agents, working blind of each other, reported the same
structural fact in their closing note: **the shipped strings carry the twist
better than new prose does.** Recurring examples they found on their own —
`"A previous pilgrim stands inside the stone"` (a loot prompt), whisper 11
`"Your monument does not always lie down"`, `"choose the fire your lantern
will carry"` (the run-start screen). None of these needs rewriting for the
twist to work; they need a subject supplied weeks later.

The second convergence, less comfortable: several noted that a reveal gated
behind six quest completions is **the most expensive scene reaching the fewest
players**. Whatever spine is chosen, that gate is the risk to design around.
