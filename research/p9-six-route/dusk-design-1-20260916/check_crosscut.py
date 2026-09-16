"""Finite DD1-X falsification checks. Results are derived from transitions.

Run: python check_crosscut.py [--mutant NAME]. Exit 2 means a violated claim.
All fixtures are constructed, non-native states, never empirical observations.
"""
from __future__ import annotations
import argparse
from copy import deepcopy
import itertools
import json
import sys
from crosscut_model import Card, Enemy, State, end_turn, play, return_hp, view


def run(mutant: str = '') -> dict:
    records: list[dict] = []

    def check(name: str, condition: bool, observed: object) -> None:
        records.append({'check': name, 'satisfied': bool(condition), 'observed': observed})

    def act(s: State, uid: int, target: int, **kw: object) -> str:
        return play(s, uid, s.enemies[target], mutant=mutant, **kw)

    def pair(**kw: object) -> State:
        s = State(**kw)
        act(s, 1, 0)
        act(s, 2, 1)
        return s

    s = pair()
    check('ordered-pair-physical-return', return_hp(s) == 5, view(s))
    check('two-cards-one-attack-lifecycle', (s.plays, s.attacks, len(s.discard), s.energy) == (2, 1, 2, 1), view(s))
    check('consume-once', s.anchor is None, view(s))
    check('untouched-third-enemy', s.enemies[2].hp == 40, view(s))
    s = State()
    act(s, 2, 1)
    act(s, 1, 0)
    check('wrong-order-has-no-retroactive-hit', return_hp(s) == 0, view(s))
    s = State()
    act(s, 1, 0)
    check('missing-consumer-keeps-only-block', return_hp(s) == 0 and s.block == 4, view(s))
    s = State()
    act(s, 2, 1)
    check('missing-producer-keeps-primary', return_hp(s) == 0 and s.enemies[1].hp == 35, view(s))
    s = State()
    act(s, 2, 1)
    check('missing-producer-keeps-primary', return_hp(s) == 0 and s.enemies[1].hp == 35, view(s))
    s = State(hand=[Card(1, 'P'), Card(22, 'C')])
    act(s, 1, 0)
    act(s, 22, 1)
    check('consumer-independent-card-instance', return_hp(s) == 5, view(s))
    s = State(hand=[Card(1, 'P'), Card(2, 'C'), Card(3, 'C')], energy=3)
    act(s, 1, 0)
    act(s, 2, 1)
    act(s, 3, 1)
    check('second-copy-cannot-reuse-anchor', return_hp(s) == 5, view(s))
    s = State(hand=[Card(1, 'P'), Card(2, 'C'), Card(3, 'C')], energy=3)
    act(s, 1, 0)
    act(s, 2, 0)
    act(s, 3, 1)
    check('same-target-spends-without-return', return_hp(s) == 0, view(s))
    s = State(hand=[Card(1, 'P'), Card(2, 'C'), Card(3, 'P')], energy=3)
    act(s, 1, 0)
    act(s, 3, 2)
    act(s, 2, 1)
    check('replacement-not-stacking', [e.hp for e in s.enemies] == [40, 35, 35], view(s))
    s = State()
    act(s, 1, 0)
    end_turn(s, mutant)
    act(s, 2, 1)
    check('end-turn-expiry', return_hp(s) == 0, view(s))
    old = State()
    act(old, 1, 0)
    s = State()
    s.anchor = old.anchor
    act(s, 2, 1)
    check('cross-combat-same-name-is-not-same-object', return_hp(s) == 0, view(s))
    s = State()
    act(s, 1, 0)
    s.enemies[0].hp = 0
    act(s, 2, 1)
    check('dead-anchor-no-return', return_hp(s) == 0, view(s))
    s = State(enemies=[Enemy('A')])
    act(s, 1, 0)
    act(s, 2, 0)
    check('single-enemy-no-package-payoff', return_hp(s) == 0, view(s))
    s = pair(aspect=1)
    check('other-aspect-no-package-payoff', return_hp(s) == 0 and s.block == 4 and s.enemies[1].hp == 35, view(s))
    for energy in [0, 1]:
        s = State(energy=energy)
        if energy:
            act(s, 1, 0)
        before = deepcopy(view(s))
        result = act(s, 2, 1)
        check(f'resource-denial-{energy}-unknown-tail', result == 'ILLEGAL_UNAVAILABLE' and view(s) == before,
              {'result': result, 'state': view(s), 'tail': 'UNKNOWN'})
    s = State()
    before = deepcopy(view(s))
    result = act(s, 999, 1)
    check('missing-hand-uid-unavailable', result == 'ILLEGAL_UNAVAILABLE' and view(s) == before, result)
    s = State()
    s.enemies[1].hp = 0
    before = deepcopy(view(s))
    result = act(s, 2, 1)
    check('dead-target-unavailable', result == 'ILLEGAL_UNAVAILABLE' and view(s) == before, result)
    s = pair(energy=1, first_discount=1)
    check('native-first-discount-not-flat-cost-denial', return_hp(s) == 5 and s.energy == 0, view(s))
    s = State()
    s.enemies[0].block = 20
    act(s, 1, 0)
    act(s, 2, 1)
    check('full-block-refutes-activation-implies-hp-payoff', return_hp(s) == 0 and s.enemies[0].block == 15, view(s))
    s = State()
    s.enemies[0].hp = 2
    act(s, 1, 0)
    act(s, 2, 1)
    rs = [e for e in s.trace if e['kind'] == 'hit' and e['phase'] == 'return']
    check('physical-hp-not-overkill-report', return_hp(s) == 2 and rs[0]['reported'] == 5, rs)
    s = State(strength=2, weak=True)
    s.enemies[0].vulnerable = 2
    s.enemies[0].block = 1
    act(s, 1, 0)
    act(s, 2, 1)
    check('sequential-floors-and-block', return_hp(s) == 6, view(s))
    s = State()
    s.enemies[1].thorns = 40
    act(s, 1, 0)
    act(s, 2, 1)
    check('first-hit-lethal-thorns-suppresses-return', return_hp(s) == 0 and s.over and s.hp == 0, s.trace)
    s = State()
    s.enemies[1].hp = 2
    s.enemies[1].handoff = True
    act(s, 1, 0)
    act(s, 2, 1)
    check('first-hit-finale-handoff-suppresses-return', return_hp(s) == 0 and s.over, s.trace)
    s = State(reaper=True)
    s.enemies[1].hp = 2
    act(s, 1, 0)
    act(s, 2, 1)
    check('nonfinal-death-keeps-source-economy-obligation', return_hp(s) == 5 and s.energy == 2 and s.reaper_draws_owed == 1, view(s))
    s = State()
    s.enemies[0].chips = s.enemies[0].facet - 1
    s.enemies[1].chips = s.enemies[1].facet - 1
    act(s, 1, 0)
    act(s, 2, 1)
    check('both-targets-coupled-shatter-stun', all(e.staggered and e.vulnerable == 2 for e in s.enemies[:2]), view(s))
    s = State()
    s.enemies[0].adamant = True
    s.enemies[0].chips = s.enemies[0].facet - 1
    act(s, 1, 0)
    act(s, 2, 1)
    check('adamant-hold-not-invented-shatter', s.enemies[0].adamant_spent and not s.enemies[0].staggered, view(s))
    s = State(bell=True)
    s.enemies[0].hp = 4
    s.enemies[1].chips = s.enemies[1].facet - 1
    act(s, 1, 0)
    act(s, 2, 1)
    check('deferred-chips-return-precedes-bell', return_hp(s) == 4, s.trace)
    s = State(bell=True)
    s.enemies[1].chips = s.enemies[1].facet - 1
    act(s, 1, 0, producer=False)
    act(s, 2, 1, consumer=False)
    check('collateral-refutes-anchor-hp-detector', return_hp(s) == 0 and s.enemies[0].hp == 36, s.trace)

    # All component masks retain BOTH legal card commands and native payloads.
    cells = {}
    for p, c in itertools.product([False, True], repeat=2):
        s = State()
        act(s, 1, 0, producer=p)
        act(s, 2, 1, consumer=c)
        cells[f'{int(p)}{int(c)}'] = {'return_hp': return_hp(s), 'hp_vector': [e.hp for e in s.enemies], 'block': s.block}
    check('proper-subsets-have-no-new-return', all(cells[k]['return_hp'] == 0 for k in ['00', '01', '10']), cells)
    check('whole-command-subsets-not-falsely-zero', all(cells[k]['hp_vector'][1] == 35 and cells[k]['block'] == 4 for k in cells), cells)
    check('union-of-disabled-factors-not-complete-chain', cells['11']['return_hp'] == 5 and cells['10']['return_hp'] + cells['01']['return_hp'] == 0, cells)

    # Non-lumpability witness: anchor choice changes NO old state before C.
    left, right = State(), State()
    act(left, 1, 0)
    act(right, 1, 2)
    old_equal = view(left, False) == view(right, False)
    act(left, 2, 1)
    act(right, 2, 1)
    lv, rv = [e.hp for e in left.enemies], [e.hp for e in right.enemies]
    check('target-blind-old-state-cannot-determine-new-transition', old_equal and lv != rv,
          {'same_old_projection': old_equal, 'left_hp': lv, 'right_hp': rv, 'old_generic_all_enemy_hp': [35, 35, 35]})
    check('generic-area-damage-is-not-selective-return', lv == [35, 35, 40] and lv != [35, 35, 35], lv)
    s = State(enemies=[Enemy('cosmetic-9'), Enemy('cosmetic-2'), Enemy('cosmetic-7')])
    act(s, 1, 0)
    act(s, 2, 1)
    check('cosmetic-renaming-commutes', [e.hp for e in s.enemies] == lv, view(s))

    # Finite cross-product; exact state-domain guarantee only, not native reachability.
    violations = []
    total = 0
    for up, aspect, a, b, shield, strength in itertools.product([False, True], [0, 1], range(3), range(3), [0, 5, 10], [0, 2]):
        total += 1
        s = State(hand=[Card(1, 'P'), Card(2, 'C', up)], aspect=aspect, strength=strength)
        s.enemies[a].block = shield
        act(s, 1, a)
        act(s, 2, b)
        expected = max(0, (7 if up else 5) + strength - shield) if aspect == 0 and a != b else 0
        if return_hp(s) != expected:
            violations.append([up, aspect, a, b, shield, strength, return_hp(s), expected])
    check('finite-domain-return-law', not violations, {'states': total, 'violations': violations})
    for up in [False, True]:
        s = pair(hand=[Card(1, 'P', up), Card(2, 'C')])
        check(f'producer-upgrade-{up}-does-not-change-return', s.block == (6 if up else 4) and return_hp(s) == 5, view(s))
    failures = [r['check'] for r in records if not r['satisfied']]
    return {'schema': 'DD1-X-SYMBOLIC-CHECKS-1', 'mutant': mutant or None,
            'decision': 'PROJECTION_CHECKS_PASS' if not failures else 'PROJECTION_CONTRACT_VIOLATION',
            'checks': len(records), 'finite_states': total, 'failures': failures,
            'native_calls': 0, 'empirical_spend': 0, 'certificate': False, 'records': records}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--mutant', default='', choices=['', 'copy-alias', 'ignore-thorns', 'same-target',
                                                       'retain-on-consume', 'eager-settlement', 'sticky-reset'])
    args = parser.parse_args()
    result = run(args.mutant)
    print(json.dumps(result, sort_keys=True, separators=(',', ':')))
    sys.exit(2 if result['failures'] else 0)
