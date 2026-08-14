# Story candidates — fifteen spines for the lite-Hades arc

Working material for **[#175](https://github.com/fol2/glassvow/issues/175)** —
story design: the arc, the cast, and how dialogue is delivered. Fifteen
candidate stories, each dramatised as a *diegetic playthrough*: the story in the
order a player meets it, across runs and deaths, then a second half explaining
how it was built.

**No spine has been chosen.** Nothing here is a decision; #175 is open.

## Read them

Each page carries one toggle that switches **every string** — prose, captions,
section labels, and the typeface with them (Iowan Old Style ↔ 宋體 TC).

| # | Story | |
|--:|---|---|
| 00 | **[Fifteen Vows](https://claude.ai/code/artifact/69e0da47-04d1-4f7a-99c3-f7eb23228574)** | the index — start here |
| 01 | [The One in the Lantern 燈中人](https://claude.ai/code/artifact/f1bc47e5-df97-452e-9d34-19c1e46f9763) | |
| 02 | [The Abdication Rite 退位儀式](https://claude.ai/code/artifact/1a1e9962-b641-46fd-bc39-9af34fb4f261) | |
| 03 | [The Forgotten Vow 忘誓者](https://claude.ai/code/artifact/1acc5899-da04-4bed-8ac2-18d3119a106b) | |
| 04 | [The Vow That Wrote Itself 自書之誓](https://claude.ai/code/artifact/9bf20dc4-2f3e-44df-93cd-ad87d6a5ccd4) | |
| 05 | [The Unfallen 立亡者](https://claude.ai/code/artifact/9c9b83d2-a04d-4f46-a845-0ed135d02652) | |
| 06 | [The Hidden Seam 隱縫](https://claude.ai/code/artifact/b1d81008-4209-47b8-9032-74e77424c4d5) | |
| 07 | [The Seventh Piece of the Flame 一團火嘅第七份](https://claude.ai/code/artifact/997adf2a-67af-41cd-9815-064def2ad89b) | |
| 08 | [The One Who Walked Never Came Back 行嗰個從來冇返嚟](https://claude.ai/code/artifact/eb910891-3c5d-4234-b965-c9891c8f770f) | |
| 09 | [The Pawned Dawn 被抵押嘅黎明](https://claude.ai/code/artifact/23ba03b8-e511-4a12-bb13-3dc2b80ba4db) | |
| 10 | [A Vow of Forgetting 以忘立誓](https://claude.ai/code/artifact/a6701e90-7003-40f6-a40e-f4243ec38481) | |
| 11 | [The Glass Remembers Forward 玻璃記得將來](https://claude.ai/code/artifact/052ac096-c7d0-4e00-ba23-6d4c7ff7eead) | |
| 12 | [Your Monument Does Not Lie Down 你嘅碑唔會躺低](https://claude.ai/code/artifact/052de3c7-d898-4c19-b371-1c63975df626) | |
| 13 | [The Borrowed Flame 借火](https://claude.ai/code/artifact/bde0228b-56f2-4fe5-b371-49d6c9900505) | |
| 14 | [The Lit Side of the Glass 琉璃裏](https://claude.ai/code/artifact/e3727dd6-b470-4e07-8b01-d9f256ee1b21) | |
| 15 | [The Firecutter 切火之人](https://claude.ai/code/artifact/e7eb4f42-e247-4207-a745-3dd06baa541e) | |

Artifacts are private to the account that published them. This directory is the
durable copy: the pages regenerate from what is here.

## What is here

| Path | |
|---|---|
| `content/story-NN.json` | the deliverable. Every string is an `{en, zh}` pair — that is enforced, not conventional, which is what stops a language toggle silently dropping content. English is written as shipping game text, intended for `content/full-content.json`; Chinese is HK 書面語 matching `locale/zh-Hant.json`. |
| `img/` | the 60 illustrations authored for these pages, plus 5 Hollow Lamplighter candidates, at the 1200px the pages embed |
| `outlines/story-NN.md` | the source outline each page dramatises — ending-first, with the twist, the 起承轉合, and a misdirection audit quoting already-shipped lines |
| `outlines/asset-inventory.md` | what the game's art actually shows, and where the story space is empty |
| `outlines/findings.md` | what dramatising the fifteen exposed about shipped content |
| `render.py`, `render_index.py`, `validate.py` | regenerate the pages |
| `urls.json` | number → artifact URL |

## Regenerate

```bash
cd docs/story-candidates
python3 validate.py                       # every {en,zh} pair, image ref, asset path
python3 render.py content/story-*.json    # → pages/story-NN.html
python3 render_index.py                   # → pages/index.html
```

`pages/` is build output and is not committed. Requires Pillow.

Images marked `"source": "asset"` are read from the repo **at its current
state**, so a page rendered later shows whatever the game ships today. That is
deliberate: the stories argue from real art, and a page that quietly kept a
stale copy would be arguing from a picture that no longer exists.

## Provenance and limits

- Illustrations here are 1200px JPEG, the resolution the pages embed. The
  1024×1536 masters were not kept; `"subject"` in each content JSON is the
  prompt, and `docs/art-ledger.md` holds the house style block, so any of them
  can be remade.
- The stories were written before `assets/art/meta/hollow-lamplighter.png`
  existed and originally referenced the placeholder SVG; the paths were
  repointed when the real asset landed.
- **【終境】 / 【the Last Place】 is a placeholder.** "Spire" is retired, and
  every occurrence — including inside otherwise-verbatim quotes of shipped
  strings — was substituted. `outlines/findings.md` lists the 17 shipped
  locations that still carry the retired name; that list is the rename
  work-order, and it includes `ui.menu.leaveSpireTitle`, where the name is in
  the locale **key**, so the rename is a code change and not only a copy change.
- Names other than 【終境】 are provisional too. Assets are the stable layer;
  names are not.
