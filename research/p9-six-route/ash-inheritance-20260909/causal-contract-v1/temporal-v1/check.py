"""Source-occurrence attribution and complete finite native reconstruction.
This is a task-local observation checker, never a package or P9 admission gate.
"""
from __future__ import annotations
import hashlib
import itertools
import json
import lzma
from pathlib import Path

SCENARIOS = ('spend_one', 'unrelated_play', 'wait_turn', 'repeat_consumer')
ARMS = (-1, 0, 1, 2, 3)
KEYS = ('source', 'aspect', 'vow', 'up', 'scenario')
PASS = 'TEMPORAL_HAND_ATTRIBUTION_QUALIFIED_NOT_CERTIFICATE'
CONTENT = '4107c7c0bbed5d9acf8c2bdf97023552426920242ea958c8ebdec793b712afd9'
COMBAT = '3ccb89f69f50e41d5a46eadd8f48c0a907fd0e382cd492b2c34dd5f93e091ad0'


def require(ok, why):
    if not ok:
        raise ValueError(why)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def integer(x):
    require(type(x) is int, 'INTEGER_NOT_BOOL_OR_FLOAT')
    return x


def hand(state):
    cards = state['combat']['hand']
    result = {integer(c['uid']): c for c in cards}
    require(len(result) == len(cards), 'DUPLICATE_HAND_UID')
    return result


def assignment():
    return {(s, a, v, u, q)
            for s in ('preparation', 'surge')
            for a, v, u in itertools.product((0, 1), (0, 5), (False, True))
            for q in SCENARIOS + (('spend_all',) if s == 'preparation' else ())}


def useful_hp(step):
    require(step['ret'] is True, 'REJECTED_ACTION_NOT_ZERO')
    target = integer(step['command']['target'])
    before = {integer(e['idx']): e for e in step['before']['combat']['enemies']}
    after = {integer(e['idx']): e for e in step['after']['combat']['enemies']}
    require(target in before and target in after, 'TARGET_IDENTITY')
    return max(integer(before[target]['hp']), 0) - max(integer(after[target]['hp']), 0)


def descriptor(steps, source_uid=900):
    """Credit belongs to a draw OCCURRENCE, not an eternally labelled card UID.

    Reading hand size does not spend other cards. Leaving hand/endTurn does.
    A later draw of the same UID by another source does not revive old credit.
    This observation alone is not a causal effect; the factorial checks it below.
    """
    credit, records = {}, []
    for index, step in enumerate(steps):
        before, after, cmd = step['before'], step['after'], step['command']
        pre_hand, post_hand = hand(before), hand(after)
        credit = {uid: origin for uid, origin in credit.items() if uid in pre_hand}
        if cmd['t'] == 'playCard':
            uid = integer(cmd['uid'])
            require(uid in pre_hand and step['ret'] is True, 'REJECTED_OR_ABSENT_PLAY')
            if pre_hand[uid]['id'] == 'phantomBlades':
                live = sorted(x for x in credit if x != uid)
                records.append({'step': index, 'consumer_uid': uid,
                    'turn': integer(before['combat']['turn']),
                    'hand_units_read': len(pre_hand) - 1,
                    'surviving_source_uids': live,
                    'source_occurrences': [credit[x] for x in live],
                    'consumer_was_source_drawn': uid in credit,
                    'useful_hp_removed': useful_hp(step)})
        is_source = cmd.get('t') == 'playCard' and cmd.get('uid') == source_uid
        for event_index, event in enumerate(step['events']):
            kind = event.get('t')
            if kind in ('endTurn', 'discardHand', 'turn'):
                credit.clear()
            elif kind in ('play', 'exhaust', 'kindle', 'toDiscard') and 'uid' in event:
                credit.pop(integer(event['uid']), None)
            elif kind == 'draw' and is_source:
                uid = integer(event['uid'])
                require(uid not in credit, 'DUPLICATE_DRAW_OCCURRENCE')
                credit[uid] = {'source_uid': source_uid, 'step': index,
                              'event': event_index, 'turn': integer(after['combat']['turn'])}
        if before['combat']['turn'] != after['combat']['turn']:
            credit.clear()
        credit = {uid: origin for uid, origin in credit.items() if uid in post_hand}
    return records


def expected_commands(row):
    source, _, _, _, scenario = (row[k] for k in KEYS)
    enabled = row['arm'] in (-1, 2, 3)
    draws = ([965, 964] if source == 'preparation' else [965]) if enabled else []
    commands = [{'t': 'playCard', 'uid': 900, 'target': None}]
    if scenario == 'spend_one':
        commands += [{'t': 'playCard', 'uid': uid, 'target': None} for uid in draws[:1]]
    elif scenario == 'spend_all':
        commands += [{'t': 'playCard', 'uid': uid, 'target': None} for uid in draws]
    elif scenario == 'unrelated_play':
        commands.append({'t': 'playCard', 'uid': 920, 'target': 0})
    elif scenario == 'wait_turn':
        commands.append({'t': 'endTurn'})
    commands.append({'t': 'playCard', 'uid': 901, 'target': 0})
    if scenario == 'repeat_consumer':
        commands.append({'t': 'playCard', 'uid': 902, 'target': 0})
    return commands, draws


def check_trajectory(row):
    require(row['kind'] == 'temporal', 'ROW_KIND')
    require(type(row['up']) is bool, 'UPGRADE_IDENTITY')
    for field in ('aspect', 'vow', 'arm'):
        integer(row[field])
    commands, draws = expected_commands(row)
    require([s['command'] for s in row['steps']] == commands, 'DECLARED_ADAPTIVE_SCRIPT')
    current = row['start']
    for step in row['steps']:
        require(step['before'] == current, 'COMMAND_CONTINUITY')
        require(step['ret'] == step['after']['return'], 'RETURN_BINDING')
        before, after = step['before']['combat'], step['after']['combat']
        q = before['queue']
        require(after['queue'][:len(q)] == q and after['queue'][len(q):] == step['events'], 'EVENT_BINDING')
        for state in (step['before'], step['after']):
            cb = state['combat']
            uids = [integer(c['uid']) for p in ('hand', 'draw', 'discard', 'exhaust') for c in cb[p]]
            require(len(uids) == len(set(uids)), 'CROSS_PILE_UID')
            require(not cb['over'], 'CONSTRUCTED_COMBAT_ENDED')
        if step['command']['t'] == 'playCard':
            require(step['ret'] is True, 'REJECTED_ACTION_NOT_ZERO')
        else:
            require(step['ret'] is None, 'END_TURN_RETURN')
        current = step['after']
    require(current == row['end'], 'END_BINDING')
    actual_draws = [e['uid'] for e in row['steps'][0]['events'] if e.get('t') == 'draw']
    require(actual_draws == draws, 'SOURCE_DRAW_LAW')
    seen = descriptor(row['steps'])
    expected_credit = len(draws)
    if row['scenario'] == 'spend_one':
        expected_credit = max(0, expected_credit - 1)
    elif row['scenario'] in ('spend_all', 'wait_turn'):
        expected_credit = 0
    expected_consumers = [901, 902] if row['scenario'] == 'repeat_consumer' else [901]
    require([r['consumer_uid'] for r in seen] == expected_consumers, 'CONSUMER_COVERAGE')
    require(all(len(r['surviving_source_uids']) == expected_credit for r in seen), 'TEMPORAL_CREDIT')
    require(all(not r['consumer_was_source_drawn'] for r in seen), 'UNDECLARED_ELIGIBILITY_CHANNEL')
    return seen


def group(rows):
    require(set(rows) == set(ARMS), 'FIVE_WORLD_COVERAGE')
    key = tuple(rows[-1][k] for k in KEYS)
    for arm, row in rows.items():
        require(row['arm'] == arm and tuple(row[k] for k in KEYS) == key, 'GROUP_IDENTITY')
        require(row['start'] == rows[-1]['start'], 'MATCHED_INITIAL_NATIVE_STATE')
    require(rows[3]['steps'] == rows[-1]['steps'] and rows[3]['end'] == rows[-1]['end'], 'ALL_ON_NATIVE_REFERENCE')
    for off, on in ((0, 1), (2, 3)):
        require(rows[off]['steps'][0] == rows[on]['steps'][0], 'CONSUMER_RETROCAUSALITY')
    source_energy = [r['steps'][0]['after']['combat']['player']['energy'] for r in rows.values()]
    require(len(set(source_energy)) == 1, 'SOURCE_ENERGY_NOT_PRESERVED')
    descriptions = {a: check_trajectory(r) for a, r in rows.items()}
    contrasts = []
    for index, record in enumerate(descriptions[3]):
        payoffs = {a: descriptions[a][index]['useful_hp_removed'] for a in range(4)}
        interaction = payoffs[3] - payoffs[2] - payoffs[1] + payoffs[0]
        units = len(record['surviving_source_uids'])
        coefficient = 4 if key[3] else 3
        require(interaction == coefficient * units, 'NATIVE_TEMPORAL_PAYOFF_INTERACTION')
        contrasts.append({'consumer_uid': record['consumer_uid'], 'source_units': units,
                          'interaction_useful_hp': interaction, 'world_payoffs': payoffs})
    return dict(zip(KEYS, key), contrasts=contrasts, descriptors=descriptions)


def read(path, runtime, probe_sha):
    compressed = Path(path).read_bytes()
    raw = lzma.decompress(compressed)
    records = [json.loads(line) for line in raw.splitlines()]
    require(len(records) == 362, 'RAW_RECORD_COUNT')
    header, terminal = records[0], records[-1]
    require(header['kind'] == 'header' and header['is_constructed'] is True
            and header['new_population_runs'] == 0, 'HEADER_SCOPE')
    require(header['content_sha256'] == CONTENT and header['combat_sha256'] == COMBAT, 'RUNTIME_IDENTITY')
    require(header['engine'] == '4.7.2-stable (official)', 'ENGINE_VERSION')
    require(header['probe_sha256'] == probe_sha, 'PROBE_IDENTITY')
    for field, path in (('instrument_sha256', 'causal_rules.gd'), ('base_probe_sha256', 'causal_probe.gd')):
        require(header[field] == runtime[path]['sha256'], 'INHERITED_SOURCE_IDENTITY')
    require(terminal == {'kind': 'terminal', 'rows': 360}, 'TERMINAL_ASSIGNMENT')
    grouped = {}
    for row in records[1:-1]:
        require(type(row['up']) is bool, 'UPGRADE_IDENTITY')
        for name in ('aspect', 'vow', 'arm'):
            integer(row[name])
        key = tuple(row[k] for k in KEYS)
        require(key in assignment() and row['arm'] in ARMS, 'UNASSIGNED_ROW')
        bucket = grouped.setdefault(key, {})
        require(row['arm'] not in bucket, 'DUPLICATE_WORLD')
        bucket[row['arm']] = row
    require(set(grouped) == assignment(), 'COMPLETE_FIXTURE_ASSIGNMENT')
    summaries = [group(grouped[k]) for k in sorted(grouped)]
    return {'status': PASS, 'fixtures': 72, 'trajectories': 360, 'native_reference_pairs': 72,
            'consumer_contrasts': sum(len(r['contrasts']) for r in summaries),
            'raw_sha256': sha(raw), 'raw_bytes': len(raw), 'compressed_sha256': sha(compressed),
            'summaries': summaries, 'new_population_runs': 0, 'new_independent_samples': 0,
            'packages_admitted': 0, 'p9_certified': False,
            'scope': 'Finite temporal observation qualification only; not independent descriptor prediction, package value, natural economy, peer-policy separation or P9.'}
