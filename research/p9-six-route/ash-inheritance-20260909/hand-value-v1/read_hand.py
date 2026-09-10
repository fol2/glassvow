"""One fixed group-source/Phantom adaptive-value estimand; never P9 admission."""
from collections import Counter
import hashlib
import importlib.util
import json
import math
from pathlib import Path

WORLDS = ('00', '01', '10', '11')
BASE = Path('research/p9-six-route/ash-inheritance-20260909')
BOUNDS = {'active': 32, 'inactive': 32, 'reachable': 16, 'exclusive': 8}


def require(ok, reason):
    if not ok:
        raise ValueError(reason)


def config(first, vow):
    require(type(first) is int and first in range(0, 128, 2), 'CONFIG_INDEX')
    require(type(vow) is int and vow in (0, 5), 'VOW')
    start = 73620100 + 1000 * vow + 4 * (first // 2)
    return {'root': 73409000, 'first': first, 'count': 2,
            'seeds': list(range(start, start + 4)), 'vow': vow, 'integration': False}


def blob(data):
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()


def bootstrap_function(repo):
    path = repo / BASE / 'causal-value-v1/read_causal.py'
    require(blob(path.read_bytes()) == '9113e3f97534aaac29e295d2212abc1eb416b514', 'BOOTSTRAP_SOURCE')
    spec = importlib.util.spec_from_file_location('preserved_bootstrap_only', path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.bootstrap


def blocks_from_rows(rows, vow):
    require(set(rows) == set(WORLDS), 'FOUR_WORLDS')
    expected = {(i, seed) for first in range(0, 128, 2)
                for i in range(first, first + 2) for seed in config(first, vow)['seeds']}
    indexed = {}
    for world in WORLDS:
        require(all(type(r['index']) is int and type(r['seed']) is int for r in rows[world]), 'INTEGER_IDENTITIES')
        indexed[world] = {(r['index'], r['seed']): r for r in rows[world]}
        require(len(rows[world]) == len(indexed[world]) == 512 and set(indexed[world]) == expected,
                'COMPLETE_RECTANGLE:' + world)
        for key, row in indexed[world].items():
            require(row['row']['outcome'] in ('win', 'loss') and not row['row'].get('error'), 'FAULT_NOT_LOSS')
            require(row['vow'] == vow and row['policy'] == indexed['00'][key]['policy'], 'MATCHED_POLICY_CONTEXT')
    by_seed, patterns = {}, Counter()
    for key in sorted(expected):
        y = {w: int(indexed[w][key]['row']['outcome'] == 'win') for w in WORLDS}
        vector = [y['11'] - y['01'], y['11'] - y['10'], y['11'] - y['10'] - y['01'] + y['00']]
        by_seed.setdefault(key[1], []).append(vector)
        patterns[''.join(str(y[w]) for w in WORLDS)] += 1
    require(len(by_seed) == 256 and all(len(v) == 2 for v in by_seed.values()), 'SEED_BLOCKS')
    blocks = [[sum(v[k] for v in by_seed[s]) / 2 for k in range(3)] for s in sorted(by_seed)]
    wins = {w: sum(r['row']['outcome'] == 'win' for r in rows[w]) for w in WORLDS}
    return blocks, wins, dict(sorted(patterns.items()))


def primary(rows, vow, repo):
    blocks, wins, patterns = blocks_from_rows(rows, vow)
    intervals = bootstrap_function(repo)(blocks)
    contrasts = {name: {'point': sum(b[k] for b in blocks) / 256,
                        'interval': intervals[k], 'positive_lower_bound': intervals[k][0] > 0}
                 for k, name in enumerate(('source_group', 'consumer', 'interaction'))}
    return {'rows_per_world': 512, 'policy_configurations': 128, 'distinct_seed_blocks': 256,
            'wins': wins, 'contrasts': contrasts, 'outcome_patterns_00_01_10_11': patterns,
            'primary_pass': all(v['positive_lower_bound'] for v in contrasts.values()),
            'uncertainty': 'Preserved 10000-resample seed-block bootstrap, Random(421), linear Bonferroni percentiles .05/6 and 1-.05/6. Approximate fixed-policy inference, not final P9 error control.'}


def resource_ok(costs):
    return set(costs) == set(WORLDS) and all(math.isfinite(x) and 0 <= x <= 3600 for x in costs.values())


def read_stage(folder, protocols, vow, repo, reader, validate_extra):
    folder = Path(folder)
    rows_by_world, costs, secondary = {}, {}, {}
    for world in WORLDS:
        rows, policies, counts, cpu = [], {}, Counter(), 0.
        for first in range(0, 128, 2):
            cfg = config(first, vow)
            stem = f'v{vow}-{first:03d}'
            root = folder / world
            receipt = json.loads((root / (stem + '.RECEIPT.json')).read_bytes())
            require(receipt['status'] == 'COMPLETE' and receipt['cfg'] == cfg and receipt['rows'] == 8, 'CELL_RECEIPT')
            pair = reader.outcome_records(root / (stem + '.outcomes.jsonl.xz'), cfg, protocols[world])
            validate_extra(pair, 'planner')
            traces, ct = reader.trace_summary(root / (stem + '.traces.jsonl.xz'), {r['row_key'] for r in pair})
            counts.update(ct)
            for row in pair:
                flags = reader.run_flags(row, traces[row['row_key']])
                identity = json.dumps(row['policy'], sort_keys=True, separators=(',', ':'))
                i = row['index']
                if i not in policies:
                    policies[i] = {'identity': identity, **{k: False for k in flags}}
                require(policies[i]['identity'] == identity, 'POLICY_DRIFT')
                for k, value in flags.items():
                    policies[i][k] |= value
            rows.extend(pair)
            values = [receipt['cpu']['user'], receipt['cpu']['system']]
            require(all(math.isfinite(x) and x >= 0 for x in values), 'CPU_IDENTITY')
            cpu += sum(values)
        require(len(policies) == 128 and len({v['identity'] for v in policies.values()}) == 128, 'POLICY_COVERAGE')
        rows_by_world[world], costs[world] = rows, cpu
        secondary[world] = {'historical_necessary_pattern_only': reader.support_decision(policies, BOUNDS),
                            'clone_counts': dict(counts),
                            'limits': 'Post-treatment, not source causality or independent confirmation. Suppressed Phantom coefficient can retain Strength damage; ordinary/background draw stays enabled.'}
    result = primary(rows_by_world, vow, repo)
    result.update(vow=vow, cpu_seconds=costs, resource_pass=resource_ok(costs),
                  pass_all=result['primary_pass'] and resource_ok(costs), secondary=secondary,
                  packages_admitted=0, p9_certified=False,
                  scope='Joint direct Preparation/Surge draw group and Phantom payoff at the unchanged audit policy. Not separate producer-variant necessity or full package admission.')
    result['status'] = 'HAND_ADAPTIVE_GROUP_VALUE_SUPPORTED_NOT_CERTIFICATE' if result['pass_all'] else 'HAND_ADAPTIVE_GROUP_VALUE_NOT_ESTABLISHED'
    return result
