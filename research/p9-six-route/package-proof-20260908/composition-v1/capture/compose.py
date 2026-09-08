"""Exact guarded-effect decomposition, not closed-package admission.

No model, engine, numerical-state abstraction, scalar erasure, or sampling.
The equality witness is an exact source decomposition under the unchanged
whole-command envelope. Different effect programs retain their parameters.
"""
from __future__ import annotations
import hashlib
import json
from pathlib import Path
import re
import sys

CONTENT = '3c7b2f9dba362d19128ef82ad559d3f26e54925371d823a665767032255eadaa'
COMBAT = 'a6fd99eb53030d3cf1401153bdeceec8b86ccc2af8b7643481855c681906f2ba'
BASE_CONTENT = 'a0d608a5142d2e3aab799cdf33d3163922b402c2aaf2a895e46e096399b56cf1'
BASE_COMBAT = '3adb0e063a536bf249d3b5d9524427facf1398304206da59d97594d3fff246e8'
LOOP = '''\tfor fx_v: Variant in effects:
\t\tif cb.over:
\t\t\tbreak
\t\tvar fx: Dictionary = fx_v
\t\t_apply_effect(run, cb, inst, d, fx, target, seal_mult)
'''
UNROLLED = '''\tif not cb.over:
\t\t_apply_effect(run, cb, inst, d, effects[0], target, seal_mult)
\tif not cb.over:
\t\t_apply_effect(run, cb, inst, d, effects[1], target, seal_mult)
'''

def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def require(ok: bool, reason: str) -> None:
    if not ok:
        raise ValueError(reason)


def function(source: str, name: str) -> str:
    starts = list(re.finditer(r'^(?:static )?func (\w+)\(', source, re.M))
    selected = [i for i, s in enumerate(starts) if s[1] == name]
    require(len(selected) == 1, 'FUNCTION_CARDINALITY:' + name)
    i = selected[0]
    text = source[starts[i].start():starts[i+1].start() if i+1<len(starts) else len(source)]
    lines = text.rstrip().splitlines()
    while lines and (not lines[-1].strip() or lines[-1].startswith('#')):
        lines.pop()
    return '\n'.join(lines)+'\n'


def arm(source: str, function_name: str, key: str) -> str:
    text = function(source, function_name)
    starts = list(re.finditer(r'^\t\t(?:"([\w]+)"|_):[^\n]*\n', text, re.M))
    selected = [i for i, s in enumerate(starts) if s[1] == key]
    require(len(selected) == 1, 'ARM_CARDINALITY:' + key)
    i = selected[0]
    return text[starts[i].end():starts[i+1].start() if i+1<len(starts) else len(text)].rstrip()+'\n'


def resolved(card: dict, upgraded: bool) -> dict:
    out = {k: v for k, v in card.items() if k != 'up'}
    if upgraded:
        out.update(card.get('up', {}))
    return out


def differences(a: dict, b: dict) -> list[str]:
    # Presence is observable, including an unknown key with explicit null.
    return sorted(k for k in a.keys() | b.keys()
                  if k not in a or k not in b or a[k] != b[k])


def unroll(source: str) -> str:
    body = function(source, 'play_card')
    require(body.count(LOOP) == 1, 'EFFECT_LOOP_CHANGED')
    # Exactly two effects only; all other programs follow the original loop.
    replacement = ('\tif effects.size() == 2:\n' +
                   ''.join('\t'+line for line in UNROLLED.splitlines(True)) +
                   '\telse:\n' + ''.join('\t'+line for line in LOOP.splitlines(True)))
    changed = body.replace(LOOP, replacement)
    require(source.count(body) == 1, 'BODY_CARDINALITY')
    return source.replace(body, changed)


def inspect(base: Path, candidate: Path) -> dict:
    identities = {}
    for key, root, c, s in [('base', base, BASE_CONTENT, BASE_COMBAT),
                            ('candidate', candidate, CONTENT, COMBAT)]:
        for rel, want in [('content/full-content.json', c), ('domain/rules/combat.gd', s)]:
            value = digest((root/rel).read_bytes())
            require(value == want, 'IDENTITY:'+key+':'+rel)
            identities[key+'/'+rel] = value
    old = json.loads((base/'content/full-content.json').read_bytes())
    new = json.loads((candidate/'content/full-content.json').read_bytes())
    bs = (base/'domain/rules/combat.gd').read_text()
    cs = (candidate/'domain/rules/combat.gd').read_text()
    witnesses = {}
    for fn in ['play_card', '_apply_effect', 'draw_cards', 'hit_enemy', 'apply_chips',
               '_shatter_enemy', 'eff_cost', 'can_play', 'end_turn', 'start_combat']:
        b, c = function(bs, fn), function(cs, fn)
        # Remove only trailing unindented section comments; body bytes stay exact.
        require(b == c, 'COMMON_ENVELOPE_CHANGED:'+fn)
        witnesses[fn] = digest(c.encode())
    for special in ['momentum', 'shatterEcho']:
        b, c = arm(bs, '_apply_special', special), arm(cs, '_apply_special', special)
        require(b == c, 'INHERITED_OPERATOR_CHANGED:'+special)
        witnesses[special] = digest(c.encode())
    growth = arm(cs, '_apply_special', 'momentum')
    require(growth == '\t\t\thit_enemy(run, cb, target, _ji(fx["n"]) + inst.bonus, true, damage_mult)\n\t\t\tinst.bonus += _ji(fx.get("grow", 0))\n', 'GROWTH_LAW_CHANGED')
    body = function(cs, 'play_card')
    require(body.count(LOOP) == 1, 'EFFECT_LOOP_CHANGED')
    pre, post = body.split(LOOP)
    # Current card is not moved to discard until AFTER all effects, chip flush,
    # and common post-play triggers. Single-zone validity is a stated premise.
    require('cb.hand.remove_at(i)' in pre and 'cb.discard.append(inst)' in post,
            'ZONE_ORDER_CHANGED')
    require('cb.discard.append(inst)' not in pre, 'PREMATURE_DISCARD')
    require('cb.pending_chips_active = true' in pre and
            'if cb.pending_chips_active and not cb.over:' in post, 'CHIP_ORDER_CHANGED')
    cardinst = (candidate/'domain/state/card_inst.gd').read_text()
    require(cardinst == (base/'domain/state/card_inst.gd').read_text(), 'INSTANCE_LIFECYCLE_CHANGED')
    require('return CardInst.new(uid, id, up)' in function(cardinst,'combat_copy'), 'RESET_CHANGED')
    cards = {}
    for cid in ['chisel','resonantLance','momentum','eclipseSlash','warCry']:
        cards[cid] = []
        for up in [False, True]:
            b, c = resolved(old['cards'][cid], up), resolved(new['cards'][cid], up)
            cards[cid].append({'upgraded':up, 'old':b, 'candidate':c,
                               'exact_changed_keys':differences(b,c)})
    for up, expect in [(False, (0,14)), (True, (1,17))]:
        c = resolved(new['cards']['momentum'],up)
        require(c['effects'] == [{'kind':'special','id':'momentum','n':expect[0],'grow':expect[1]},
                                 {'kind':'draw','n':1}], 'CYCLE_PROGRAM_CHANGED')
    return {
        'status':'GUARDED_COMPOSITION_PROVED_NOT_FULL_CLOSED_PACKAGE_EQUIVALENCE',
        'inputs':identities,'exact_common_blocks':witnesses,'cards':cards,
        'witness':{'prefix_sha256':digest(pre.encode()),'suffix_sha256':digest(post.encode()),
                   'loop_sha256':digest(LOOP.encode()),'unrolled_sha256':digest(UNROLLED.encode()),
                   'transformed_combat_sha256':digest(unroll(cs).encode())},
        'theorem':{
            'cycle':'Pre; G(n,grow); if not over then Draw(1); Post. Every event, RNG change, cost, CardInst identity and shared hook is preserved. The loop checks over before G as well.',
            'proof':'For length two, guarded loop expansion executes exactly the same ordered calls with the same object arguments; prefix and suffix bytes are identical. Other lengths use the original loop. Step identity implies equality of finite command traces from identical complete states and content.',
            'domain':'Well-typed immutable resolved effect arrays and engine semantics of the pinned candidate; no total-correctness claim for malformed runtime objects.',
            'self_draw':'In a valid single-zone state, the currently played instance is outside hand/draw/discard during Draw(1), so this draw cannot return that same instance. Subsequent ordinary turn/draw transitions can return it.',
            'termination':'The common over guard is retained. Draw may be skipped after lethal damage; chip flush follows the draw, not vice versa.',
            'historical_limit':'This proves composition of inherited operators, not equivalence to the frozen old Honing card, the old repeat-extra-chip proposal, or a two-card player sequence. Acquisition, costs, card-play triggers and numeric parameters are NOT erased.'},
        'decisions':{
            'cycle_new_independent_effect_operator':False,
            'cycle_exact_guarded_effect_composition':True,
            'cycle_identical_to_old_whole_card':False,
            'cycle_self_redraw_inside_own_action':False,
            'facet_whole_acquisition_equivalent_to_old_card':False,
            'all_closed_package_comparisons_complete':False,
            'authorises_new_cohort':False,'packages_admitted':0,'p9_certified':False}}

if __name__ == '__main__':
    if len(sys.argv)!=3:
        raise SystemExit('usage: compose.py BASE CANDIDATE')
    print(json.dumps(inspect(Path(sys.argv[1]),Path(sys.argv[2])),indent=2))
