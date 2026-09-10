"""Strict reconstruction of the source-utility / mediator factorial.
No action rejected by a counterfactual is silently given a zero payoff.
"""
from __future__ import annotations
import copy
import hashlib
import itertools
import json
import lzma
from pathlib import Path
from assemble import require, MIN_CONTENT, MIN_COMBAT

SOURCES = ('bloodRite', 'preparation', 'surge')
CONTEXTS = ('available', 'no_energy', 'hand_cap', 'empty_draw', 'shuffle', 'blocked', 'already_lethal', 'source_fatal')
KEYS = ('aspect', 'vow', 'up', 'context')
ARMS = (-1, 0, 1, 2, 3, 4, 5, 6, 7)


def snapshot_without_path(state: dict, pathway: str) -> dict:
    s = copy.deepcopy(state)
    if pathway == 'bloodfire':
        s['combat']['player']['statuses'].pop('bloodfire', None)
        s['combat']['queue'] = [e for e in s['combat']['queue'] if not (e.get('t') == 'status' and e.get('id') == 'bloodfire')]
    elif pathway == 'energy':
        s['combat']['player']['energy'] = 0
        s['combat']['queue'] = [e for e in s['combat']['queue'] if e.get('t') != 'energy']
    else:
        raise ValueError('UNKNOWN_PROJECTION')
    return s


def source_without_path(row: dict, pathway: str) -> dict:
    s = copy.deepcopy(row['steps'][0])
    s['before'] = snapshot_without_path(s['before'], pathway)
    s['after'] = snapshot_without_path(s['after'], pathway)
    if pathway == 'bloodfire':
        s['events'] = [e for e in s['events'] if not (e.get('t') == 'status' and e.get('id') == 'bloodfire')]
    else:
        s['events'] = [e for e in s['events'] if e.get('t') != 'energy']
    return s


def payoff(step: dict) -> dict:
    require(type(step['ret']) is bool, 'NONBOOLEAN_PLAY_RETURN')
    if not step['ret']:
        return {'eligible': False, 'actual_hp_removed': None, 'healing_events': None,
                'native_hit_amount': None, 'player_hp_delta': None}
    a, b = step['before']['combat'], step['after']['combat']
    target = step['command']['target']
    x = {e['idx']: e for e in a['enemies']}
    y = {e['idx']: e for e in b['enemies']}
    require(target in x and target in y, 'TARGET_IDENTITY')
    return {'eligible': True,
            'actual_hp_removed': max(x[target]['hp'], 0) - max(y[target]['hp'], 0),
            'healing_events': sum(e['n'] for e in step['events'] if e.get('t') == 'heal' and e.get('who') == 'player'),
            'native_hit_amount': sum(e['amount'] for e in step['events'] if e.get('t') == 'hitEnemy' and e.get('idx') == target),
            'player_hp_delta': b['player']['hp'] - a['player']['hp']}


def interaction(rows: dict, energy: bool) -> dict:
    start = 4 if energy else 0
    p = {i: payoff(rows[start+i]['steps'][1]) for i in range(4)}
    if not all(x['eligible'] for x in p.values()):
        return {'identified_for_fixed_commands': False,
                'ineligible_arms': [start+i for i,x in p.items() if not x['eligible']],
                'actual_hp_interaction': None, 'healing_interaction': None}
    return {'identified_for_fixed_commands': True, 'ineligible_arms': [],
            'actual_hp_interaction': p[3]['actual_hp_removed'] - p[2]['actual_hp_removed'] - p[1]['actual_hp_removed'] + p[0]['actual_hp_removed'],
            'healing_interaction': p[3]['healing_events'] - p[2]['healing_events'] - p[1]['healing_events'] + p[0]['healing_events']}


def check_group(source: str, key: tuple, rows: dict) -> dict:
    require(set(rows) == set(ARMS), 'FULL_FACTORIAL_AND_NATIVE_REFERENCE')
    reference = rows[-1]
    for arm, r in rows.items():
        require(r['source'] == source and tuple(r[k] for k in KEYS) == key, 'GROUP_BINDING')
        require(r['start'] == reference['start'], 'MATCHED_START')
        require(len(r['steps']) == 2, 'COMPLETE_SEQUENCE')
        require(r['steps'][0]['command'] == {'t':'playCard', 'uid':900, 'target':None}, 'SOURCE_COMMAND')
        require(r['steps'][1]['command'] == {'t':'playCard', 'uid':901, 'target':0}, 'CONSUMER_COMMAND')
        require(r['start'] == r['steps'][0]['before'] and r['steps'][0]['after'] == r['steps'][1]['before'] and r['steps'][1]['after'] == r['end'], 'SEQUENTIAL_CONTINUITY')
    require(rows[7]['steps'] == reference['steps'] and rows[7]['end'] == reference['end'], 'ALL_ON_NATIVE_EQUIVALENCE')
    # C cannot change an earlier source event or state.
    for arm in (0,2,4,6):
        require(rows[arm]['steps'][0] == rows[arm+1]['steps'][0], 'CONSUMER_RETROCAUSALITY')
    for arm in (0,1,2,3):
        require(source_without_path(rows[arm], 'energy') == source_without_path(rows[arm+4], 'energy'), 'ENERGY_INTERVENTION_LEAK')
    aspect, vow, up, context = key
    source_after = lambda arm: rows[arm]['steps'][0]['after']['combat']
    if source == 'bloodRite':
        for arm in (0,1,4,5):
            require(source_without_path(rows[arm], 'bloodfire') == source_without_path(rows[arm+2], 'bloodfire'), 'MEDIATOR_CHANGED_ORIGINAL_HP_ENERGY_UTILITY')
        expected_energy = 0 if source_after(7)['over'] else (3 if up else 2)
        energy_delta = source_after(7)['player']['energy'] - source_after(3)['player']['energy']
        require(energy_delta == expected_energy, 'BLOODRITE_ENERGY_LAW')
        require(not any(e.get('t') == 'draw' for e in rows[7]['steps'][0]['events']), 'BLOODRITE_MISLABELLED_AS_DRAW')
        delta_m = source_after(7)['player']['statuses'].get('bloodfire',0) - source_after(5)['player']['statuses'].get('bloodfire',0)
        require(delta_m == int(aspect == 1 and not source_after(7)['over']), 'BLOODFIRE_PRODUCER_LAW')
        if aspect == 0:
            for e in (0,4):
                require(all(rows[e]['steps'] == rows[e+i]['steps'] for i in (1,2,3)), 'DUSK_BLOODFIRE_EXACT_NULL')
    else:
        delta_m = len(source_after(7)['hand']) - len(source_after(5)['hand'])
        wanted = 0 if context == 'empty_draw' else (1 if context == 'hand_cap' or source == 'surge' else 2)
        require(delta_m == wanted, 'ACTUAL_DRAW_CAPACITY_LAW')
        if source == 'preparation':
            require(all(rows[i]['steps'] == rows[i+4]['steps'] for i in range(4)), 'PREPARATION_NO_ENERGY_EXACT_NULL')
    all_on = payoff(rows[7]['steps'][1])
    no_mediator = payoff(rows[5]['steps'][1])
    # This is a witness that a necessary activation flag is not causal attribution.
    legacy_proxy = source != 'bloodRite' and rows[7]['steps'][0]['ret'] is True and all_on['eligible'] and all_on['native_hit_amount'] > 0
    source_null_witness = bool(legacy_proxy and delta_m == 0 and rows[7]['steps'] == rows[5]['steps'])
    return {'source':source, 'aspect':aspect, 'vow':vow, 'up':up, 'context':context,
            'source_mediator_difference':delta_m, 'utility_energy_enabled':interaction(rows,True),
            'utility_energy_disabled':interaction(rows,False),
            'all_on_consumer':all_on, 'mediator_off_consumer':no_mediator,
            'necessary_activation_is_not_causal_witness':source_null_witness}


def read(root: Path, expected_source: dict) -> dict:
    summaries = []
    manifests = []
    assignment = set(itertools.product((0,1),(0,5),(False,True),CONTEXTS))
    for source in SOURCES:
        path = root/(source+'.jsonl.xz')
        raw = lzma.decompress(path.read_bytes())
        lines = [json.loads(x) for x in raw.splitlines()]
        require(len(lines) == len(assignment)*9 + 2, 'RAW_COVERAGE:'+source)
        h, tail = lines[0], lines[-1]
        require(h['kind'] == 'header' and h['source'] == source, 'HEADER_SOURCE')
        require(h['content_sha256'] == MIN_CONTENT and h['combat_sha256'] == MIN_COMBAT, 'CURRENT_CANDIDATE_IDENTITY')
        require(h['engine'] == '4.7.2-stable (official)', 'ENGINE_IDENTITY')
        for field, name in [('instrument_sha256','causal_rules.gd'),('probe_sha256','causal_probe.gd')]:
            require(h[field] == expected_source[name], 'INSTRUMENT_IDENTITY')
        require(tail == {'kind':'terminal', 'rows':576}, 'TERMINAL_COVERAGE')
        groups = {}
        for r in lines[1:-1]:
            require(r['kind'] == 'sequence', 'ROW_KIND')
            key = tuple(r[k] for k in KEYS)
            bucket = groups.setdefault(key,{})
            require(r['arm'] not in bucket, 'DUPLICATE_ARM')
            bucket[r['arm']] = r
        require(set(groups) == assignment, 'EXACT_ASSIGNMENT')
        for key in sorted(groups):
            summaries.append(check_group(source,key,groups[key]))
        manifests.append({'path':path.name, 'compressed_bytes':path.stat().st_size,
                          'compressed_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                          'raw_bytes':len(raw), 'raw_sha256':hashlib.sha256(raw).hexdigest()})
    nulls = [r for r in summaries if r['necessary_activation_is_not_causal_witness']]
    require(bool(nulls), 'MISSING_NECESSARY_NOT_SUFFICIENT_NEGATIVE')
    for source in SOURCES:
        positive = [r for r in summaries if r['source'] == source and r['aspect'] == 1 and r['context'] == 'available']
        require(len(positive) == 4 and all(r['utility_energy_enabled']['identified_for_fixed_commands'] and r['utility_energy_enabled']['actual_hp_interaction'] > 0 for r in positive), 'FULL_CHAIN_INCREMENTAL_PAYOFF:'+source)
    return {'status':'SOURCE_UTILITY_AND_MEDIATOR_SEPARATION_QUALIFIED_NOT_CERTIFICATE',
            'fixtures':len(summaries), 'sequence_records':1728, 'native_reference_pairs':len(summaries),
            'raw':manifests, 'source_identity_correction':'BloodRite exchanges 3 HP for 2/3 Energy; it is not a draw producer.',
            'necessary_activation_null_witnesses':len(nulls),
            'interpretation':'The old necessary activation predicate retains its original scope. It cannot be promoted to source-caused payoff evidence.',
            'all_on_matches_unchanged_minimum_runtime':True,
            'eligibility_mismatches_are_not_zero_payoff':True,
            'summaries':summaries, 'new_population_runs':0, 'new_independent_samples':0,
            'packages_admitted':0, 'p9_certified':False,
            'limits':['Constructed, fixed two-command contexts only; not a natural acquisition or adaptive whole-run policy experiment.',
                      'No claim of novelty, optimality, long-horizon utility, new frozen-model accuracy, seed-independent confirmation or full P9.',
                      'The source model and current producer/consumer law are bound; native-versus-shim identity is not an independent product oracle.',
                      'Local commit and bundle durability are not remote byte readback.']}
