"""Offline, exact-source lineage screen; NOT a canonical quotient or P9 gate.

Usage: python audit_source.py BASE_REPO ASSEMBLED_CANDIDATE
The candidate is assembled by the already committed finite-audit assemble.py.
No engine, native row, model fit or protected cohort is opened. This is a
post-observation source audit: its findings are not independent confirmation.
"""
from __future__ import annotations
import hashlib
import json
from pathlib import Path
import re
import sys

BASE_CONTENT = 'a0d608a5142d2e3aab799cdf33d3163922b402c2aaf2a895e46e096399b56cf1'
BASE_COMBAT = '3adb0e063a536bf249d3b5d9524427facf1398304206da59d97594d3fff246e8'
CAND_CONTENT = '3c7b2f9dba362d19128ef82ad559d3f26e54925371d823a665767032255eadaa'
CAND_COMBAT = 'a6fd99eb53030d3cf1401153bdeceec8b86ccc2af8b7643481855c681906f2ba'
CARDS = ('chisel', 'resonantLance', 'momentum', 'empower', 'flurry',
         'nightSight', 'phantomBlades', 'venomStrike', 'catalyst')
# Only this explicit projection is compared. Unknown keys remain observable.
NON_COMBAT = frozenset(('name', 'text', 'vfx', 'rarity', 'locked', 'up'))


def require(value: bool, message: str) -> None:
    if not value:
        raise ValueError(message)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def functions(source: str) -> dict[str, str]:
    """Exact bodies in this pinned source's top-level function grammar."""
    starts = list(re.finditer(r'^(?:static )?func ([A-Za-z_]\w*)\(', source, re.M))
    require(bool(starts), 'no functions')
    out = {}
    for i, start in enumerate(starts):
        name = start.group(1)
        require(name not in out, 'duplicate function:' + name)
        text = source[start.start():starts[i + 1].start() if i + 1 < len(starts) else len(source)]
        lines = text.rstrip().splitlines()
        # Non-indented trailing section comments are not function statements.
        while lines and (not lines[-1].strip() or lines[-1].startswith('#')):
            lines.pop()
        out[name] = '\n'.join(lines) + '\n'
    return out


def special_arm(source: str, name: str) -> str:
    text = functions(source)['_apply_special']
    starts = list(re.finditer(r'^\t\t(?:"([A-Za-z_]\w*)"|_):', text, re.M))
    found = [i for i, s in enumerate(starts) if s.group(1) == name]
    require(len(found) == 1, 'missing/duplicate special arm:' + name)
    i = found[0]
    body = text[starts[i].end():starts[i + 1].start() if i + 1 < len(starts) else len(text)]
    return body.strip('\n') + '\n'


def resolved(card: dict, upgraded: bool) -> dict:
    result = dict(card)
    if upgraded:
        result.update(card.get('up', {}))
    return result


def combat_card(card: dict, upgraded: bool) -> dict:
    return {k: v for k, v in resolved(card, upgraded).items() if k not in NON_COMBAT}


def compare_card(base: dict, candidate: dict, upgraded: bool) -> dict:
    b, c = resolved(base, upgraded), resolved(candidate, upgraded)
    return {'upgraded': upgraded,
            'changed_keys': sorted(k for k in set(b) | set(c) if b.get(k) != c.get(k)),
            'combat_projection_equal': combat_card(base, upgraded) == combat_card(candidate, upgraded),
            'base_effects': b.get('effects', []), 'candidate_effects': c.get('effects', []),
            'base_rarity': b.get('rarity'), 'candidate_rarity': c.get('rarity')}


def inspect(base: Path, candidate: Path) -> dict:
    identities = {}
    for label, root, want_content, want_combat in (
            ('base', base, BASE_CONTENT, BASE_COMBAT),
            ('candidate', candidate, CAND_CONTENT, CAND_COMBAT)):
        identities[label] = {}
        for path, expected in (('content/full-content.json', want_content),
                               ('domain/rules/combat.gd', want_combat)):
            actual = sha((root / path).read_bytes())
            require(actual == expected, label + ' identity:' + path)
            identities[label][path] = actual
    b = json.loads((base / 'content/full-content.json').read_bytes())
    c = json.loads((candidate / 'content/full-content.json').read_bytes())
    bs = (base / 'domain/rules/combat.gd').read_text()
    cs = (candidate / 'domain/rules/combat.gd').read_text()
    bf, cf = functions(bs), functions(cs)
    unchanged = sorted(k for k in bf if k in cf and bf[k] == cf[k])
    changed = sorted(k for k in bf if k in cf and bf[k] != cf[k])
    added = sorted(set(cf) - set(bf))
    removed = sorted(set(bf) - set(cf))
    domain_changed = []
    for path in sorted((base / 'domain').rglob('*')):
        if not path.is_file():
            continue
        relative = path.relative_to(base)
        other = candidate / relative
        if not other.is_file() or path.read_bytes() != other.read_bytes():
            domain_changed.append(str(relative))
    added_domain = sorted(str(p.relative_to(candidate)) for p in (candidate / 'domain').rglob('*')
                          if p.is_file() and not (base / p.relative_to(candidate)).exists())
    cards = {k: [compare_card(b['cards'][k], c['cards'][k], up) for up in (False, True)] for k in CARDS}
    arms = {k: {'body_equal': special_arm(bs, k) == special_arm(cs, k),
                'base_body_sha256': sha(special_arm(bs, k).encode()),
                'candidate_body_sha256': sha(special_arm(cs, k).encode())}
            for k in ('shatterEcho', 'momentum', 'catalyst', 'phantom')}
    context_changes = {}
    for key in sorted(set(b) | set(c)):
        if key == 'cards' or b.get(key) == c.get(key):
            continue
        if isinstance(b.get(key), dict) and isinstance(c.get(key), dict):
            context_changes[key] = sorted(x for x in set(b[key]) | set(c[key]) if b[key].get(x) != c[key].get(x))
        else:
            context_changes[key] = 'section_changed'
    core = ('play_card', 'hit_enemy', '_apply_effect', 'apply_chips', '_shatter_enemy',
            'end_turn', 'draw_cards', '_start_player_turn', 'start_combat', 'card_data',
            'can_play', 'eff_cost')
    require(all(k in unchanged for k in core), 'unexpected route dispatch/lifecycle change')
    require(domain_changed == ['domain/rules/combat.gd'] and not added_domain, 'unexamined domain delta')
    facet_same = all(row['combat_projection_equal'] for k in ('chisel', 'resonantLance') for row in cards[k]) and arms['shatterEcho']['body_equal']
    cycle_draw_added = all(row['candidate_effects'][1:] == [{'kind': 'draw', 'n': 1}] and len(row['base_effects']) == 1 for row in cards['momentum'])
    return {
        'status': 'EXACT_SOURCE_LINEAGE_NOT_FULL_PACKAGE_EQUIVALENCE',
        'review_kind': 'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT',
        'source_identities': identities,
        'domain_changed': domain_changed, 'added_domain': added_domain,
        'unchanged_combat_functions': unchanged, 'changed_combat_functions': changed,
        'added_combat_functions': added, 'removed_combat_functions': removed,
        'special_arms': arms, 'card_comparisons': cards,
        'non_card_context_changes': context_changes,
        'decisions': {
            'facet_named_pair_has_unchanged_intrinsic_combat_law': facet_same,
            'facet_new_echo_primitive_demonstrated': False,
            'cycle_growth_operator_and_reset_unchanged': arms['momentum']['body_equal'],
            'cycle_has_added_ordinary_draw': cycle_draw_added,
            'cycle_entire_action_equivalent_to_old_card': False,
            'whole_game_equivalence_established': False,
            'complete_closed_family_quotient_established': False,
            'historical_cohort_failure_is_universal_nonviability': False,
            'admission_from_labels_or_source_lineage_permitted': False},
        'limits': [
            'The explicit combat-card projection excludes presentation/acquisition metadata, not arbitrary fields.',
            'Identical bodies are source evidence, not independently qualified runtime/source translation.',
            'Facet is an unchanged named combat motif under matched context; different acquisition and global content prevent a whole-game equivalence claim.',
            'Cycle composes old growth with draw and changed magnitudes. A union/decomposition screen is still required; scalar erasure is not a bisimulation proof.',
            'Historical Dusk policy/cohort closures cannot establish universal Ash or changed-context futility.',
            'Hand-size improvement is expressly permitted by the programme; generic primitives need not be globally aspect-exclusive.'],
        'new_native_runs': 0, 'new_independent_samples': 0,
        'packages_admitted': 0, 'p9_certified': False}


if __name__ == '__main__':
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    print(json.dumps(inspect(Path(sys.argv[1]), Path(sys.argv[2])), indent=2))
