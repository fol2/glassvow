"""Source-bound signed RandomBuild guardrail screen. Never a P9 certificate."""
from __future__ import annotations
from collections import Counter
import hashlib
import json
import lzma
from pathlib import Path
import random


def require(ok, why):
    if not ok:
        raise ValueError(why)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def specifications(protocol):
    return [dict(id=f'{cat}-{aspect}-v{vow}', catalogue=cat, aspect=aspect,
                 vow=vow, arm=2, seed0=protocol['seed0'], runs=protocol['seeds_per_grid'])
            for cat in ('baseline', 'candidate') for aspect in ('duskblade', 'ashwarden') for vow in (0, 5)]


def validate(rows, cfg, protocol):
    header, outcomes = rows[0], rows[1:]
    require(header['kind'] == 'header' and header['config'] == cfg, 'CONFIG')
    require(header['signed_arm'] == {'random_build': True, 'random_play': False, 'ban': []}, 'SIGNED_ARM')
    require(header['engine'] == '4.7.2-stable (official)', 'ENGINE')
    require(header['content_sha256'] == protocol['content_sha256'][cfg['catalogue']], 'CONTENT')
    require(header['combat_sha256'] == protocol['combat_sha256'][cfg['catalogue']], 'COMBAT')
    require(header['sources'] == protocol['tool_sha256'], 'TOOLS')
    require(header['driver_sha256'] == protocol['source_sha256']['probe.gd'], 'DRIVER')
    require(sha(json.dumps(header['policy'],sort_keys=True,separators=(',',':')).encode()) == protocol['resolved_policy_sha256'], 'DEFAULT_SIGNED_POLICY')
    require(len(outcomes) == cfg['runs'], 'COUNT')
    require([r['seed'] for r in outcomes] == list(range(cfg['seed0'], cfg['seed0'] + cfg['runs'])), 'SEED_ORDER')
    for row in outcomes:
        require(row['aspect'] == cfg['aspect'] and row['vow'] == cfg['vow'] and row['arm'] == 2, 'CONTEXT')
        require(row['policy'] == header['policy'], 'POLICY')
        require(row['outcome'] in ('win', 'loss', 'stall', 'error'), 'OUTCOME')
        if row['outcome'] == 'win':
            require(row['hp'] > 0 and row['fights'] and row['fights'][-1]['act'] == 3
                    and row['fights'][-1]['kind'] == 'boss'
                    and all(f['result'] == 'win' for f in row['fights']), 'VALID_WIN')
    return outcomes, header['policy']


def paired_interval(differences, repetitions=5000):
    """Fixed nominal paired percentile interval, report-only, never an extra gate."""
    rng = random.Random(421); n = len(differences)
    values = sorted(sum(differences[rng.randrange(n)] for _ in range(n)) / n
                    for _ in range(repetitions))
    return [values[int(.025 * (repetitions - 1))], values[int(.975 * (repetitions - 1))]]


def arithmetic(baseline, candidate):
    require(len(baseline) == len(candidate) and baseline, 'PAIRED_COVERAGE')
    require(all(type(x) is bool for x in baseline + candidate), 'BINARY_OUTCOMES')
    n = len(baseline); b, c = sum(baseline), sum(candidate)
    # Integer arithmetic avoids accidental boundary failures at exactly 0.1.
    gates = {'candidate_random_build_at_most_half': 2 * c <= n,
             'absolute_random_build_movement_at_most_tenth': 10 * abs(c - b) <= n}
    return {'n': n, 'baseline_wins': b, 'candidate_wins': c,
            'difference': (c-b)/n, 'gates': gates,
            'paired_discordance': dict(Counter(int(y)-int(x) for x, y in zip(baseline, candidate)))}


def analyze(folder, protocol):
    folder = Path(folder); cells = {}; policies = set(); evidence = []
    expected = specifications(protocol)
    available = list(folder.glob('*.ndjson')) + list(folder.glob('*.ndjson.xz'))
    names = [p.name.removesuffix('.xz').removesuffix('.ndjson') for p in available]
    require(len(names) == len(expected) and set(names) == {c['id'] for c in expected}, 'COMPLETE_RECTANGLE')
    for cfg in expected:
        path = folder / (cfg['id'] + '.ndjson')
        if path.exists():
            raw = path.read_bytes()
        else:
            path = path.with_suffix(path.suffix + '.xz'); raw = lzma.decompress(path.read_bytes())
        require(len(raw) <= protocol['containment']['raw_bytes_per_cell'], 'RAW_CAP')
        rows, policy = validate([json.loads(x) for x in raw.splitlines()], cfg, protocol)
        policies.add(json.dumps(policy, sort_keys=True, separators=(',', ':')))
        cells[cfg['id']] = rows
        evidence.append({'path': cfg['id'] + '.ndjson', 'bytes': len(raw), 'sha256': sha(raw)})
    require(len(policies) == 1, 'SAME_SIGNED_POLICY')
    result = []
    for aspect in ('duskblade', 'ashwarden'):
        for vow in (0, 5):
            b = cells[f'baseline-{aspect}-v{vow}']; c = cells[f'candidate-{aspect}-v{vow}']
            r = arithmetic([x['outcome']=='win' for x in b], [x['outcome']=='win' for x in c])
            r.update(aspect=aspect, vow=vow,
                     candidate_outcomes=dict(Counter(x['outcome'] for x in c)),
                     baseline_outcomes=dict(Counter(x['outcome'] for x in b)))
            r['gates']['candidate_fault_free'] = all(x['outcome'] not in ('error','stall') and not x['error'] for x in c)
            r['baseline_faults'] = sum(x['outcome'] in ('error','stall') or bool(x['error']) for x in b)
            require(r['baseline_faults'] == 0, 'REFERENCE_FAULT_NO_VALID_COMPARISON')
            r['nominal_paired_interval_report_only'] = paired_interval([int(y['outcome']=='win')-int(x['outcome']=='win') for x,y in zip(b,c)])
            result.append(r)
    okay = all(all(r['gates'].values()) for r in result)
    return {'status': 'SIGNED_CONTROL_NECESSARY_SCREEN_PASS_NOT_P9' if okay else 'SIGNED_CONTROL_NECESSARY_SCREEN_FAIL',
            'grids': result, 'full_raw': evidence, 'rows': sum(len(x) for x in cells.values()),
            'protocol_role': 'Prospective exact-candidate necessary guardrail screen, not a release or independent package certificate.',
            'decision': ('Continue missing package confirmation; no gate is admitted by this screen alone.' if okay else
                         'This fixed candidate cannot advance through this registered guardrail screen. Preserve the failed grid and all old evidence; no extension, weaker comparator or retune in this protocol.'),
            'limits': ['Not the balanced research controller. Only the unchanged signed arm2 is compared.',
                       'Point-scale inherited screen and fixed paired intervals are separate; intervals do not override the frozen decision.',
                       'No causal attribution of a catalogue-wide change to Hand alone.',
                       'No C2 strategy gap, duration, policy-ceiling, detector, retention or full P9 assertion.'],
            'packages_admitted': 0, 'p9_certified': False}


if __name__ == '__main__':
    import sys
    print(json.dumps(analyze(sys.argv[1], json.loads(Path(sys.argv[2]).read_bytes())), indent=2))
