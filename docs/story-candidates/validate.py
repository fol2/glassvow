#!/usr/bin/env python3
"""Gate the writers' output. A story that fails here would render as a page
where switching language silently drops content, or as a broken <img>."""
import glob, json, os, subprocess, sys

SP = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(SP, '..', '..'))
ASSETS = set(subprocess.run(['git', '-C', REPO, 'ls-files', 'assets/art'],
                            capture_output=True, text=True).stdout.split())

BLOCK_KEYS = {'act', 'prose', 'screen', 'art', 'line'}


def walk_pairs(node, path, bad):
    """Every dict holding an 'en' must hold a non-empty 'zh', and vice versa."""
    if isinstance(node, dict):
        has = {k for k in ('en', 'zh') if k in node}
        if has:
            for k in ('en', 'zh'):
                if not str(node.get(k) or '').strip():
                    bad.append('%s missing/empty %s' % (path, k))
        if 'sp_en' in node or 'sp_zh' in node:
            for k in ('sp_en', 'sp_zh'):
                if not str(node.get(k) or '').strip():
                    bad.append('%s missing/empty %s' % (path, k))
        for k, v in node.items():
            walk_pairs(v, path + '.' + k, bad)
    elif isinstance(node, list):
        for i, v in enumerate(node):
            walk_pairs(v, '%s[%d]' % (path, i), bad)


def check(path):
    d = json.load(open(path))
    bad = []
    walk_pairs(d, os.path.basename(path), bad)

    ids = {i['id'] for i in d['images']}
    for i, b in enumerate(d['story']):
        if b.get('t') not in BLOCK_KEYS:
            bad.append('story[%d] unknown type %r' % (i, b.get('t')))
        if b.get('t') == 'art' and b.get('img') not in ids:
            bad.append('story[%d] art references unknown image %r' % (i, b.get('img')))
    if d.get('poster') not in ids:
        bad.append('poster %r not in images' % d.get('poster'))

    gen = [i for i in d['images'] if i.get('source') == 'generate']
    ast = [i for i in d['images'] if i.get('source') == 'asset']
    for i in ast:
        if i['path'] not in ASSETS:
            bad.append('asset not in repo: %s' % i['path'])
    for i in gen:
        if not str(i.get('subject') or '').strip():
            bad.append('generate image %s has no subject' % i['id'])

    words = sum(len(b.get('en', '').split()) for b in d['story'])
    return d['no'], len(d['story']), len(gen), len(ast), words, bad


rows = []
for p in sorted(glob.glob(SP + '/content/story-*.json')):
    if p.endswith('story-99.json'):
        continue
    try:
        rows.append(check(p))
    except Exception as ex:
        print('!! %s : %s' % (os.path.basename(p), ex))

print('%-4s %6s %5s %6s %7s  %s' % ('no', 'blocks', 'gen', 'asset', 'words', 'problems'))
fails = 0
for no, nb, ng, na, w, bad in rows:
    print('%-4d %6d %5d %6d %7d  %s' % (no, nb, ng, na, w, '; '.join(bad) or 'ok'))
    fails += len(bad)
print('\n%d stories, %d problems' % (len(rows), fails))
sys.exit(1 if fails else 0)
