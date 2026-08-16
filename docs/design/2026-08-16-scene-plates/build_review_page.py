#!/usr/bin/env python3
"""Build the self-contained review page for the #310 scene plates.

Artifacts run under a CSP that blocks every external host, so each plate is
inlined as a JPEG data URI. Rebuild after any new candidate lands:

    python3 docs/design/2026-08-16-scene-plates/build_review_page.py
"""
from __future__ import annotations

import base64
import io
from pathlib import Path

from PIL import Image

HERE = Path(__file__).parent
CANDIDATES = HERE / "candidates"
OUT = HERE / "review.html"

EMBED_W = 1400
EMBED_Q = 80

# Scene order — the plates play in this sequence, which is why they are numbered.
PLATES = [
    dict(
        n="1", slug="opening-hearth", title="The hearth", scene="Opening · beats ①③④",
        anchor="00 §5 L0 — 出發時鏡頭多留一秒,爐前仍坐着一個兜帽身影",
        band="You are awake.",
        state="shipped",
        read="<b>B</b> won on staging, then the figure ruling voided both first-round "
             "candidates: A and B bake in a seated hooded figure, and the #283 Keeper "
             "overlays this same plate for beat ②, which puts two bodies on screen. "
             "James ruled one. <b>C</b> and <b>D</b> re-render the hall deserted in B's "
             "staging — <b>C shipped</b>, for the long low bare hearth step that gives "
             "the overlay the most room and the clearest read of the east road.",
        flaw="爐前仍坐着一個兜帽身影 is now carried entirely by the #283 overlay, so that "
             "overlay has to persist through beat ④'s linger and the every-departure "
             "ambient staging. It is no longer free — #283/#309 wiring.",
        variants=["opening-hearth-c", "opening-hearth-d",
                  "opening-hearth-a", "opening-hearth-b"],
    ),
    dict(
        n="2", slug="unsealing-mirror-queue", title="One queue in the mirror",
        scene="Unsealing · full",
        anchor="00 §2.6 — 彩窗全亮的一刻變成鏡:窗中站滿一排「你」,每人胸口一點光",
        band="Stand at the Threshold.",
        state="shipped",
        read="<b>B shipped.</b> <b>A</b> reproduces the treatment rejected on the "
             "bake-off — the crowd restarts inside every lobe. The lever was not a "
             "stronger negative prompt: a round lobed window <i>structurally invites</i> "
             "per-lobe grouping. B restages it as six tall lancets under one arch, so a "
             "single row crosses all six at one height and the mullions pass in front of "
             "it like railings. One queue, seen once.",
        flaw="Its six lancets are six because the architecture forces the count — the round windows elsewhere in the set count six too, which an earlier revision of this page wrongly denied.",
        variants=["unsealing-mirror-queue-a", "unsealing-mirror-queue-b"],
    ),
    dict(
        n="3", slug="unsealing-monuments-push", title="The monuments push the door",
        scene="Unsealing · full",
        anchor="00 §2.6 — 門不是你開的,是他們一齊推開的",
        band="", state="clean",
        read="Monuments straightening out of the ground into walkers along the road, "
             "hands flat on the stone, the gold seam cutting back toward us, every back "
             "turned. The still-crooked stones in the foreground carry the transition.",
        flaw="",
        variants=["unsealing-monuments-push-a"],
    ),
    dict(
        n="—", slug="unsealing-door-open", title="The door opens",
        scene="Unsealing · short",
        anchor="07-scenes §8 — 推門 plate 的門開 crop",
        band="", state="derived",
        read="Not rendered. Crop <code>(600, 0, 1536, 624)</code> of plate 3, resampled "
             "to 1536×1024. The crop turned out to carry a rhyme nobody planned: the "
             "door's carved relief of hooded figures pushing sits directly above the "
             "real queue doing the same thing.",
        flaw="~1.6× upsample. Soft at full size, sound under a dialogue band.",
        variants=["unsealing-door-open-a"],
    ),
    dict(
        n="4", slug="act4-node1", title="門檻′ — the threshold's inner face",
        scene="Act IV · node 1",
        anchor="03-acts — motif 池:彩窗六格、封門浮雕",
        band="", state="shipped",
        read="<b>B shipped.</b> <b>A</b> has the richer light, and fills its six lobes with haloed saints — "
             "generic cathedral iconography where the six emberglass shards belong. "
             "<b>B</b> fixes that, counts six, and reads its monuments as grave markers "
             "rather than obelisks.",
        flaw="B's light reads as coming <i>from</i> the window, so 倒轉爐光 — the inverted "
             "hearth light that is the whole grammar of Act IV — goes missing.",
        variants=["act4-node1-a", "act4-node1-b"],
    ),
    dict(
        n="5", slug="act4-node2", title="III′ — the Obsidian Court mirrored",
        scene="Act IV · node 2",
        anchor="03-acts — motif 池:斷環、星、黑曜",
        band="", state="shipped",
        read="<b>B shipped.</b> <b>A</b> sits properly in the indigo and violet, and is canon-true on motif "
             "— the broken ring, the stars doubled in the floor. But it is "
             "<b>symmetric</b>, against the stated bar, and its monuments are "
             "indistinguishable from the architecture. <b>B</b> fixes both: camera off "
             "the left edge, one colonnade sweeping right, rough-hewn stones legibly "
             "separate from the smooth pillars.",
        flaw="B's cost is colour — nearly monochrome gold-on-black, and it reads as "
             "polished stone rather than glass.",
        variants=["act4-node2-a", "act4-node2-b"],
    ),
    dict(
        n="6", slug="act4-node3", title="II′ — the Sunken City mirrored",
        scene="Act IV · node 3",
        anchor="03-acts — motif 池:水、假光、圖書館",
        band="", state="clean",
        read="Water as the ceiling with books rising into it, drowned shelves, the green "
             "false lanterns lighting nothing against the one true amber arriving from "
             "the far end. Shadows thrown forward, motes rising.",
        flaw="",
        variants=["act4-node3-a"],
    ),
    dict(
        n="7", slug="act4-node4", title="I′ — the Ash Wood mirrored",
        scene="Act IV · node 4",
        anchor="03-acts — motif 池:灰、根、雙燈",
        band="", state="shipped",
        read="<b>B shipped.</b> The sharpest fork in the set. <b>A</b> is the prettier picture and it is "
             "just the Ash Wood — the canopy is ordinary branches and nothing is "
             "inverted. <b>B</b> lands it: a ceiling of hanging roots and clotted soil, "
             "trunks growing downward, ash rising.",
        flaw="B is stranger and less classically pretty. It is also the only one of the "
             "two that is Act IV.",
        variants=["act4-node4-a", "act4-node4-b"],
    ),
    dict(
        n="8", slug="act4-node5", title="爐邊′ — the Gilded City gate",
        scene="Act IV · node 5",
        anchor="00 §8.1 — 金城=爐邊真貌,入城=歸家",
        band="", state="clean",
        read="The best plate of the nine. The gate is unmistakably a fireplace mouth "
             "built at cathedral scale, so the reveal that 金城 <i>is</i> the hearth seen "
             "from the far side is carried by the architecture itself rather than by a "
             "line of dialogue. Queue, chest-lights, cloud sea, monuments.",
        flaw="The queue reads as walking toward camera rather than away, and the lights "
             "are held in hands rather than at the chest.",
        variants=["act4-node5-a"],
    ),
    dict(
        n="9", slug="finale-swap", title="The swap — you walk, it stays",
        scene="Finale",
        anchor="00 §2.6 — 終戰不是把 boss 打倒,而是換位:你走,它留",
        band="", state="clean",
        read="Reads at a glance, which is the whole requirement: the sitting figure near, "
             "right, and cold; the walking figure far, left, and already dissolving into "
             "the gold. The empty lit floor between them is the swap.",
        flaw="Background window is a four-lobe again — small, and behind everything.",
        variants=["finale-swap-a"],
    ),
]

STATE_LABEL = {
    "clean": "shipped",
    "fork": "pick one",
    "shipped": "shipped",
    "derived": "derived",
}


def data_uri(name: str) -> str:
    path = CANDIDATES / f"{name}.png"
    im = Image.open(path).convert("RGB")
    im.thumbnail((EMBED_W, EMBED_W), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=EMBED_Q, optimize=True, progressive=True)
    return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()


def figure(name: str, band: str, solo: bool) -> str:
    letter = name.rsplit("-", 1)[-1].upper()
    tag = "" if solo else f'<span class="pick">{letter}</span>'
    band_html = f'<p class="band-copy">{band}</p>' if band else ""
    return f"""<figure class="plate">
  <button class="frame" type="button" data-full="{name}" aria-label="Open {name} full size">
    <img src="{data_uri(name)}" alt="{name}" loading="lazy">
    <span class="band">{band_html}</span>
  </button>
  <figcaption>{tag}<code>{name}.png</code></figcaption>
</figure>"""


def row(p: dict) -> str:
    solo = len(p["variants"]) == 1
    figs = "\n".join(figure(v, p["band"], solo) for v in p["variants"])
    flaw = f'<p class="flaw">{p["flaw"]}</p>' if p["flaw"] else ""
    return f"""<section class="row" id="{p['slug']}">
  <header class="row-head">
    <span class="idx">{p['n']}</span>
    <div class="row-title">
      <h2>{p['title']}</h2>
      <p class="scene">{p['scene']}</p>
    </div>
    <span class="state s-{p['state']}">{STATE_LABEL[p['state']]}</span>
  </header>
  <p class="anchor">{p['anchor']}</p>
  <div class="plates {'solo' if solo else 'duo'}">
{figs}
  </div>
  <div class="read"><p>{p['read']}</p>{flaw}</div>
</section>"""


HEAD = """<title>The Nine Plates</title>
<style>
:root{
  --ground:#100D13; --raised:#17141B; --sunk:#0A080D;
  --ink:#EDE4D6; --ink-dim:#A2968A; --ink-faint:#6E6459;
  --rule:#2A2431; --rule-soft:#1F1A26;
  --ember:#E39A32; --gilt:#C6A15E;
  --clean:#7E9A6C; --fork:#8878C4; --derived:#5E8FA3;
  --shadow:0 18px 44px rgb(0 0 0 / .55);
}
@media (prefers-color-scheme: light){
  :root:not([data-theme="dark"]){
    --ground:#EDE5D6; --raised:#F6F0E4; --sunk:#DED4C2;
    --ink:#221C18; --ink-dim:#5C5045; --ink-faint:#8B7E70;
    --rule:#CDBFA9; --rule-soft:#DFD4C1;
    --ember:#A96A15; --gilt:#8A6A28;
    --clean:#4C6B3C; --fork:#544590; --derived:#2F6076;
    --shadow:0 14px 34px rgb(60 44 20 / .18);
  }
}
:root[data-theme="light"]{
  --ground:#EDE5D6; --raised:#F6F0E4; --sunk:#DED4C2;
  --ink:#221C18; --ink-dim:#5C5045; --ink-faint:#8B7E70;
  --rule:#CDBFA9; --rule-soft:#DFD4C1;
  --ember:#A96A15; --gilt:#8A6A28;
  --clean:#4C6B3C; --fork:#544590; --derived:#2F6076;
  --shadow:0 14px 34px rgb(60 44 20 / .18);
}

*{box-sizing:border-box}
body{
  margin:0; background:var(--ground); color:var(--ink);
  font-family:'Iowan Old Style','Palatino Linotype',Palatino,'Book Antiqua',Georgia,serif;
  font-size:17px; line-height:1.62;
  -webkit-font-smoothing:antialiased;
}
code,.mono,.idx,.pick,.state,figcaption{
  font-family:ui-monospace,'SF Mono',SFMono-Regular,Menlo,Consolas,monospace;
}
h1,h2{text-wrap:balance; margin:0; font-weight:600; letter-spacing:-.01em}
a{color:var(--ember)}
:focus-visible{outline:2px solid var(--ember); outline-offset:3px; border-radius:2px}

.wrap{max-width:1180px; margin:0 auto; padding:0 24px}

/* ── masthead ─────────────────────────────────────── */
.mast{padding:72px 0 30px; border-bottom:1px solid var(--rule)}
.eyebrow{
  font-family:ui-monospace,'SF Mono',Menlo,monospace;
  font-size:11px; letter-spacing:.18em; text-transform:uppercase;
  color:var(--gilt); margin:0 0 18px;
}
.mast h1{font-size:clamp(2.4rem,6vw,4rem); line-height:1.04}
.dek{max-width:62ch; color:var(--ink-dim); margin:18px 0 0; font-size:1.06rem}
.meta{
  display:flex; flex-wrap:wrap; gap:8px 28px; margin:26px 0 0;
  font-family:ui-monospace,'SF Mono',Menlo,monospace;
  font-size:12px; color:var(--ink-faint);
}
.meta b{color:var(--ink-dim); font-weight:400}

/* ── control bar ──────────────────────────────────── */
.bar{
  position:sticky; top:0; z-index:20;
  background:color-mix(in srgb, var(--ground) 88%, transparent);
  backdrop-filter:blur(14px);
  border-bottom:1px solid var(--rule);
}
.bar-in{
  max-width:1180px; margin:0 auto; padding:11px 24px;
  display:flex; align-items:center; gap:18px; flex-wrap:wrap;
}
.toggle{
  display:inline-flex; align-items:center; gap:10px; cursor:pointer;
  font-family:ui-monospace,'SF Mono',Menlo,monospace; font-size:12px;
  color:var(--ink-dim); user-select:none;
}
.toggle input{position:absolute; opacity:0; width:0; height:0}
.sw{
  width:38px; height:21px; border-radius:11px; flex:none;
  background:var(--sunk); border:1px solid var(--rule); position:relative;
  transition:background .18s, border-color .18s;
}
.sw::after{
  content:""; position:absolute; inset:3px auto 3px 3px; width:13px;
  border-radius:50%; background:var(--ink-faint); transition:transform .18s, background .18s;
}
.toggle input:checked + .sw{background:var(--ember); border-color:var(--ember)}
.toggle input:checked + .sw::after{transform:translateX(17px); background:var(--ground)}
.toggle input:focus-visible + .sw{outline:2px solid var(--ember); outline-offset:3px}
.bar-note{font-family:ui-monospace,'SF Mono',Menlo,monospace; font-size:11.5px; color:var(--ink-faint)}

/* ── plate rows ───────────────────────────────────── */
.row{padding:56px 0; border-bottom:1px solid var(--rule-soft)}
.row-head{display:flex; align-items:baseline; gap:18px}
.idx{
  font-size:12px; color:var(--gilt); flex:none; width:2ch;
  font-variant-numeric:tabular-nums; padding-top:6px;
}
.row-title{flex:1 1 auto; min-width:0}
.row-title h2{font-size:1.62rem}
.scene{margin:3px 0 0; font-size:12px; color:var(--ink-faint);
  font-family:ui-monospace,'SF Mono',Menlo,monospace; letter-spacing:.04em}
.state{
  flex:none; font-size:10.5px; letter-spacing:.1em; text-transform:uppercase;
  padding:4px 10px; border-radius:2px; border:1px solid currentColor;
}
.s-clean{color:var(--clean)}
.s-fork{color:var(--fork)}
.s-shipped{color:var(--ember)}
.s-derived{color:var(--derived)}

.anchor{
  margin:16px 0 0 calc(2ch + 18px); padding-left:14px;
  border-left:2px solid var(--gilt);
  font-size:14px; color:var(--ink-dim); max-width:70ch;
}

.plates{display:grid; gap:16px; margin:26px 0 0}
.plates.duo{grid-template-columns:1fr 1fr}
.plates.solo{grid-template-columns:1fr; max-width:860px}
@media (max-width:720px){ .plates.duo{grid-template-columns:1fr} }

.plate{margin:0}
.frame{
  display:block; width:100%; padding:0; border:1px solid var(--rule);
  background:var(--sunk); cursor:zoom-in; position:relative; overflow:hidden;
  box-shadow:var(--shadow); border-radius:2px;
}
.frame img{display:block; width:100%; height:auto; aspect-ratio:3/2; object-fit:cover}
.band{display:none}

/* the game's real display box: 1180x820, cover-cropped, dialogue band over it */
body.framed .frame img{aspect-ratio:1180/820}
body.framed .band{
  display:flex; align-items:center; justify-content:center;
  position:absolute; left:0; right:0; bottom:0; height:12%;
  background:linear-gradient(to top, rgb(6 4 8 / .96), rgb(6 4 8 / .82));
  border-top:1px solid rgb(198 161 94 / .22);
}
.band-copy{
  margin:0; color:#EDE4D6; font-size:clamp(.8rem,1.5vw,1.05rem); letter-spacing:.01em;
}
figcaption{
  display:flex; align-items:center; gap:10px;
  margin:9px 2px 0; font-size:11.5px; color:var(--ink-faint);
}
.pick{
  font-size:11px; font-weight:700; color:var(--ground); background:var(--gilt);
  width:19px; height:19px; display:grid; place-items:center; border-radius:2px; flex:none;
}

.read{margin:22px 0 0 calc(2ch + 18px); max-width:66ch}
.read p{margin:0}
.read b{color:var(--ink); font-weight:700}
.flaw{
  margin-top:12px !important; padding-left:14px;
  border-left:2px solid var(--rule); color:var(--ink-dim); font-size:15px;
}

/* ── calls ────────────────────────────────────────── */
.calls{padding:64px 0 40px}
.calls h2{font-size:1.9rem; margin-bottom:8px}
.call-grid{display:grid; gap:18px; grid-template-columns:1fr 1fr; margin-top:30px}
@media (max-width:820px){ .call-grid{grid-template-columns:1fr} }
.call{
  background:var(--raised); border:1px solid var(--rule);
  border-top:2px solid var(--ember); border-radius:2px; padding:24px 24px 26px;
}
.call h3{margin:0 0 10px; font-size:1.18rem; font-weight:600}
.call p{margin:0 0 12px; font-size:15.5px; color:var(--ink-dim)}
.call p:last-child{margin-bottom:0}
.call ol{margin:0; padding-left:1.25em; font-size:15.5px; color:var(--ink-dim)}
.call li{margin-bottom:7px}
.call li:last-child{margin-bottom:0}
.call b{color:var(--ink)}

.side{padding:0 0 72px}
.side h2{font-size:1.5rem; margin-bottom:18px}
.tbl-scroll{overflow-x:auto; -webkit-overflow-scrolling:touch}
table{border-collapse:collapse; width:100%; min-width:520px; font-size:14.5px}
th,td{text-align:left; padding:11px 14px; border-bottom:1px solid var(--rule-soft); vertical-align:top}
th{
  font-family:ui-monospace,'SF Mono',Menlo,monospace; font-size:11px;
  letter-spacing:.1em; text-transform:uppercase; color:var(--gilt);
  border-bottom:1px solid var(--rule);
}
td.num{font-family:ui-monospace,'SF Mono',Menlo,monospace; font-variant-numeric:tabular-nums;
  text-align:right; white-space:nowrap}
tr:last-child td{border-bottom:none}

.gates{
  display:flex; flex-wrap:wrap; gap:10px; margin:22px 0 0;
  font-family:ui-monospace,'SF Mono',Menlo,monospace; font-size:12px;
}
.gate{border:1px solid var(--rule); border-left:2px solid var(--clean);
  padding:7px 12px; color:var(--ink-dim); border-radius:2px}
.gate.skip{border-left-color:var(--ink-faint)}

footer{border-top:1px solid var(--rule); padding:30px 0 60px; color:var(--ink-faint);
  font-family:ui-monospace,'SF Mono',Menlo,monospace; font-size:11.5px}

/* ── lightbox ─────────────────────────────────────── */
#lb{
  position:fixed; inset:0; z-index:60; display:none;
  background:rgb(4 3 6 / .96); padding:24px; cursor:zoom-out;
}
#lb.on{display:grid; place-items:center}
#lb img{max-width:100%; max-height:88vh; border:1px solid var(--rule); border-radius:2px}
#lb .cap{
  position:absolute; left:0; right:0; bottom:20px; text-align:center;
  font-family:ui-monospace,'SF Mono',Menlo,monospace; font-size:12px; color:var(--ink-dim);
}
@media (prefers-reduced-motion:reduce){ *{transition:none !important; animation:none !important} }
</style>"""


BODY = """
<div class="wrap">
  <header class="mast">
    <p class="eyebrow">Glassvow · issue 310 · staging hybrid</p>
    <h1>The Nine Plates</h1>
    <p class="dek">Every candidate for the nine full-bleed plates, in the order the
    scenes play, with the picks marked. <b>All ten paths are filled</b> — James decided on
    2026&#8209;08&#8209;16, and <code>install_plates.py</code> wrote the winners into
    <code>assets/art/scenes/</code> at a 256-colour palette.</p>
    <div class="meta">
      <span><b>Rendered</b> 1536×1024</span>
      <span><b>Shown in</b> 1180×820</span>
      <span><b>Branch</b> work/310-scene-plates</span>
      <span><b>Bar</b> Route B cinematic</span>
    </div>
  </header>
</div>

<div class="bar">
  <div class="bar-in">
    <label class="toggle">
      <input type="checkbox" id="frameToggle">
      <span class="sw"></span>
      <span>Game frame</span>
    </label>
    <span class="bar-note">Crops each plate to the real display box and lays the dialogue band over it — <code>stretch/aspect="keep"</code> means every device sees this one frame.</span>
  </div>
</div>

<div class="wrap">
__ROWS__

  <section class="calls">
    <h2>Two rulings, and one correction</h2>
    <div class="call-grid">
      <div class="call">
        <h3>One figure in the opening, not two</h3>
        <p>The first candidates baked the seated hooded figure into the plate, on the
        reasoning that it is the L0 plant and would save beat ④ a second asset. But the
        <b>#283 Keeper overlays this same plate</b> for beat ②'s dialogue — so a baked
        figure means two bodies on screen at once.</p>
        <p><b>James ruled one.</b> C and D re-render the hall deserted, hearth step bare
        and composed as the seat; C shipped.</p>
        <p>The cost lands on the scene player, not the plate: 爐前仍坐着一個兜帽身影 is now
        the overlay's job in beat ④'s linger and in the every-departure ambient staging.
        It is no longer free.</p>
      </div>
      <div class="call">
        <h3>There was never a six-lobe problem</h3>
        <p>An earlier revision of this page reported that no round window in the set would
        count to six, and offered three ways to work around it — including restaging the
        Vigil hall. <b>That was wrong, and James caught it.</b></p>
        <p>Measured off 4× crops of the window region: <code>opening-hearth</code> a, b, c
        and d are all <b>six</b>; so is <code>act4-node1-b</code>. Only the finale's small
        background rose is five, at a size where the tracery barely resolves.</p>
        <p>The lesson is not about the generator. A count asserted from a downscaled view
        is an inference wearing the grammar of a measurement — the crops cost one command,
        and would have kept the wrong number out of three documents.</p>
      </div>
    </div>
  </section>

  <section class="side">
    <h2>Fixed on the way</h2>
    <div class="tbl-scroll">
      <table>
        <thead><tr><th>What</th><th>Why it mattered</th></tr></thead>
        <tbody>
          <tr>
            <td><code>content/scenes.json</code><br>tenth path</td>
            <td><code>act4-entry.png</code> appears in the scene data and in no line of the
            bill. It now points at <code>act4-node1.png</code> — node 1's motif pool 門檻′
            <i>is</i> the entry image, and the entry's <code>push-in</code> running into
            node 1's <code>hold</code> reads as one camera move, not a repeat.</td>
          </tr>
          <tr>
            <td><code>docs/.gdignore</code></td>
            <td><code>check_imports.sh</code> imports every image under <code>docs/</code>.
            The run for this commit generated <code>.import</code> files for four
            decision-record directories that had none — those images were entering the
            import pipeline and the export payload. Nothing loads
            <code>res://docs/…</code> at runtime.</td>
          </tr>
        </tbody>
      </table>
    </div>

    <h2 style="margin-top:46px">Payload, measured</h2>
    <div class="tbl-scroll">
      <table>
        <thead><tr><th>Plate</th><th class="num">RGB</th><th class="num">256-colour</th><th class="num">Cut</th></tr></thead>
        <tbody>
          <tr><td><code>act4-node5-a</code></td><td class="num">2.90 MB</td><td class="num">1.05 MB</td><td class="num">64%</td></tr>
          <tr><td><code>opening-hearth-a</code></td><td class="num">2.44 MB</td><td class="num">1.24 MB</td><td class="num">49%</td></tr>
        </tbody>
      </table>
    </div>
    <p style="max-width:66ch; color:var(--ink-dim); font-size:15.5px">Inspected at full
    size: the sunset gradient and cloud sea in <code>act4-node5</code> survive with no
    visible banding, and that is the hardest case in the set. Nine plates go from ~24 MB
    to ~10 MB on a payload already at 135 MB. Candidates stay lossless — quantize only on
    the way into <code>assets/</code>, so a re-crop never compounds.</p>

    <div class="gates">
      <span class="gate">check_imports.sh — OK</span>
      <span class="gate">check_anchors.py — OK</span>
      <span class="gate">run_all.gd — PASS (38 tests)</span>
      <span class="gate skip">check_web_anchors.py — not run, no benchmark citation touched</span>
    </div>
  </section>
</div>

<div class="wrap"><footer>
  Decision material for issue 310. Full-resolution candidates live in
  <code>docs/design/2026-08-16-scene-plates/candidates/</code>; prompts and the frame
  contract are in that directory's <code>README.md</code>. Rebuild this page with
  <code>build_review_page.py</code>.
</footer></div>

<div id="lb" role="dialog" aria-modal="true" aria-label="Plate at full size">
  <img alt=""><p class="cap"></p>
</div>

<script>
(function(){
  var t = document.getElementById('frameToggle');
  t.addEventListener('change', function(){
    document.body.classList.toggle('framed', t.checked);
  });

  var lb = document.getElementById('lb'),
      lbImg = lb.querySelector('img'),
      lbCap = lb.querySelector('.cap'),
      last = null;

  document.querySelectorAll('.frame').forEach(function(btn){
    btn.addEventListener('click', function(){
      last = btn;
      lbImg.src = btn.querySelector('img').src;
      lbImg.alt = btn.dataset.full;
      lbCap.textContent = btn.dataset.full + '.png — 1536x1024';
      lb.classList.add('on');
    });
  });

  function close(){
    lb.classList.remove('on');
    lbImg.removeAttribute('src');
    if (last) last.focus();
  }
  lb.addEventListener('click', close);
  document.addEventListener('keydown', function(e){
    if (e.key === 'Escape' && lb.classList.contains('on')) close();
  });
})();
</script>"""


def build() -> None:
    rows = "\n".join(row(p) for p in PLATES)
    OUT.write_text(HEAD + BODY.replace("__ROWS__", rows), encoding="utf-8")
    print(f"{OUT}  {OUT.stat().st_size/1e6:.2f} MB")


if __name__ == "__main__":
    build()
