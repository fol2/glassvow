#!/usr/bin/env python3
"""Render the index page: fifteen leaded panes, one per story, spoiler-free."""
import glob, json, os
from render import encode, pair, e, resolve

SP = os.path.dirname(os.path.abspath(__file__))

UI = {
    'kicker': {'en': 'Glassvow · story candidates for ticket #175',
               'zh': 'Glassvow · #175 故事候選'},
    'lede': {'en': 'Fifteen ways the same six shards could turn out to mean '
                   'something else. Each page plays its story through as a '
                   'player would meet it, then explains itself afterwards. '
                   'Nothing on this page gives an ending away.',
             'zh': '同樣六塊碎片,十五種到頭來另有所指嘅可能。每一頁都先照玩家會遇到嘅次序'
                   '將故事行一次,講完先解釋。呢一頁唔會透露任何結局。'},
    'read': {'en': 'Read', 'zh': '讀'},
}


def render(urls):
    cards = []
    for path in sorted(glob.glob(SP + '/content/story-*.json')):
        d = json.load(open(path))
        if d['no'] == 99 or str(d['no']) not in urls:
            continue
        uri = resolve({'id': d['poster'], **next(
            i for i in d['images'] if i['id'] == d['poster'])}, d['no'])
        media = ('<img src="%s" alt="" loading="lazy">' % uri) if uri else \
                '<div class="blank"></div>'
        cards.append(
            # No twist-family label here either — it names the kind of turn.
            '<a class="card" href="%s"><span class="no">%02d</span>'
            '<div class="glass">%s</div><div class="txt">%s%s</div></a>'
            % (e(urls[str(d['no'])]), d['no'], media,
               pair(d['title'], 'h2'),
               pair(d['hook'], 'p')))
    # Token replacement rather than %-formatting: this template is mostly CSS,
    # and CSS is full of bare % signs that %-formatting would choke on.
    out = TEMPLATE
    for k, v in (('kicker', pair(UI['kicker'], 'p', 'kicker')),
                 ('lede', pair(UI['lede'], 'p', 'lede')),
                 ('cards', '\n'.join(cards))):
        out = out.replace('%(' + k + ')s', v)
    return out


TEMPLATE = """<title>Fifteen Vows</title>
<style>
:root{
  --ground:#07090C;--panel:#0E1118;--came:#262A34;--came-lit:#3A4050;
  --ink:#DDD8CD;--ink-dim:#8A8B93;--ink-faint:#5C5E68;--ember:#FF9A4D;--gold:#C9A227;
  --serif:"Iowan Old Style","Palatino Linotype",Palatino,"Hoefler Text",Georgia,serif;
  --serif-zh:"Songti TC","Songti SC","Noto Serif CJK HK",serif;
  --sans:"Avenir Next","Segoe UI",system-ui,sans-serif;
  --sans-zh:"PingFang HK","PingFang TC","Noto Sans CJK HK",sans-serif;
}
*{box-sizing:border-box}
body{margin:0;background:var(--ground);color:var(--ink);font-family:var(--serif);
  font-size:17px;line-height:1.7;padding:0 1.25rem 6rem}
[data-lang="en"] .zh,[data-lang="zh"] .en{display:none}
.zh{font-family:var(--serif-zh);line-height:1.9}
img{max-width:100%;display:block}
h1,h2{margin:0;font-weight:600;text-wrap:balance}
p{margin:0}
.lang{position:fixed;top:1rem;right:1rem;z-index:20;display:flex;
  border:1px solid var(--came);background:rgba(7,9,12,.86);backdrop-filter:blur(8px);
  font-family:var(--sans)}
.lang button{appearance:none;background:none;border:0;cursor:pointer;
  color:var(--ink-faint);font:inherit;font-size:.72rem;letter-spacing:.14em;
  padding:.5rem .72rem}
.lang button:focus-visible{outline:2px solid var(--ember);outline-offset:-2px}
[data-lang="en"] .lang [data-l="en"],[data-lang="zh"] .lang [data-l="zh"]{
  color:var(--ground);background:var(--ink)}
header{max-width:38rem;margin:0 auto;padding:5.5rem 0 3.5rem}
.kicker{font-family:var(--sans);font-size:.68rem;letter-spacing:.22em;
  text-transform:uppercase;color:var(--ink-faint);margin-bottom:1.3rem}
.kicker.zh{font-family:var(--sans-zh);letter-spacing:.16em}
h1{font-size:clamp(2.6rem,8vw,4.2rem);line-height:1.02;letter-spacing:-.025em}
.lede{margin-top:1.6rem;color:var(--ink-dim);font-size:1.02rem}
.grid{max-width:74rem;margin:0 auto;display:grid;gap:2.5rem 2rem;
  grid-template-columns:repeat(auto-fill,minmax(19rem,1fr))}
.card{position:relative;text-decoration:none;color:inherit;display:block}
.no{position:absolute;top:-.6rem;left:-.1rem;z-index:2;font-family:var(--sans);
  font-size:.66rem;letter-spacing:.16em;color:var(--ink-faint);
  font-variant-numeric:tabular-nums}
.glass{position:relative;border:1px solid var(--came-lit);
  clip-path:polygon(12px 0,100% 0,100% calc(100% - 12px),calc(100% - 12px) 100%,0 100%,0 12px);
  transition:border-color .3s}
.glass::after{content:"";position:absolute;inset:0;
  box-shadow:inset 0 0 34px rgba(255,154,77,.06),inset 0 0 1px rgba(201,162,39,.45)}
.card:hover .glass,.card:focus-visible .glass{border-color:var(--ember)}
.card:focus-visible{outline:none}
.blank{aspect-ratio:16/9;background:var(--panel)}
.txt{padding-top:1rem}
.fam{display:block;font-family:var(--sans);font-size:.62rem;letter-spacing:.2em;
  text-transform:uppercase;color:var(--ember);margin-bottom:.5rem;opacity:.75}
.fam.zh{font-family:var(--sans-zh);letter-spacing:.12em;text-transform:none}
.card h2{font-size:1.35rem;letter-spacing:-.01em}
.card h2.zh{letter-spacing:.03em;font-size:1.25rem}
.txt p{margin-top:.55rem;font-size:.9rem;line-height:1.65;color:var(--ink-dim)}
.txt p.zh{font-size:.88rem}
</style>

<div class="lang" role="group">
  <button data-l="en" type="button">EN</button>
  <button data-l="zh" type="button">中文</button>
</div>

<header>
  %(kicker)s
  <h1 class="en" lang="en">Fifteen Vows</h1>
  <h1 class="zh" lang="zh-Hant">十五個誓</h1>
  %(lede)s
</header>

<div class="grid">
%(cards)s
</div>

<script>
(function(){
  var r=document.documentElement;
  function set(l){r.setAttribute('data-lang',l);try{localStorage.setItem('gv-lang',l)}catch(e){}}
  set((function(){try{return localStorage.getItem('gv-lang')}catch(e){return null}})()||'en');
  document.querySelectorAll('.lang button').forEach(function(b){
    b.addEventListener('click',function(){set(b.dataset.l)});
  });
})();
</script>
"""

if __name__ == '__main__':
    urls = json.load(open(SP + '/urls.json'))
    out = SP + '/pages/index.html'
    open(out, 'w').write(render(urls))
    print(out, '%.1f KB' % (os.path.getsize(out) / 1024))
