"""Reconstruct selected Bloodfire bytes and assemble isolated native projects.
Historical Python is parsed, never executed. No historical outcomes are read.
"""
from __future__ import annotations
import ast
import copy
import hashlib
import io
import itertools
import json
import shutil
import tarfile
from pathlib import Path

CONTENT = 'a0d608a5142d2e3aab799cdf33d3163922b402c2aaf2a895e46e096399b56cf1'
COMBAT = '3adb0e063a536bf249d3b5d9524427facf1398304206da59d97594d3fff246e8'
SELECTED = '765d9efd639fe3507d92ea2f7515b3ed92afd15166925a6db2f8934e3a777f07'
HARNESS = '0e963a6dfadb87912f9b1074b78d8629bbad2a47'
RECIPE = '9418a3419c4feecae84360a9ea4068b60157c239d0359bb265939d3c579cdf97'
ROOT = Path('research/p9-six-route/ash-inheritance-20260909')
HERE = Path(__file__).resolve().parent


def sha(data):
    return hashlib.sha256(data).hexdigest()


def blob(data):
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()


def require(ok, reason):
    if not ok:
        raise ValueError(reason)


def dump(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def once(text, old, new):
    require(text.count(old) == 1, 'PATCH_ANCHOR:' + old[:50])
    return text.replace(old, new, 1)


def selected_content(repo, out):
    raw = (repo / ROOT / 'binding-1/inputs/harness.tar.gz').read_bytes()
    require(blob(raw) == HARNESS, 'HARNESS_IDENTITY')
    with tarfile.open(fileobj=io.BytesIO(raw), mode='r:gz') as archive:
        original = archive.extractfile('source/content/full-content.json').read()
        recipe = archive.extractfile('post_v38_factorial.py').read()
    require(sha(recipe) == RECIPE, 'RECIPE_IDENTITY')
    tree = ast.parse(recipe)
    function = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == '_set_payoffs')
    history = json.loads(original)
    selected = copy.deepcopy(history)
    card = selected['cards']['executioner']
    card['rarity'] = 'uncommon'
    card['effects'][0].pop('scorelineBonus', None)
    card['up']['effects'][0].pop('scorelineBonus', None)
    card['text'] = "Deal @8@ damage. Cracked enemies take 6 more. Duskblade: consume Scoreline to complete the enemy's remaining Facets."
    card['up']['text'] = "Deal @11@ damage. Cracked enemies take 8 more. Duskblade: consume Scoreline to complete the enemy's remaining Facets."
    card = selected['cards']['guardedStrike']
    card['effects'][0]['reflection'] = 2
    card['up']['effects'][0]['reflection'] = 2
    card['text'] = 'Deal @5@ damage. Gain #4# Ward. Duskblade: consume Afterimage to deal damage equal to twice your current Ward.'
    card['up']['text'] = 'Deal @7@ damage. Gain #6# Ward. Duskblade: consume Afterimage to deal damage equal to twice your current Ward.'
    matches = []
    for sort, ascii_, indent, newline, compact in itertools.product(
            (True, False), (True, False), (None, 2), (False, True), (False, True)):
        data = (json.dumps(selected, sort_keys=sort, ensure_ascii=ascii_, indent=indent,
                           separators=(',', ':') if compact else None) + ('\n' if newline else '')).encode()
        if sha(data) == SELECTED:
            matches.append(data)
    require(matches and len(set(matches)) == 1, 'SELECTED_CONTENT_NOT_RECONSTRUCTED')
    for name in ('bloodRite', 'leechBlade'):
        require(history['cards'][name] == selected['cards'][name], 'SELECTED_ROLE_CHANGED')
    require(history['statuses']['bloodfire'] == selected['statuses']['bloodfire'], 'SELECTED_STATUS_CHANGED')
    out.mkdir(parents=True, exist_ok=False)
    (out / 'SELECTED-HISTORICAL-CONTENT.json').write_bytes(matches[0])
    projection = {'selected_content_sha256': SELECTED, 'recipe_sha256': RECIPE,
                  'cards': {k: selected['cards'][k] for k in ('bloodRite', 'leechBlade')},
                  'status': selected['statuses']['bloodfire']}
    dump(out / 'SELECTED-PROJECTION.json', projection)
    lines = recipe.decode().splitlines(keepends=True)
    (out / 'EXACT-CONSTRUCTOR.txt').write_text(''.join(lines[function.lineno - 1:function.end_lineno]))
    dump(out / 'BINDING.json', {'selected_sha256': sha(matches[0]), 'selected_bytes': len(matches[0]),
                               'bloodfire_projection_unchanged_from_harness': True,
                               'historical_python_executed': False, 'historical_outcomes_carried': False})
    return projection


def candidate_content(data, projection):
    require(sha(data) == CONTENT, 'BASE_CONTENT')
    current = json.loads(data)
    old = copy.deepcopy(current)
    require(projection['selected_content_sha256'] == SELECTED, 'PROJECTION_SELECTION')
    for card_id in ('bloodRite', 'leechBlade'):
        src, dst = projection['cards'][card_id], current['cards'][card_id]
        dst['text'], dst['up']['text'] = src['text'], src['up']['text']
        for upgraded in (False, True):
            a = dst['up'] if upgraded else dst
            b = src['up'] if upgraded else src
            if card_id == 'bloodRite':
                require(a['effects'] == b['effects'][:-1], 'PRODUCER_OLD_EFFECTS')
                a['effects'].append(copy.deepcopy(b['effects'][-1]))
            else:
                require(len(a['effects']) == len(b['effects']) == 1, 'CONSUMER_SHAPE')
                expected = dict(b['effects'][0])
                bonus = expected.pop('bonus')
                require(a['effects'][0] == expected, 'CONSUMER_OLD_EFFECT')
                a['effects'][0]['bonus'] = bonus
    current['statuses']['bloodfire'] = copy.deepcopy(projection['status'])
    check = copy.deepcopy(current)
    check['statuses'].pop('bloodfire')
    for card_id in ('bloodRite', 'leechBlade'):
        check['cards'][card_id] = old['cards'][card_id]
    require(check == old and list(current['cards']) == list(old['cards']), 'UNRELATED_CONTENT_DELTA')
    return (json.dumps(current, ensure_ascii=False, indent=2) + '\n').encode()


def patch_combat(data):
    require(sha(data) == COMBAT, 'BASE_COMBAT')
    text = once(data.decode(), 'var content: ContentDB', '''# Research-only intervention switches; not promoted product configuration.
var bloodfire_enabled: bool = true
var bloodfire_producer_enabled: bool = true
var bloodfire_consumer_enabled: bool = true
var content: ContentDB''')
    text = once(text, '\t\t\tif who == "self":\n\t\t\t\tadd_status_player(cb, sid, sn)',
                '\t\t\tif who == "self":\n\t\t\t\tif sid != "bloodfire" or (bloodfire_enabled and bloodfire_producer_enabled and run.aspect == 1):\n\t\t\t\t\tadd_status_player(cb, sid, sn)')
    text = once(text, '\t\t"leech":\n\t\t\tvar leech_loss: int = hit_enemy(run, cb, target, _ji(fx["n"]), true, damage_mult)', '''\t\t"leech":
\t\t\tvar ready: bool = bloodfire_enabled and bloodfire_consumer_enabled and run.aspect == 1 and _sget(cb.player.statuses, "bloodfire") > 0
\t\t\tvar bloodfire_bonus: int = _ji(fx.get("bonus", 0)) if ready else 0
\t\t\tif ready:
\t\t\t\tadd_status_player(cb, "bloodfire", -1)
\t\t\tvar leech_loss: int = hit_enemy(run, cb, target, _ji(fx["n"]) + bloodfire_bonus, true, damage_mult)''')
    text = once(text, '\t\t\tif sid == "execute":', '''\t\t\tif sid == "leech" and bloodfire_enabled and bloodfire_consumer_enabled and run != null and run.aspect == 1 and _sget(p.statuses, "bloodfire") > 0:
\t\t\t\thits.append({"dmg": _preview_hit(p, target, _ji(fx["n"]) + _ji(fx.get("bonus", 0))), "times": 1})
\t\t\telif sid == "execute":''')
    return text.encode()


def assemble(repo, out, projection, active):
    require(not out.exists(), 'OUTPUT_EXISTS')
    out.mkdir(parents=True)
    for name in ('domain', 'content'):
        shutil.copytree(repo / name, out / name)
    (out / 'tools').mkdir()
    for name in ('vow_incentives.gd', 'balance_pilot.gd', 'balance_policy.gd', 'balance_sim.gd',
                 'balance_metrics.gd', 'balance_catalogue.gd', 'check_scripts.sh'):
        shutil.copyfile(repo / 'tools' / name, out / 'tools' / name)
    if active:
        path = out / 'content/full-content.json'
        path.write_bytes(candidate_content(path.read_bytes(), projection))
        path = out / 'domain/rules/combat.gd'
        path.write_bytes(patch_combat(path.read_bytes()))
    shutil.copyfile(HERE / 'probe.gd', out / 'probe.gd')
    (out / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="P9 Bloodfire minimum proof"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    return {str(p.relative_to(out)): {'sha256': sha(p.read_bytes()), 'bytes': p.stat().st_size}
            for p in sorted(out.rglob('*')) if p.is_file()}
