"""Bind the EXISTING minimum candidate; add interventions only in a test subclass.
Reconstructed bytes must equal the already-published assembly hashes.
"""
from __future__ import annotations
import copy
import hashlib
import json
from pathlib import Path
import shutil

BASE_CONTENT = 'a0d608a5142d2e3aab799cdf33d3163922b402c2aaf2a895e46e096399b56cf1'
BASE_COMBAT = '3adb0e063a536bf249d3b5d9524427facf1398304206da59d97594d3fff246e8'
MIN_CONTENT = '4107c7c0bbed5d9acf8c2bdf97023552426920242ea958c8ebdec793b712afd9'
MIN_COMBAT = '3ccb89f69f50e41d5a46eadd8f48c0a907fd0e382cd492b2c34dd5f93e091ad0'
HERE = Path(__file__).resolve().parent


def sha(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()


def require(ok: bool, message: str) -> None:
    if not ok:
        raise ValueError(message)


def once(text: str, old: str, new: str) -> str:
    require(text.count(old) == 1, 'PATCH_ANCHOR:' + old[:60])
    return text.replace(old, new, 1)


def candidate_content(raw: bytes) -> bytes:
    require(sha(raw) == BASE_CONTENT, 'BASE_CONTENT')
    c = json.loads(raw)
    original = copy.deepcopy(c)
    for up in (False, True):
        a = c['cards']['bloodRite']['up'] if up else c['cards']['bloodRite']
        require(a['effects'] == [{'kind': 'loseHp', 'n': 3}, {'kind': 'energy', 'n': 3 if up else 2}], 'SOURCE_IS_HP_FOR_ENERGY_NOT_DRAW')
        a['effects'].append({'kind': 'status', 'who': 'self', 'id': 'bloodfire', 'n': 1})
        a['text'] = f"Lose 3 HP. Gain {3 if up else 2} Energy. Ashwarden: gain 1 Bloodfire."
        b = c['cards']['leechBlade']['up'] if up else c['cards']['leechBlade']
        b['effects'][0]['bonus'] = 12 if up else 10
        b['text'] = f"Deal @{13 if up else 9}@ damage. Heal for half the unblocked damage. Ashwarden: consume Bloodfire to deal @{12 if up else 10}@ more."
    c['statuses']['bloodfire'] = {'icon': '\u2665', 'kind': 'buff', 'name': 'Bloodfire', 'desc': 'Pain banked as heat. Thirsting Shard consumes one stack for bonus damage and healing.'}
    restored = copy.deepcopy(c)
    del restored['statuses']['bloodfire']
    for k in ('bloodRite', 'leechBlade'):
        restored['cards'][k] = original['cards'][k]
    require(restored == original, 'UNRELATED_CONTENT_CHANGE')
    data = (json.dumps(c, ensure_ascii=False, indent=2) + '\n').encode()
    require(sha(data) == MIN_CONTENT, 'MINIMUM_CONTENT_IDENTITY')
    return data


def candidate_combat(data: bytes) -> bytes:
    require(sha(data) == BASE_COMBAT, 'BASE_COMBAT')
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
    result = text.encode()
    require(sha(result) == MIN_COMBAT, 'MINIMUM_COMBAT_IDENTITY')
    return result


def assemble(base: Path, out: Path) -> dict:
    require(not out.exists(), 'PROJECT_ALREADY_EXISTS')
    content = candidate_content((base/'content/full-content.json').read_bytes())
    combat = candidate_combat((base/'domain/rules/combat.gd').read_bytes())
    out.mkdir(parents=True)
    for name in ('domain', 'content'):
        shutil.copytree(base/name, out/name)
    (out/'content/full-content.json').write_bytes(content)
    (out/'domain/rules/combat.gd').write_bytes(combat)
    (out/'tools').mkdir()
    shutil.copyfile(base/'tools/check_scripts.sh', out/'tools/check_scripts.sh')
    # Runtime-facing dependency of current domain commands.
    shutil.copyfile(base/'tools/vow_incentives.gd', out/'tools/vow_incentives.gd')
    for name in ('causal_rules.gd', 'causal_probe.gd'):
        shutil.copyfile(HERE/name, out/name)
    (out/'project.godot').write_text('config_version=5\n[application]\nconfig/name="P9 source utility mediation proof"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    return {str(p.relative_to(out)): {'bytes': p.stat().st_size, 'sha256': sha(p.read_bytes())}
            for p in sorted(out.rglob('*')) if p.is_file()}
