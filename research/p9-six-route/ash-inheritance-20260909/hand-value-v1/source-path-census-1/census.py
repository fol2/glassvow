"""Complete post-observation mechanism census, not a new test or admission.

Uses every assigned Hand four-world run. The frozen win estimand, interval,
cohort and negative terminal are not changed. Does not invoke an engine.
"""
from __future__ import annotations
from collections import Counter
import hashlib
import importlib.util
import json
import lzma
from pathlib import Path
import subprocess
import sys

BASE = Path('research/p9-six-route/ash-inheritance-20260909')
STUDY = BASE / 'hand-value-v1'
WORLDS = ('00', '01', '10', '11')
SOURCES = frozenset(('preparation', 'surge'))
EXPECTED_TERMINAL = 'df7a4da6db2e61dcd69e50406194a1430e13de16'
EXPECTED_DESCRIPTOR = 'f41337fb6a0ea7fa91a0e2ede26ebf0670cd724b'


def require(condition, reason):
    if not condition:
        raise ValueError(reason)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def blob(data):
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()


def load(path):
    return json.loads(path.read_bytes())


def save(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')


def path_safe(value):
    require(isinstance(value, str) and value and '\\' not in value, 'PATH')
    p = Path(value)
    require(not p.is_absolute() and '..' not in p.parts and p.as_posix() == value and value != '.', 'PATH')
    return p


def keyset(vow=5):
    return {f'{vow}:{i}:{73620100 + 1000*vow + 4*(i//2)+j}' for i in range(128) for j in range(4)}


def parse_key(key):
    pieces = key.split(':')
    require(len(pieces) == 3 and all(p.isdecimal() for p in pieces), 'ROW_KEY')
    return tuple(map(int, pieces))


def ids(hand):
    values = [c['uid'] for c in hand]
    require(all(type(x) is int for x in values) and len(values) == len(set(values)), 'HELD_IDENTITIES')
    return values


def update_origins(events, card, legal, origins):
    """Pinned event ordering: direct source draw before its Exhaust/relic hook."""
    after_exhaust = False
    direct = 0
    for event in events:
        if event.get('t') == 'exhaust':
            after_exhaust = True
        if event.get('t') == 'draw':
            u = event['uid']
            require(type(u) is int, 'DRAW_IDENTITY')
            origin = card if card in SOURCES and legal and not after_exhaust else 'background'
            origins[u] = origin
            direct += int(origin in SOURCES)
    return direct


class Tracker:
    def __init__(self, world, expected):
        require(world in WORLDS, 'WORLD')
        self.world, self.expected = world, expected
        self.runs = {}
        self.current, self.fight, self.prior = None, None, None
        self.sequence, self.origins = 0, {}
        self.fields = []

    def feed(self, record):
        key = record['row_key']
        require(key in self.expected, 'UNASSIGNED_ROW')
        if key != self.current:
            require(key not in self.runs, 'DUPLICATE_RUN')
            self.current, self.fight, self.prior = key, None, None
            self.sequence, self.origins = 0, {}
            self.runs[key] = dict(commands=0, direct_source_draws=0, phantom_plays=0,
                                  retained_source_plays=0, source_access_plays=0,
                                  either_source_path_plays=0)
        require(record['kind'] == 'command' and type(record['sequence']) is int
                and record['sequence'] == self.sequence and record['original_untouched_by_clones'] is True,
                'COMMAND_IDENTITY')
        self.sequence += 1
        before, after = ids(record['before']['hand']), ids(record['after']['hand'])
        require(self.prior is None or self.prior == before, 'HAND_CONTINUITY')
        if record['fight'] != self.fight:
            self.origins = {}
            self.fight = record['fight']
        info = self.runs[key]
        info['commands'] += 1
        if record['card'] == 'phantomBlades' and record['ret'] is True:
            uid = record['command']['uid']
            require(uid in before, 'CONSUMER_NOT_HELD')
            other = sum(u != uid and self.origins.get(u) in SOURCES for u in before)
            access = self.origins.get(uid) in SOURCES
            require(self.world[0] == '1' or (other == 0 and not access), 'SOURCE_OFF_PROVENANCE')
            info['phantom_plays'] += 1
            info['retained_source_plays'] += int(other > 0)
            info['source_access_plays'] += int(access)
            info['either_source_path_plays'] += int(other > 0 or access)
            self.fields.append(dict(world=self.world, row_key=key, sequence=record['sequence'],
                                    retained_direct_source_instances=other, source_drew_consumer=access,
                                    consumer_factor_assigned=self.world[1] == '1'))
        direct = update_origins(record['events'], record['card'], record['ret'] is True, self.origins)
        require(self.world[0] == '1' or direct == 0, 'DIRECT_DRAW_LEAK_IN_OFF_WORLD')
        info['direct_source_draws'] += direct
        self.origins = {u: origin for u, origin in self.origins.items() if u in after}
        self.prior = after

    def finish(self):
        require(set(self.runs) == self.expected, 'INCOMPLETE_ASSIGNMENT')
        return self.runs


def response_patterns(rows):
    require(set(rows) == set(WORLDS), 'FOUR_WORLDS')
    expected = keyset()
    require(all(set(rows[w]) == expected for w in WORLDS), 'MATCHED_RECTANGLE')
    patterns, distributions = Counter(), {n: Counter() for n in ('source', 'consumer', 'interaction')}
    wins = {w: 0 for w in WORLDS}
    for key in sorted(expected):
        y = [rows[w][key] for w in WORLDS]
        require(all(type(x) is int and x in (0, 1) for x in y), 'BINARY_OUTCOME')
        patterns[''.join(map(str, y))] += 1
        for w, v in zip(WORLDS, y):
            wins[w] += v
        for name, v in zip(distributions, (y[3]-y[1], y[3]-y[2], y[3]-y[2]-y[1]+y[0])):
            distributions[name][v] += 1
    return {'wins': wins, 'patterns': dict(sorted(patterns.items())),
            'paired_response_distributions': {n: {str(k): v for k, v in sorted(c.items())}
                                                for n, c in distributions.items()},
            'counts_not_independent_samples': True}


def run(repo, output):
    require(not output.exists(), 'OUTPUT_EXISTS')
    capture = repo / STUDY / 'execution-1'
    terminal_bytes = (capture / 'TERMINAL.json').read_bytes()
    require(blob(terminal_bytes) == EXPECTED_TERMINAL, 'TERMINAL_IDENTITY')
    terminal = json.loads(terminal_bytes)
    require(terminal['status'] == 'HAND_ADAPTIVE_GROUP_VALUE_NOT_ESTABLISHED'
            and terminal['v0_skipped'] is True and not (capture/'v0').exists(), 'PRESERVED_TERMINAL')
    proof = load(capture / 'REMOTE-READBACK.json')
    require(proof['all_bytes_equal'] is True and proof['scientific_status'] == terminal['status'], 'READBACK')
    require(blob((repo / BASE / 'hand-adaptive-v1/descriptor.py').read_bytes()) == EXPECTED_DESCRIPTOR,
            'PROVENANCE_DEFINITION_CHANGED')
    entries = {r['path']: r for r in load(capture / 'FILES.json')}
    consulted = {}
    def bound(relative):
        path = capture / path_safe(relative)
        b = path.read_bytes(); r = entries[relative]
        require(len(b) == r['bytes'] and sha(b) == r['sha256'], 'INPUT_BYTES:' + relative)
        consulted[relative] = r
        return path
    sys.path.insert(0, str(repo / STUDY))
    import run_hand
    import read_hand
    _, value, _, reader = run_hand.dependencies(repo)
    run_hand.validate_contract(load(repo / STUDY / 'CONTRACT.json'))
    protocols = load(bound('RESOLVED-PROTOCOLS.json'))
    expected = keyset()
    outcomes, census, fields, all_runs = {}, {}, [], {}
    for world in WORLDS:
        tracker = Tracker(world, expected)
        outcomes[world] = {}
        for first in range(0, 128, 2):
            stem = f'v5/{world}/v5-{first:03d}'
            cfg = read_hand.config(first, 5)
            records = reader.outcome_records(bound(stem + '.outcomes.jsonl.xz'), cfg, protocols[world])
            value.read_value.validate_extra(records, 'planner')
            for r in records:
                key = r['row_key']
                require(key not in outcomes[world] and key == f"5:{r['index']}:{r['seed']}", 'OUTCOME_IDENTITY')
                require(r['row']['outcome'] in ('win', 'loss') and not r['row'].get('error'), 'OUTCOME_FAULT')
                outcomes[world][key] = int(r['row']['outcome'] == 'win')
            path = bound(stem + '.traces.jsonl.xz')
            with lzma.open(path, 'rt', encoding='utf-8') as stream:
                for line in stream:
                    require(line.strip(), 'EMPTY_TRACE_RECORD')
                    r = json.loads(line)
                    try:
                        tracker.feed(r)
                    except ValueError as exc:
                        detail = {k: r.get(k) for k in ('row_key', 'sequence', 'fight', 'card', 'events')}
                        raise ValueError(str(exc) + ':' + json.dumps(detail, sort_keys=True)) from exc
        runs = tracker.finish()
        all_runs[world] = runs
        fields.extend(tracker.fields)
        totals = Counter()
        for r in runs.values(): totals.update(r)
        census[world] = {'runs': len(runs), 'totals': dict(totals),
            'configurations_with_retained_source': len({parse_key(k)[1] for k,r in runs.items() if r['retained_source_plays']}),
            'configurations_with_source_access': len({parse_key(k)[1] for k,r in runs.items() if r['source_access_plays']}),
            'configurations_with_either_factual_path': len({parse_key(k)[1] for k,r in runs.items() if r['either_source_path_plays']})}
    responses = response_patterns(outcomes)
    stage = terminal['stages']['5']
    require(responses['wins'] == stage['wins'] and responses['patterns'] == stage['outcome_patterns_00_01_10_11'], 'PRIMARY_RECONCILIATION')
    output.mkdir(parents=True)
    with (output/'FIELDS.jsonl').open('w') as f:
        for r in fields: f.write(json.dumps(r, sort_keys=True) + '\n')
    save(output/'RUN-COVERAGE.json', all_runs)
    result = {'kind': 'FULL_ASSIGNED_HAND_SOURCE_PATH_CENSUS_NOT_NEW_INFERENCE',
        'source_evidence_head': 'a5891c3315bab3a7017595512566977b49f45632',
        'runs_read': sum(x['runs'] for x in census.values()), 'worlds': census,
        'paired_responses': responses, 'immutable_primary_terminal': terminal['status'],
        'observed_source_off_draw_leaks': 0, 'observed_source_off_provenance_leaks': 0,
        'limits': ['Post-observation complete census; no primary metric, interval or stopping rule changes.',
            'Factual direct-draw provenance is not counterfactual marginal value or an admitted descriptor.',
            'Aon/Boff can still draw and play Phantom. Boff can still have ordinary Strength/hit effects; zero HP is not asserted.',
            'Consumer factor in FIELDS is assignment metadata, not an independently measured effect.',
            'Configuration counts overlap and are not extra independent samples; no post-treatment subset is promoted.',
            'Absence of these leakage defects cannot prove planner optimality, equivalence, global package futility or final P9.'],
        'review_kind': 'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT', 'new_native_runs': 0,
        'new_independent_samples': 0, 'packages_admitted': 0, 'p9_certified': False}
    save(output/'RESULTS.json', result)
    save(output/'INPUTS.json', consulted)
    save(output/'FILES.json', [{'path': p.name, 'bytes': p.stat().st_size, 'sha256': sha(p.read_bytes())}
                               for p in sorted(output.iterdir()) if p.is_file()])
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    if len(sys.argv) != 3:
        raise SystemExit('census.py REPO NEW_OUTPUT')
    run(*(Path(s).resolve() for s in sys.argv[1:]))
