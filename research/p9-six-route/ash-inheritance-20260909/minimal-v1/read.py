"""Offline complete-matrix preflight reader; never a P9 admission."""
from __future__ import annotations
import itertools
import json
from pathlib import Path

MODES = ('baseline', 'off', 'active', 'producer_off', 'consumer_off', 'erase_mediator')
CONTEXTS = ('plain', 'block', 'weak_vulnerable', 'thorns', 'lethal_enemy', 'source_lethal')


def need(ok, why):
    if not ok:
        raise ValueError(why)


def key(row):
    return (row['kind'], row['aspect'], row['vow'], row.get('up'), row.get('context'))


def stock(state):
    return state['combat']['player']['statuses'].get('bloodfire', 0)


def hits(step):
    return [event for event in step['events'] if event['t'] == 'hitEnemy']


def analyse(folder):
    folder = Path(folder)
    allrows, checks = {}, []
    identities = json.loads((folder.parent / 'ASSEMBLY.json').read_bytes())
    def ck(ok, note):
        checks.append({'check': note, 'pass': bool(ok)})
    expected = {('pair', a, v, u, c) for a, v, u, c in itertools.product(
        (0, 1), (0, 5), (False, True), CONTEXTS)}
    expected |= {('lifecycle', a, v, u, None) for a, v, u in itertools.product((0, 1), (0, 5), (False, True))}
    expected |= {('legality', a, v, None, None) for a, v in itertools.product((0, 1), (0, 5))}
    for mode in MODES:
        records = [json.loads(line) for line in (folder / (mode + '.jsonl')).read_text().splitlines()]
        need(len(records) >= 2, 'INCOMPLETE_STREAM:' + mode)
        header = records[0]
        need(header['kind'] == 'manifest' and header['mode'] == mode, 'MANIFEST')
        need(header['engine'] == '4.7.2-stable (official)', 'ENGINE')
        identity = identities['baseline' if mode == 'baseline' else 'candidate']
        for field, path in (('content_sha256', 'content/full-content.json'),
                            ('combat_sha256', 'domain/rules/combat.gd'), ('probe_sha256', 'probe.gd')):
            need(header[field] == identity[path]['sha256'], 'NATIVE_SOURCE:' + field)
        need(records[-1] == {'kind': 'terminal', 'cases': 60}, 'TERMINAL')
        rows = {key(row): row for row in records[1:-1]}
        need(len(rows) == len(records) - 2 == 60 and set(rows) == expected, 'COVERAGE:' + mode)
        allrows[mode] = rows
        for identity, row in rows.items():
            for i, step in enumerate(row['steps']):
                ck(step['preview_readonly'], f'{mode}:{identity}:{i}:query_pure')
    for identity, baseline in allrows['baseline'].items():
        for mode in MODES[1:]:
            row = allrows[mode][identity]
            if mode == 'off' or identity[1] == 0:
                ck(row['steps'] == baseline['steps'], f'{mode}:{identity}:full_null')
        if identity[0] == 'pair':
            for mode in MODES[1:]:
                row = allrows[mode][identity]
                source, consumer = row['steps']
                enabled = identity[1] == 1 and mode != 'off'
                added = enabled and mode != 'producer_off' and identity[-1] != 'source_lethal'
                ck(stock(source['after']) == int(added), f'{mode}:{identity}:source_stock')
                if identity[-1] == 'source_lethal':
                    ck(not hits(consumer) and stock(consumer['after']) == 0, f'{mode}:{identity}:death_short_circuit')
                    continue
                payoff = added and mode not in ('consumer_off', 'erase_mediator')
                base = 13 if identity[3] else 9
                bonus = (12 if identity[3] else 10) if payoff else 0
                nominal = base + bonus
                if identity[-1] == 'weak_vulnerable':
                    nominal = (nominal * 3 // 4) * 3 // 2
                blocked = min(12, nominal) if identity[-1] == 'block' else 0
                events = hits(consumer)
                ck(len(events) == 1, f'{mode}:{identity}:one_hit')
                if events:
                    ck(events[0]['amount'] == nominal - blocked and events[0]['blocked'] == blocked,
                       f'{mode}:{identity}:source_bound_payoff')
                ck(stock(consumer['after']) == int(added and mode == 'consumer_off'),
                   f'{mode}:{identity}:one_stack_consumed')
                if payoff:
                    ck(isinstance(consumer['preview'], dict) and consumer['preview']['loss'] == nominal - blocked,
                       f'{mode}:{identity}:active_preview')
                else:
                    ck(consumer['preview'] is None, f'{mode}:{identity}:dormant_preview_unchanged')
        if identity[0] == 'lifecycle':
            for mode in MODES:
                steps = allrows[mode][identity]['steps']
                enabled = identity[1] == 1 and mode not in ('baseline', 'off', 'producer_off')
                ck(stock(steps[1]['after']) == (2 if enabled else 0), f'{mode}:{identity}:stack_twice')
                consumed = enabled and mode != 'consumer_off'
                ck(stock(steps[2]['after']) == ((1 if consumed else 2) if enabled else 0),
                   f'{mode}:{identity}:one_per_hit')
                ck(stock(steps[4]['after']) == 1, f'{mode}:{identity}:no_turn_decay')
                ck(stock(steps[5]['after']) == 0, f'{mode}:{identity}:fresh_combat_reset')
        if identity[0] == 'legality':
            for mode in MODES:
                a, b = allrows[mode][identity]['steps']
                ck(a['after']['return'] is False and stock(a['after']) == 1 and not a['events'],
                   f'{mode}:{identity}:illegal_no_consumption')
                ck(b['after']['return'] is True, f'{mode}:{identity}:cost_unchanged')
    failures = [check for check in checks if not check['pass']]
    return {'status': 'BLOODFIRE_MINIMAL_PREFLIGHT_PASS' if not failures else 'BLOODFIRE_MINIMAL_PREFLIGHT_FAIL',
            'cases': 360, 'checks': len(checks), 'failed_checks': failures,
            'scope': 'Finite source/null/preview/stack/lifecycle preflight, not package, policy, reachability, general safety or P9 admission.',
            'new_independent_samples': 0, 'packages_admitted': 0, 'p9_certified': False}


if __name__ == '__main__':
    import sys
    result = analyse(Path(sys.argv[1]))
    Path(sys.argv[2]).write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))
    raise SystemExit(0 if result['status'].endswith('_PASS') else 3)
