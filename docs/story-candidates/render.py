#!/usr/bin/env python3
"""Render a story content JSON into a self-contained bilingual page.

Every string on the page exists as an {en, zh} pair; the toggle flips
html[data-lang] and CSS hides the inactive half. Images are inlined as JPEG
data URIs because the artifact CSP blocks every external host.
"""
import base64, html, io, json, os, subprocess, sys
from PIL import Image

SP = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(SP, '..', '..'))
GROUND = (7, 9, 12)  # --ground, used to flatten alpha

# ---------------------------------------------------------------- images

def _load(path):
    if path.lower().endswith('.svg'):
        png = '/tmp/_svg_render.png'
        subprocess.run(['magick', '-background', 'none', '-density', '300',
                        path, '-resize', '1200x', png], check=True)
        path = png
    return Image.open(path)


def encode(path, maxw=1200, quality=82):
    im = _load(path)
    if im.mode in ('RGBA', 'LA', 'P'):
        im = im.convert('RGBA')
        bg = Image.new('RGB', im.size, GROUND)
        bg.paste(im, mask=im.split()[-1])
        im = bg
    else:
        im = im.convert('RGB')
    if im.width > maxw:
        im = im.resize((maxw, round(im.height * maxw / im.width)), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, 'JPEG', quality=quality, optimize=True, progressive=True)
    return 'data:image/jpeg;base64,' + base64.b64encode(buf.getvalue()).decode()


def resolve(img, no):
    """Return a data URI for an image entry, or None if the file is missing.

    `asset` entries are real game art, read from the repo at its current state —
    so a page re-rendered later shows whatever the game ships today, which is the
    point of grounding these stories in real assets. `generate` entries are the
    illustrations made for this deliverable and live beside this script.
    """
    if img['source'] == 'asset':
        p = os.path.join(REPO, img['path'])
        return encode(p) if os.path.exists(p) else None
    p = os.path.join(SP, 'img', 'story-%02d-%s.jpg' % (no, img['id']))
    return encode(p) if os.path.exists(p) else None

# ---------------------------------------------------------------- html

def e(s):
    return html.escape(str(s or ''), quote=False)


def pair(p, tag='p', cls=''):
    """One {en,zh} pair as two sibling elements, one per language."""
    c = (cls + ' ').lstrip()
    return ('<%s class="%sen" lang="en">%s</%s><%s class="%szh" lang="zh-Hant">%s</%s>'
            % (tag, c, e(p.get('en')), tag, tag, c, e(p.get('zh')), tag))


UI = {
    'story':   {'en': 'The story',   'zh': '故事'},
    'craft':   {'en': 'How it works','zh': '拆解'},
    'spoil':   {'en': 'Everything below discusses the ending.',
                'zh': '以下全部涉及結局。'},
    'reread':  {'en': 'Lines that change',      'zh': '會變樣嘅句'},
    'shipped': {'en': 'Already in the game',    'zh': '已經喺遊戲入面'},
    'before':  {'en': 'First reading',          'zh': '初讀'},
    'after':   {'en': 'Second reading',         'zh': '再讀'},
    'twist':   {'en': 'The turn',               'zh': '反轉'},
    'act4':    {'en': 'Act IV',                 'zh': '第四幕'},
    'defeat':  {'en': 'When you lose',          'zh': '輸咗之後'},
    'risks':   {'en': 'What could go wrong',    'zh': '風險'},
    'placeholder': {'en': 'illustration pending', 'zh': '插圖未生成'},
    # The twist-family label names the KIND of turn coming ("the benefactor is
    # the architect"), so it cannot sit in the header above the title. It is a
    # reviewer's index, and it belongs on the far side of the seam.
    'family': {'en': 'Twist family', 'zh': '反轉家族'},
}


def figure(img, uri, cap, no):
    # An image that could not be generated is dropped, not stubbed: a grey box
    # reads as a broken page, whereas the surrounding art carries the section
    # perfectly well without it.
    if not uri:
        return ''
    media = ('<img src="%s" alt="%s" loading="lazy">'
             % (uri, e(img.get('alt', {}).get('en', ''))))
    out = '<figure class="pane"><div class="glass">%s</div>' % media
    if cap and (cap.get('en') or cap.get('zh')):
        out += '<figcaption>%s</figcaption>' % pair(cap, 'span')
    return out + '</figure>'


ACT_TINT = ['t1', 't2', 't3']


def render(d):
    no = d['no']
    imgs = {i['id']: i for i in d['images']}
    uris = {i['id']: resolve(i, no) for i in d['images']}

    body = []
    act_i = -1
    for b in d['story']:
        t = b.get('t')
        if t == 'act':
            act_i += 1
            body.append('<div class="act %s"><span class="came"></span>%s'
                        '<span class="came"></span></div>'
                        % (ACT_TINT[act_i % 3], pair(b, 'h2')))
        elif t == 'art':
            im = imgs.get(b.get('img'))
            if im:
                body.append(figure(im, uris.get(b['img']), b, no))
        elif t == 'prose':
            body.append(pair(b, 'p'))
        elif t == 'line':
            body.append('<blockquote class="said">%s%s</blockquote>' % (
                pair({'en': b.get('sp_en'), 'zh': b.get('sp_zh')}, 'cite'),
                pair(b, 'p')))
        elif t == 'screen':
            body.append('<div class="screen">%s</div>' % pair(b, 'p'))

    craft = []
    for c in d.get('craft', []):
        craft.append('<section class="note">%s%s</section>' % (
            pair(c['h'], 'h3'),
            ''.join(pair(x, 'p') for x in c.get('body', []))))

    rows = []
    for r in d.get('rereadings', []):
        rows.append(
            '<div class="rr"><p class="quote">%s</p>'
            '<div class="rr-pair"><div><span class="lbl">%s</span>%s</div>'
            '<div><span class="lbl">%s</span>%s</div></div></div>'
            % (e(r['line']),
               pair(UI['before'], 'span'), pair(r['before'], 'p'),
               pair(UI['after'], 'span'), pair(r['after'], 'p')))

    m = dict(d.get('meta', {}), family=d['family'])
    cards = ''.join(
        '<div class="card"><span class="lbl">%s</span>%s</div>'
        % (pair(UI[k], 'span'), pair(m[k], 'p'))
        for k in ('family', 'twist', 'act4', 'defeat', 'risks') if m.get(k))

    poster = uris.get(d.get('poster'))
    hero = ('<div class="glass hero-glass"><img src="%s" alt=""></div>' % poster
            ) if poster else ''

    return TEMPLATE % {
        'title': e(d['title']['en']),
        'family': pair({'en': 'Glassvow · %d of 15' % no,
                        'zh': 'Glassvow · 第 %d 個 · 共 15' % no},
                       'span', 'eyebrow'),
        'h1': pair(d['title'], 'h1'),
        'hook': pair(d['hook'], 'p', 'hook'),
        'hero': hero,
        'story_lbl': pair(UI['story'], 'span', 'lbl'),
        'craft_lbl': pair(UI['craft'], 'span', 'lbl'),
        'spoil': pair(UI['spoil'], 'p', 'warn'),
        'body': '\n'.join(body),
        'craft': '\n'.join(craft),
        'reread_lbl': pair(UI['reread'], 'h3'),
        'shipped_lbl': pair(UI['shipped'], 'span', 'lbl'),
        'rows': '\n'.join(rows),
        'cards': cards,
        'no': no,
    }


TEMPLATE = """<title>%(title)s</title>
<style>
:root{
  --ground:#07090C; --panel:#0E1118; --raise:#141822;
  --came:#262A34; --came-lit:#3A4050;
  --ink:#DDD8CD; --ink-dim:#8A8B93; --ink-faint:#5C5E68;
  --ember:#FF9A4D; --gold:#C9A227;
  --t1:#7DDB8F; --t2:#5FD6E8; --t3:#C99AFF;
  --serif:"Iowan Old Style","Palatino Linotype",Palatino,"Hoefler Text",Georgia,serif;
  --serif-zh:"Songti TC","Songti SC","Source Han Serif HC","Noto Serif CJK HK",serif;
  --sans:"Avenir Next","Segoe UI",system-ui,sans-serif;
  --sans-zh:"PingFang HK","PingFang TC","Noto Sans CJK HK",sans-serif;
  --measure:34rem;
}
*{box-sizing:border-box}
html{-webkit-text-size-adjust:100%%}
body{margin:0;background:var(--ground);color:var(--ink);
  font-family:var(--serif);font-size:17px;line-height:1.72;
  overflow-x:hidden;padding-bottom:6rem}
[data-lang="en"] .zh,[data-lang="zh"] .en{display:none}
.zh{font-family:var(--serif-zh);line-height:1.9;letter-spacing:.01em}
h1,h2,h3{text-wrap:balance;font-weight:600;margin:0}
p{margin:0}
img{max-width:100%%;display:block}

/* ---- language toggle ---- */
.lang{position:fixed;top:1rem;right:1rem;z-index:20;display:flex;
  border:1px solid var(--came);border-radius:2px;overflow:hidden;
  background:rgba(7,9,12,.86);backdrop-filter:blur(8px);font-family:var(--sans)}
.lang button{appearance:none;background:none;border:0;cursor:pointer;
  color:var(--ink-faint);font:inherit;font-size:.72rem;letter-spacing:.14em;
  padding:.5rem .72rem;transition:color .2s,background .2s}
.lang button:hover{color:var(--ink)}
.lang button:focus-visible{outline:2px solid var(--ember);outline-offset:-2px}
[data-lang="en"] .lang [data-l="en"],[data-lang="zh"] .lang [data-l="zh"]{
  color:var(--ground);background:var(--ink)}

/* ---- shell ---- */
.wrap{max-width:var(--measure);margin:0 auto;padding:0 1.25rem}
header{padding:5.5rem 0 2rem;text-align:center}
.eyebrow{display:block;font-family:var(--sans);font-size:.68rem;
  letter-spacing:.22em;text-transform:uppercase;color:var(--ink-faint);
  margin-bottom:1.4rem}
.eyebrow.zh{font-family:var(--sans-zh);letter-spacing:.18em}
h1{font-size:clamp(2.4rem,7vw,3.6rem);line-height:1.06;letter-spacing:-.02em}
h1.zh{letter-spacing:.04em;font-size:clamp(2.1rem,6.4vw,3.1rem)}
.hook{margin-top:1.5rem;color:var(--ink-dim);font-size:1.06rem;font-style:italic}
.hook.zh{font-style:normal}

/* ---- the pane: every image is a piece of leaded glass ---- */
.glass{position:relative;border:1px solid var(--came-lit);
  clip-path:polygon(14px 0,100%% 0,100%% calc(100%% - 14px),
    calc(100%% - 14px) 100%%,0 100%%,0 14px);
  background:#04050700}
.glass::after{content:"";position:absolute;inset:0;pointer-events:none;
  box-shadow:inset 0 0 40px rgba(255,154,77,.07),inset 0 0 1px rgba(201,162,39,.5)}
.hero-glass{margin:2.5rem 0 0}
/* Centred with margins, never with transform: the entrance animation below
   owns `transform`, and `.pane.seen{transform:none}` (0,2,0) outranks
   `figure.pane` (0,1,1), so a transform-based centring silently died the
   moment an image scrolled into view. Left margin = half the column minus
   half the figure, which is exactly centre at any width. */
figure.pane{margin-block:2.8rem;width:min(52rem,calc(100vw - 2.5rem));
  margin-inline:calc(50%% - min(26rem,50vw - 1.25rem))}
figcaption{margin-top:.7rem;font-family:var(--sans);font-size:.78rem;
  line-height:1.6;color:var(--ink-faint);text-align:center}
figcaption .zh{font-family:var(--sans-zh)}
.pending{aspect-ratio:16/9;display:flex;flex-direction:column;gap:.5rem;
  align-items:center;justify-content:center;background:var(--panel);
  color:var(--ink-faint);font-family:var(--sans);font-size:.75rem;padding:2rem;
  text-align:center}
.pending span{max-width:34rem;opacity:.5}

/* ---- story ---- */
.story{padding-top:1rem}
.story>p{margin-top:1.35rem}
.story>p:first-of-type::first-letter{float:left;font-size:3.9rem;line-height:.86;
  padding:.16em .12em 0 0;color:var(--ember)}
[data-lang="zh"] .story>p:first-of-type::first-letter{float:none;font-size:inherit;
  padding:0;color:inherit}
.act{display:flex;align-items:center;gap:1.1rem;margin:3.6rem 0 1.9rem}
.act h2{font-family:var(--sans);font-size:.72rem;letter-spacing:.2em;
  text-transform:uppercase;color:var(--ink-dim);white-space:nowrap}
.act h2.zh{font-family:var(--sans-zh);letter-spacing:.16em}
.came{flex:1;height:1px;background:var(--came)}
.act.t1 .came{background:linear-gradient(90deg,transparent,#7DDB8F55,transparent)}
.act.t2 .came{background:linear-gradient(90deg,transparent,#5FD6E855,transparent)}
.act.t3 .came{background:linear-gradient(90deg,transparent,#C99AFF55,transparent)}
.said{margin:1.7rem 0;padding-left:1.1rem;border-left:1px solid var(--came-lit)}
.said cite{display:block;font-family:var(--sans);font-style:normal;
  font-size:.68rem;letter-spacing:.16em;text-transform:uppercase;
  color:var(--ember);margin-bottom:.4rem}
.said cite.zh{font-family:var(--sans-zh);letter-spacing:.1em;text-transform:none}
.said p{font-size:1.06rem}
.screen{margin:1.9rem 0;padding:1.15rem 1.3rem;background:var(--panel);
  border:1px solid var(--came);font-family:var(--sans);font-size:.9rem;
  line-height:1.7;color:var(--ink-dim);text-align:center}
.screen .zh{font-family:var(--sans-zh)}

/* ---- the seam: story ends, analysis begins ---- */
.seam{margin-top:5rem;border-top:1px solid var(--came-lit);
  background:var(--panel);padding:3.4rem 0 5rem}
.seam .lbl,.card .lbl,.rr .lbl{display:block;font-family:var(--sans);
  font-size:.66rem;letter-spacing:.2em;text-transform:uppercase;
  color:var(--ink-faint)}
.seam .lbl.zh,.card .lbl.zh,.rr .lbl.zh{font-family:var(--sans-zh);letter-spacing:.14em}
.seam .warn{margin-top:.6rem;color:var(--ember);font-family:var(--sans);
  font-size:.8rem;letter-spacing:.02em}
.seam .warn.zh{font-family:var(--sans-zh)}
.seam,.seam .zh{font-family:var(--sans)}
.seam .zh{font-family:var(--sans-zh)}
.note{margin-top:2.6rem}
.note h3{font-size:1.15rem;letter-spacing:-.01em;margin-bottom:.7rem;color:var(--ink)}
.note p{margin-top:.9rem;font-size:.95rem;line-height:1.75;color:var(--ink-dim)}
.rr{margin-top:1.9rem;padding:1.15rem 1.25rem;background:var(--raise);
  border-left:2px solid var(--gold)}
.rr .quote{font-family:var(--serif);font-size:1rem;color:var(--ink);
  font-style:italic;margin-bottom:1rem}
.rr-pair{display:grid;gap:1rem}
@media(min-width:36rem){.rr-pair{grid-template-columns:1fr 1fr;gap:1.4rem}}
.rr-pair p{margin-top:.35rem;font-size:.87rem;line-height:1.7;color:var(--ink-dim)}
.cards{display:grid;gap:1rem;margin-top:2.6rem}
.card{padding:1.1rem 1.2rem;background:var(--raise);border:1px solid var(--came)}
.card p{margin-top:.5rem;font-size:.9rem;line-height:1.72;color:var(--ink-dim)}
footer{text-align:center;padding-top:3rem;font-family:var(--sans);
  font-size:.7rem;letter-spacing:.18em;color:var(--ink-faint)}

@media(prefers-reduced-motion:no-preference){
  .pane{opacity:0;transform:translateY(14px);transition:opacity .7s,transform .7s}
  .pane.seen{opacity:1;transform:none}
}
</style>

<div class="lang" role="group">
  <button data-l="en" type="button">EN</button>
  <button data-l="zh" type="button">中文</button>
</div>

<header class="wrap">
  %(family)s
  %(h1)s
  %(hook)s
  %(hero)s
</header>

<main class="wrap story">
%(body)s
</main>

<div class="seam">
  <div class="wrap">
    %(craft_lbl)s
    %(spoil)s
    %(craft)s
    %(reread_lbl)s
    %(rows)s
    <div class="cards">%(cards)s</div>
    <footer>GLASSVOW &middot; %(no)s / 15</footer>
  </div>
</div>

<script>
(function(){
  var r=document.documentElement;
  function set(l){r.setAttribute('data-lang',l);try{localStorage.setItem('gv-lang',l)}catch(e){}}
  set((function(){try{return localStorage.getItem('gv-lang')}catch(e){return null}})()||'en');
  document.querySelectorAll('.lang button').forEach(function(b){
    b.addEventListener('click',function(){set(b.dataset.l)});
  });
  if(matchMedia('(prefers-reduced-motion: no-preference)').matches){
    var io=new IntersectionObserver(function(es){
      es.forEach(function(x){if(x.isIntersecting){x.target.classList.add('seen');io.unobserve(x.target)}})
    },{rootMargin:'0px 0px -12%% 0px'});
    document.querySelectorAll('.pane').forEach(function(f){io.observe(f)});
  }else{document.querySelectorAll('.pane').forEach(function(f){f.classList.add('seen')})}
})();
</script>
"""

if __name__ == '__main__':
    for arg in sys.argv[1:]:
        d = json.load(open(arg))
        out = os.path.join(SP, 'pages', 'story-%02d.html' % d['no'])
        os.makedirs(os.path.dirname(out), exist_ok=True)
        open(out, 'w').write(render(d))
        print('%s  %.1f KB' % (out, os.path.getsize(out) / 1024))
