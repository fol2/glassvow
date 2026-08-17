# Phase 1 story inventory — #356

Generated from `locale/en.json`, `locale/zh-Hant.json`, `content/scenes.json`, and `content/line-table.json` on the acceptance branch. Every row is bilingual (zh-Hant ≠ en, neither empty, neither the key literal).

Authority for `story.*` copy is the locale catalogues. Scene *structure* (beat order, art, motion) lives in `content/scenes.json`. Line-table copy is bilingual on the row itself.

## Census

| Family | Count | Authority | Runtime host family |
|---|---:|---|---|
| `story.*` scene leaves | 79 | `locale/{en,zh-Hant}.json` + `content/scenes.json` | `ScenePlayer` |
| `story.dawn.*` | 25 | `locale/{en,zh-Hant}.json` | `DawnScreen` |
| `story.event-*` | 18 | `locale/{en,zh-Hant}.json` | `EventScreen` |
| **`story.*` total** | **122** | | |
| line-table hearth | 60 | `content/line-table.json` | `DepartureStaging` |
| line-table waystone | 60 | `content/line-table.json` | pool `ScenePlayer` |
| line-table loss | 50 | `content/line-table.json` | `VigilScreen` |
| line-table death/closer/whisper | 8 | `content/line-table.json` | Dawn / Vigil residue |
| **line-table total** | **178** | | |
| `content.whispers.*` | 24 | `locale/{en,zh-Hant}.json` | `VigilScreen` / Dawn |
| `content.quests.*` (companion) | 57 | `content/full-content.json` (en bake) + locale overlay | Vigil rose, Dawn, quest HUD |

Unhosted `story.*` leaves: **0**. Duplicate scene authorities: **0**. Fallback-only leaves: **0**.

## `story.*` leaves

| Leaf | Authority | Runtime host | Journeys |
|---|---|---|---|
| `story.act4-entry.b1.l1` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `act4-entry` | D (first), E (anti-replay) |
| `story.act4-entry.b1.l2` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `act4-entry` | D (first), E (anti-replay) |
| `story.act4-entry.b1.l3` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `act4-entry` | D (first), E (anti-replay) |
| `story.act4-node1.b1.l1` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `act4-node1` | D, E (anti-replay) |
| `story.act4-node1.b1.l2` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `act4-node1` | D, E (anti-replay) |
| `story.act4-node2.b1.l1` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `act4-node2` | D, E (anti-replay) |
| `story.act4-node2.b1.l2` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `act4-node2` | D, E (anti-replay) |
| `story.act4-node3.b1.l1` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `act4-node3` | D, E (anti-replay) |
| `story.act4-node3.b1.l2` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `act4-node3` | D, E (anti-replay) |
| `story.act4-node4.b1.l1` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `act4-node4` | D, E (anti-replay) |
| `story.act4-node4.b1.l2` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `act4-node4` | D, E (anti-replay) |
| `story.act4-node4.b1.l3` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `act4-node4` | D, E (anti-replay) |
| `story.act4-node4.b1.l4` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `act4-node4` | D, E (anti-replay) |
| `story.act4-node4.b1.l5` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `act4-node4` | D, E (anti-replay) |
| `story.act4-node5.b1.l1` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `act4-node5` | D, E (anti-replay) |
| `story.act4-node5.b1.l2` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `act4-node5` | D, E (anti-replay) |
| `story.act4-node5.b1.l3` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `act4-node5` | D, E (anti-replay) |
| `story.act4-node5.b1.l4` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `act4-node5` | D, E (anti-replay) |
| `story.dawn.eighthOmen.done` | `locale/en.json` + `locale/zh-Hant.json` | DawnScreen ← Main dawn planting | A, D |
| `story.dawn.eighthOmen.p1` | `locale/en.json` + `locale/zh-Hant.json` | DawnScreen ← Main dawn planting | A, D |
| `story.dawn.hollowLamplighter.done` | `locale/en.json` + `locale/zh-Hant.json` | DawnScreen ← Main dawn planting | A, D |
| `story.dawn.hollowLamplighter.p1` | `locale/en.json` + `locale/zh-Hant.json` | DawnScreen ← Main dawn planting | A, D |
| `story.dawn.hollowLamplighter.p2` | `locale/en.json` + `locale/zh-Hant.json` | DawnScreen ← Main dawn planting | A, D |
| `story.dawn.hollowLamplighter.p3` | `locale/en.json` + `locale/zh-Hant.json` | DawnScreen ← Main dawn planting | A, D |
| `story.dawn.hollowLamplighter.p4` | `locale/en.json` + `locale/zh-Hant.json` | DawnScreen ← Main dawn planting | A, D |
| `story.dawn.ownShade.done` | `locale/en.json` + `locale/zh-Hant.json` | DawnScreen ← Main dawn planting | A, D |
| `story.dawn.ownShade.p1` | `locale/en.json` + `locale/zh-Hant.json` | DawnScreen ← Main dawn planting | A, D |
| `story.dawn.ownShade.p2` | `locale/en.json` + `locale/zh-Hant.json` | DawnScreen ← Main dawn planting | A, D |
| `story.dawn.paleOnes.done` | `locale/en.json` + `locale/zh-Hant.json` | DawnScreen ← Main dawn planting | A, D |
| `story.dawn.paleOnes.p1` | `locale/en.json` + `locale/zh-Hant.json` | DawnScreen ← Main dawn planting | A, D |
| `story.dawn.paleOnes.p2` | `locale/en.json` + `locale/zh-Hant.json` | DawnScreen ← Main dawn planting | A, D |
| `story.dawn.pane.1` | `locale/en.json` + `locale/zh-Hant.json` | DawnScreen ← Main dawn planting | A, D |
| `story.dawn.pane.2` | `locale/en.json` + `locale/zh-Hant.json` | DawnScreen ← Main dawn planting | A, D |
| `story.dawn.pane.3` | `locale/en.json` + `locale/zh-Hant.json` | DawnScreen ← Main dawn planting | A, D |
| `story.dawn.pane.4` | `locale/en.json` + `locale/zh-Hant.json` | DawnScreen ← Main dawn planting | A, D |
| `story.dawn.pane.5` | `locale/en.json` + `locale/zh-Hant.json` | DawnScreen ← Main dawn planting | A, D |
| `story.dawn.unreadablePage.done` | `locale/en.json` + `locale/zh-Hant.json` | DawnScreen ← Main dawn planting | A, D |
| `story.dawn.unreadablePage.p1` | `locale/en.json` + `locale/zh-Hant.json` | DawnScreen ← Main dawn planting | A, D |
| `story.dawn.unreadablePage.p2` | `locale/en.json` + `locale/zh-Hant.json` | DawnScreen ← Main dawn planting | A, D |
| `story.dawn.unreadablePage.p3` | `locale/en.json` + `locale/zh-Hant.json` | DawnScreen ← Main dawn planting | A, D |
| `story.dawn.unreadablePage.p4` | `locale/en.json` + `locale/zh-Hant.json` | DawnScreen ← Main dawn planting | A, D |
| `story.dawn.usurper.done` | `locale/en.json` + `locale/zh-Hant.json` | DawnScreen ← Main dawn planting | A, D |
| `story.dawn.usurper.p1` | `locale/en.json` + `locale/zh-Hant.json` | DawnScreen ← Main dawn planting | A, D |
| `story.event-fleshTrader.c0` | `locale/en.json` + `locale/zh-Hant.json` | EventScreen ← `fleshTrader` | A |
| `story.event-fleshTrader.c1` | `locale/en.json` + `locale/zh-Hant.json` | EventScreen ← `fleshTrader` | A |
| `story.event-fleshTrader.coda` | `locale/en.json` + `locale/zh-Hant.json` | EventScreen ← `fleshTrader` | A |
| `story.event-forgottenShrine.c0` | `locale/en.json` + `locale/zh-Hant.json` | EventScreen ← `forgottenShrine` | A |
| `story.event-forgottenShrine.c1` | `locale/en.json` + `locale/zh-Hant.json` | EventScreen ← `forgottenShrine` | A |
| `story.event-forgottenShrine.c2` | `locale/en.json` + `locale/zh-Hant.json` | EventScreen ← `forgottenShrine` | A |
| `story.event-forgottenShrine.coda` | `locale/en.json` + `locale/zh-Hant.json` | EventScreen ← `forgottenShrine` | A |
| `story.event-library.c0` | `locale/en.json` + `locale/zh-Hant.json` | EventScreen ← `library` | A, F |
| `story.event-library.c1` | `locale/en.json` + `locale/zh-Hant.json` | EventScreen ← `library` | A, F |
| `story.event-library.coda` | `locale/en.json` + `locale/zh-Hant.json` | EventScreen ← `library` | A, F |
| `story.event-mirror.c0` | `locale/en.json` + `locale/zh-Hant.json` | EventScreen ← `mirror` | A |
| `story.event-mirror.c1` | `locale/en.json` + `locale/zh-Hant.json` | EventScreen ← `mirror` | A |
| `story.event-mirror.c2` | `locale/en.json` + `locale/zh-Hant.json` | EventScreen ← `mirror` | A |
| `story.event-mirror.coda` | `locale/en.json` + `locale/zh-Hant.json` | EventScreen ← `mirror` | A |
| `story.event-woundedKnight.c0` | `locale/en.json` + `locale/zh-Hant.json` | EventScreen ← `woundedKnight` | A |
| `story.event-woundedKnight.c1` | `locale/en.json` + `locale/zh-Hant.json` | EventScreen ← `woundedKnight` | A |
| `story.event-woundedKnight.c2` | `locale/en.json` + `locale/zh-Hant.json` | EventScreen ← `woundedKnight` | A |
| `story.event-woundedKnight.coda` | `locale/en.json` + `locale/zh-Hant.json` | EventScreen ← `woundedKnight` | A |
| `story.finale-loss.b1.l1` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `finale-loss` | E |
| `story.finale-loss.b1.l2` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `finale-loss` | E |
| `story.finale-win.b1.l1` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `finale-win` | D, E |
| `story.finale-win.b1.l2` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `finale-win` | D, E |
| `story.finale-win.b1.l3` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `finale-win` | D, E |
| `story.finale.b1.l1` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `finale` | D (first), E (anti-replay), F |
| `story.finale.b1.l2` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `finale` | D (first), E (anti-replay), F |
| `story.finale.b1.l3` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `finale` | D (first), E (anti-replay), F |
| `story.finale.b2.l1` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `finale` | D (first), E (anti-replay), F |
| `story.finale.b2.l2` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `finale` | D (first), E (anti-replay), F |
| `story.finale.b2.l3` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `finale` | D (first), E (anti-replay), F |
| `story.finale.b2.l4` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `finale` | D (first), E (anti-replay), F |
| `story.lamplighter-m1.post.l1` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `lamplighter-m1-post` | A, B |
| `story.lamplighter-m1.post.l2` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `lamplighter-m1-post` | A, B |
| `story.lamplighter-m1.pre.l1` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `lamplighter-m1-pre` | A, B |
| `story.lamplighter-m1.pre.l2` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `lamplighter-m1-pre` | A, B |
| `story.lamplighter-m1.pre.l3` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `lamplighter-m1-pre` | A, B |
| `story.lamplighter-m2.post.l1` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `lamplighter-m2-post` | B |
| `story.lamplighter-m2.post.l2` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `lamplighter-m2-post` | B |
| `story.lamplighter-m2.pre.l1` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `lamplighter-m2-pre` | B |
| `story.lamplighter-m2.pre.l2` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `lamplighter-m2-pre` | B |
| `story.lamplighter-m2.pre.l3` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `lamplighter-m2-pre` | B |
| `story.lamplighter-m3.post.l1` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `lamplighter-m3-post` | B |
| `story.lamplighter-m3.post.l2` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `lamplighter-m3-post` | B |
| `story.lamplighter-m3.pre.l1` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `lamplighter-m3-pre` | B |
| `story.lamplighter-m3.pre.l2` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `lamplighter-m3-pre` | B |
| `story.lamplighter-m3.pre.l3` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `lamplighter-m3-pre` | B |
| `story.lamplighter-m4.post.l1` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `lamplighter-m4-post` | B |
| `story.lamplighter-m4.post.l2` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `lamplighter-m4-post` | B |
| `story.lamplighter-m4.pre.l1` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `lamplighter-m4-pre` | B |
| `story.lamplighter-m4.pre.l2` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `lamplighter-m4-pre` | B |
| `story.lamplighter-m4.pre.l3` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `lamplighter-m4-pre` | B |
| `story.lamplighter-m4.pre.l4` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `lamplighter-m4-pre` | B |
| `story.lamplighter-m5.post.l1` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `lamplighter-m5-post` | B |
| `story.lamplighter-m5.post.l2` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `lamplighter-m5-post` | B |
| `story.lamplighter-m5.post.l3` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `lamplighter-m5-post` | B |
| `story.lamplighter-m5.pre.l1` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `lamplighter-m5-pre` | B |
| `story.lamplighter-m5.pre.l2` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `lamplighter-m5-pre` | B |
| `story.lamplighter-m5.pre.l3` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `lamplighter-m5-pre` | B |
| `story.opening.b1.l1` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `opening` | A, B (anti-replay), F |
| `story.opening.b1.l2` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `opening` | A, B (anti-replay), F |
| `story.opening.b2.l1` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `opening` | A, B (anti-replay), F |
| `story.opening.b2.l2` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `opening` | A, B (anti-replay), F |
| `story.opening.b2.l3` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `opening` | A, B (anti-replay), F |
| `story.opening.b3.l1` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `opening` | A, B (anti-replay), F |
| `story.opening.b3.l2` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `opening` | A, B (anti-replay), F |
| `story.opening.b4.l1` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `opening` | A, B (anti-replay), F |
| `story.unsealing-short.b1.l1` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `unsealing-short` | D (repeat), E |
| `story.unsealing.b1.l1` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `unsealing` | D (first) |
| `story.unsealing.b1.l2` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `unsealing` | D (first) |
| `story.unsealing.b1.l3` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `unsealing` | D (first) |
| `story.unsealing.b2.l1` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `unsealing` | D (first) |
| `story.unsealing.b2.l2` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `unsealing` | D (first) |
| `story.unsealing.b2.l3` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `unsealing` | D (first) |
| `story.unsealing.b3.l1` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `unsealing` | D (first) |
| `story.unsealing.b3.l2` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `unsealing` | D (first) |
| `story.unsealing.b3.l3` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `unsealing` | D (first) |
| `story.unsealing.b3.l4` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `unsealing` | D (first) |
| `story.unsealing.b4.l1` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `unsealing` | D (first) |
| `story.unsealing.b4.l2` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `unsealing` | D (first) |
| `story.unsealing.b4.l3` | `locale/en.json` + `locale/zh-Hant.json` | ScenePlayer ← `unsealing` | D (first) |

## Line-table rows

| Leaf | Slot | Authority | Runtime host | Journeys |
|---|---|---|---|---|
| `whisper.channel` | `whisper` | `content/line-table.json` | DawnScreen whisper channel | A |
| `death.ownShade1` | `death.ownShade1` | `content/line-table.json` | DawnScreen / Vigil residue | C, D |
| `death.ownShade2` | `death.ownShade2` | `content/line-table.json` | DawnScreen / Vigil residue | C, D |
| `death.ownShade3` | `death.ownShade3` | `content/line-table.json` | DawnScreen / Vigil residue | C, D |
| `closer.ownShade` | `closer.ownShade` | `content/line-table.json` | DawnScreen / Vigil residue | C, D |
| `closer.usurper` | `closer.usurper` | `content/line-table.json` | DawnScreen / Vigil residue | C, D |
| `closer.eighthOmen` | `closer.eighthOmen` | `content/line-table.json` | DawnScreen / Vigil residue | C, D |
| `pool.hearth.h01` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h02` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h03` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h04` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h05` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h06` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h07` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h08` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h09` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h10` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h11` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h12` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h13` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h14` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h15` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h16` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h17` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h18` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h19` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h20` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h21` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h22` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h23` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h24` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h25` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h26` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h27` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h28` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h29` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h30` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h31` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h32` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h33` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h34` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h35` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h36` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h37` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h38` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h39` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h40` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h41` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h42` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h43` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h44` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h45` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h46` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h47` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h48` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h49` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h50` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h51` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h52` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h53` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h54` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h55` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h56` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h57` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h58` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h59` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.hearth.h60` | `hearth` | `content/line-table.json` | DepartureStaging | A, B |
| `pool.waystone.w01` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w02` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w03` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w04` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w05` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w06` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w07` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w08` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w09` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w10` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w11` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w12` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w13` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w14` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w15` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w16` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w17` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w18` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w19` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w20` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w21` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w22` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w23` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w24` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w25` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w26` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w27` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w28` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w29` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w30` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w31` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w32` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w33` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w34` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w35` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w36` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w37` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w38` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w39` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w40` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w41` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w42` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w43` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w44` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w45` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w46` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w47` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w48` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w49` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w50` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w51` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w52` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w53` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w54` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w55` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w56` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w57` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w58` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w59` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.waystone.w60` | `waystone` | `content/line-table.json` | ScenePlayer pool beat | A, F |
| `pool.loss.e01` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e02` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e03` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e04` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e05` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e06` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e07` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e08` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e09` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e10` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e11` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e12` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e13` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e14` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e15` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e16` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e17` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e18` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e19` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e20` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e21` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e22` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e23` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e24` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e25` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e26` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e27` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e28` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e29` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e30` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e31` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e32` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e33` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e34` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e35` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e36` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e37` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e38` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e39` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e40` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e41` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e42` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e43` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e44` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e45` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e46` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e47` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e48` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e49` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `pool.loss.e50` | `loss` | `content/line-table.json` | VigilScreen epitaph tab | C |
| `payoff.mirror` | `closer.l3` | `content/line-table.json` | DawnScreen / Vigil residue | C, D |

## Whispers

| Leaf | Authority | Runtime host | Journeys |
|---|---|---|---|
| `content.whispers.0` | `locale/en.json` + `locale/zh-Hant.json` | VigilScreen / DawnScreen | A, D |
| `content.whispers.1` | `locale/en.json` + `locale/zh-Hant.json` | VigilScreen / DawnScreen | A, D |
| `content.whispers.2` | `locale/en.json` + `locale/zh-Hant.json` | VigilScreen / DawnScreen | A, D |
| `content.whispers.3` | `locale/en.json` + `locale/zh-Hant.json` | VigilScreen / DawnScreen | A, D |
| `content.whispers.4` | `locale/en.json` + `locale/zh-Hant.json` | VigilScreen / DawnScreen | A, D |
| `content.whispers.5` | `locale/en.json` + `locale/zh-Hant.json` | VigilScreen / DawnScreen | A, D |
| `content.whispers.6` | `locale/en.json` + `locale/zh-Hant.json` | VigilScreen / DawnScreen | A, D |
| `content.whispers.7` | `locale/en.json` + `locale/zh-Hant.json` | VigilScreen / DawnScreen | A, D |
| `content.whispers.8` | `locale/en.json` + `locale/zh-Hant.json` | VigilScreen / DawnScreen | A, D |
| `content.whispers.9` | `locale/en.json` + `locale/zh-Hant.json` | VigilScreen / DawnScreen | A, D |
| `content.whispers.10` | `locale/en.json` + `locale/zh-Hant.json` | VigilScreen / DawnScreen | A, D |
| `content.whispers.11` | `locale/en.json` + `locale/zh-Hant.json` | VigilScreen / DawnScreen | A, D |
| `content.whispers.12` | `locale/en.json` + `locale/zh-Hant.json` | VigilScreen / DawnScreen | A, D |
| `content.whispers.13` | `locale/en.json` + `locale/zh-Hant.json` | VigilScreen / DawnScreen | A, D |
| `content.whispers.14` | `locale/en.json` + `locale/zh-Hant.json` | VigilScreen / DawnScreen | A, D |
| `content.whispers.15` | `locale/en.json` + `locale/zh-Hant.json` | VigilScreen / DawnScreen | A, D |
| `content.whispers.16` | `locale/en.json` + `locale/zh-Hant.json` | VigilScreen / DawnScreen | A, D |
| `content.whispers.17` | `locale/en.json` + `locale/zh-Hant.json` | VigilScreen / DawnScreen | A, D |
| `content.whispers.18` | `locale/en.json` + `locale/zh-Hant.json` | VigilScreen / DawnScreen | A, D |
| `content.whispers.19` | `locale/en.json` + `locale/zh-Hant.json` | VigilScreen / DawnScreen | A, D |
| `content.whispers.20` | `locale/en.json` + `locale/zh-Hant.json` | VigilScreen / DawnScreen | A, D |
| `content.whispers.21` | `locale/en.json` + `locale/zh-Hant.json` | VigilScreen / DawnScreen | A, D |
| `content.whispers.22` | `locale/en.json` + `locale/zh-Hant.json` | VigilScreen / DawnScreen | A, D |
| `content.whispers.23` | `locale/en.json` + `locale/zh-Hant.json` | VigilScreen / DawnScreen | A, D |

## Companion — `content.quests.*`

Not in the 122 `story.*` census. Hosted at runtime (Vigil rose labels, Dawn inscriptions, quest HUD). English bake is `content/full-content.json`; zh-Hant overlays from the locale catalogue.

| Leaf | Authority | Runtime host | Journeys |
|---|---|---|---|
| `content.quests.eighthOmen.inscription` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.eighthOmen.mode` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.eighthOmen.name` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.eighthOmen.resolved` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.eighthOmen.waystoneEchoes.0` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.eighthOmen.waystoneEchoes.1` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.eighthOmen.waystoneEchoes.2` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.eighthOmen.waystoneEchoes.3` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.hollowLamplighter.inscription` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.hollowLamplighter.meetings.0.accepted` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.hollowLamplighter.meetings.0.ask` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.hollowLamplighter.meetings.0.cannot` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.hollowLamplighter.meetings.0.paid` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.hollowLamplighter.meetings.1.ask` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.hollowLamplighter.meetings.1.cannot` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.hollowLamplighter.meetings.1.paid` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.hollowLamplighter.meetings.2.ask` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.hollowLamplighter.meetings.2.cannot` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.hollowLamplighter.meetings.2.paid` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.hollowLamplighter.meetings.3.ask` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.hollowLamplighter.meetings.3.cannot` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.hollowLamplighter.meetings.3.paid` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.hollowLamplighter.meetings.4.ask` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.hollowLamplighter.meetings.4.cannot` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.hollowLamplighter.meetings.4.paid` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.hollowLamplighter.mode` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.hollowLamplighter.name` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.ownShade.final` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.ownShade.fragments.0` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.ownShade.fragments.1` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.ownShade.fragments.2` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.ownShade.inscription` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.ownShade.mode` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.ownShade.name` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.paleOnes.huntInscription` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.paleOnes.huntName` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.paleOnes.inscription` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.paleOnes.mode` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.paleOnes.name` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.paleOnes.progress.0` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.paleOnes.progress.1` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.unreadablePage.inscription` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.unreadablePage.mode` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.unreadablePage.name` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.unreadablePage.pages.0` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.unreadablePage.pages.1` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.unreadablePage.pages.2` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.unreadablePage.pages.3` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.unreadablePage.pages.4` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.usurper.bought` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.usurper.death` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.usurper.inscription` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.usurper.itemName` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.usurper.itemText` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.usurper.mode` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.usurper.name` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
| `content.quests.usurper.poor` | `content/full-content.json` + locale overlay | Vigil / Dawn / quest HUD | A, D |
