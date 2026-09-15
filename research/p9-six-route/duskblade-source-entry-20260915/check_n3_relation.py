#!/usr/bin/env python3
"""Check vulnerable algebra/identity steps of PROOF-RESOLUTION, not a game.

No damage engine, legality oracle, cohort, admission classifier, or network.
The induction in the written proof covers arbitrary legal native prefixes.
Here native addition and the entire common combat continuation are opaque terms.
The independently written register and event-history presentations must agree.
"""
from __future__ import annotations
import copy
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent
INPUT_BLOB = 'd645357de8bc463a1c54d63cbcfb1bc625e9cf07'


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def git_blob(data: bytes) -> str:
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()


def sources(inputs: dict, readback: dict) -> None:
    indexed = {s['id']: s for s in inputs['sources']}
    require(inputs['parameters']['momentum'] == [1, 6, 4, 8, 6, 0], 'changed-native-card')
    require(git_blob(inputs['card_inst_complete'].encode()) == indexed['card_inst']['blob'],
            'changed-complete-CardInst')
    rows = readback['complete_objects']
    require({r['source_id'] for r in rows} == {'content', 'combat', 'card_inst'}
            and len(rows) == 3, 'incomplete-source-relation')
    for row in rows:
        old = indexed[row['source_id']]
        require(row['path'] == old['path'] and row['slate_blob'] == old['blob']
                == row['archived_baseline_blob'], 'whole-object-nonidentity:' + row['path'])


def add(left: object, right: object) -> tuple:
    # Do not simplify, reorder, or assume real/infinite-precision arithmetic.
    return ('native_add', left, right)


def fold(growths: list) -> object:
    term: object = 0
    for growth in growths:
        term = add(term, growth)
    return term


def register_view(events: list[dict], mutant: str = '') -> list:
    """N3 presentation: combat-instance bonus register, read before write."""
    bonuses: dict = {}
    out = []
    for e in events:
        if e['kind'] != 'H':
            out.append(('common_edge', e))  # Retain Deflect/turn/etc., not erase it.
            continue
        key = e['uid'] if mutant == 'erase-fight' else (e['fight'], e['uid'])
        if mutant == 'collapse-copies':
            key = e['fight']
        before = bonuses.get(key, 0)
        after = add(before, e['grow'])
        read = after if mutant == 'growth-before-hit' else before
        out.append(('native_H_call', e['fight'], e['uid'], e['target'],
                    add(e['n'], read), e['context']))
        # Source increments even when hit_enemy ended the fight. A later legal
        # consumer is a separate obligation; this term asserts no such consumer.
        bonuses[key] = after
    return out


def family_view(events: list[dict]) -> list:
    """Closed-family native-law presentation: fold earlier same-instance plays."""
    out = []
    for i, e in enumerate(events):
        if e['kind'] != 'H':
            out.append(('common_edge', e))
            continue
        history = [p['grow'] for p in events[:i] if p['kind'] == 'H'
                   and (p['fight'], p['uid']) == (e['fight'], e['uid'])]
        out.append(('native_H_call', e['fight'], e['uid'], e['target'],
                    add(e['n'], fold(history)), e['context']))
    return out


def archived_repeat(events: list[dict]) -> bool:
    keys = [(e['fight'], e['uid']) for e in events if e['kind'] == 'H']
    return len(keys) != len(set(keys))


def pair_projects(events: list[dict], producer: int, consumer: int) -> bool:
    """Only the necessary event clause; NOT an enactment/legality checker."""
    p, c = events[producer], events[consumer]
    return producer < consumer and p['kind'] == c['kind'] == 'H' and (
        p['fight'], p['uid']) == (c['fight'], c['uid'])


def run() -> dict:
    raw = (ROOT / 'SOURCE-INPUTS.json').read_bytes()
    require(git_blob(raw) == INPUT_BLOB, 'changed-SOURCE-INPUTS')
    inputs = json.loads(raw)
    rb_raw = (ROOT / 'PROOF-SOURCE-READBACK.json').read_bytes()
    readback = json.loads(rb_raw)
    sources(inputs, readback)
    results = []

    def check(name: str, observed: object, expected: object) -> None:
        require(observed == expected, name)
        results.append({'name': name, 'observed': observed, 'expected': expected})

    def rejects(name: str, fn) -> None:
        try:
            fn()
        except ValueError as error:
            results.append({'name': name, 'expected_rejection': str(error)})
            return
        raise ValueError('mutation-survived:' + name)

    check('source-object-map-agrees-with-pinned-inputs', True, True)
    # Symbolic base/append equations; written induction, not bounded testing,
    # establishes this relation for arbitrary-length native legal histories.
    check('empty-combat-history', fold([]), 0)
    for gs in ([], ['g0'], ['g0', 'g1']):
        check('induction-append-' + str(len(gs)), fold(gs + ['g']), add(fold(gs), 'g'))

    def h(fight=0, uid=11, target=0, n=6, grow=4, context='B'):
        return dict(kind='H', fight=fight, uid=uid, target=target, n=n,
                    grow=grow, context=context)

    _, n, g, up_n, up_g, _ = inputs['parameters']['momentum']
    cases = {
        'native-base-replay': [h(n=n, grow=g), h(n=n, grow=g)],
        'native-upgrade-replay': [h(n=up_n, grow=up_g), h(n=up_n, grow=up_g)],
        'second-copy-interleaving': [h(), h(uid=12), h()],
        'same-uid-new-combat': [h(), h(fight=1), h(fight=1)],
        'retarget-with-all-background-kept': [h(context='Strength+Shatter+Thorns'),
                                           h(target=1, context='Strength+Shatter+Thorns')],
        'optional-Deflect-kept': [h(), {'kind': 'Deflect', 'cost': 1, 'block': 6,
                                      'draw': 'native-RNG-reference-permutation'}, h()],
        'ordinary-turn-kept': [h(), {'kind': 'end_turn', 'effects': 'entire-native-continuation'}, h()],
        'terminal-hit-still-writes-bonus': [h(context='hit_returns_combat_over')],
    }
    for name, events in cases.items():
        check(name, register_view(events), family_view(events))
    for mutant, case in [('growth-before-hit', 'native-base-replay'),
                         ('collapse-copies', 'second-copy-interleaving'),
                         ('erase-fight', 'same-uid-new-combat')]:
        check('reject-' + mutant, register_view(cases[case], mutant) != family_view(cases[case]), True)

    # Exhaust the pair's equality/order partitions, not a game-state space.
    partitions = 0
    for same_fight in (False, True):
        for same_uid in (False, True):
            events = [h(), h(fight=0 if same_fight else 1, uid=11 if same_uid else 12)]
            for p, c in ((0, 1), (1, 0), (0, 0)):
                antecedent = pair_projects(events, p, c)
                require(not antecedent or archived_repeat(events), 'pair-inclusion-counterexample')
                partitions += 1
    check('pair-equality-order-partitions', partitions, 12)
    check('different-copy-is-not-repeat', archived_repeat([h(), h(uid=12)]), False)
    check('different-fight-is-not-repeat', archived_repeat([h(), h(fight=1)]), False)

    # Converse countermodel to positive HP, not to all possible payoff metrics.
    # A common residual Block 100 absorbs both inputs. No Block reset is made.
    block = 100
    losses = []
    for base in (n, n + g):
        blocked = min(block, base)
        block -= blocked
        losses.append(base - blocked)
    check('repeat-does-not-imply-positive-HP',
          [archived_repeat([h(), h()]), losses, block], [True, [0, 0], 84])

    changed = copy.deepcopy(inputs)
    changed['parameters']['momentum'][-1] = 1
    rejects('invented-on-card-draw', lambda: sources(changed, readback))
    changed_rb = copy.deepcopy(readback)
    changed_rb['complete_objects'][1]['archived_baseline_blob'] = '0' * 40
    rejects('mismatched-archived-combat', lambda: sources(inputs, changed_rb))
    return {'kind': 'N3-SYMBOLIC-RELATION-REGRESSION-NOT-NATIVE',
            'source_inputs_git_blob': INPUT_BLOB,
            'source_readback_sha256': hashlib.sha256(rb_raw).hexdigest(),
            'checker_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            'checks': results, 'check_count': len(results), 'all_checks_matched': True,
            'proof': 'PROOF-RESOLUTION.md T1-T4',
            'limits': ['No native transition or natural-run reachability was executed.',
                       'Opaque common contexts retain native effects; their outcomes are not computed.',
                       'Pair projection is a necessary clause, not complete N3 enactment.',
                       'Author source/authority argument is not independent review.'],
            'native_calls': 0, 'empirical_spend': 0, 'certificates': 0}


if __name__ == '__main__':
    try:
        result = run()
    except (ValueError, KeyError, TypeError, OSError, json.JSONDecodeError) as error:
        print('N3 proof check rejected: ' + str(error), file=sys.stderr)
        sys.exit(2)
    print(json.dumps(result, sort_keys=True))
