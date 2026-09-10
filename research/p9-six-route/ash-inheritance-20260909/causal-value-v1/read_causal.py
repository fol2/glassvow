"""Fixed four-world adaptive value readout; no package/P9 admission by itself."""
from collections import Counter
import json
import math
from pathlib import Path
import random

WORLDS = ('00', '01', '10', '11')
CONTRASTS = ('producer', 'consumer', 'interaction')
BOUNDS = {'active': 32, 'inactive': 32, 'reachable': 16, 'exclusive': 8}


def require(ok, why):
    if not ok:
        raise ValueError(why)


def config(first, vow):
    require(type(first) is int and first in range(0, 128, 2), 'CONFIG_INDEX')
    require(vow in (0, 5), 'VOW')
    start = 73520100 + 1000 * vow + 4 * (first // 2)
    return {'root': 73409000, 'first': first, 'count': 2,
            'seeds': list(range(start, start + 4)), 'vow': vow, 'integration': False}


def quantile(ordered, q):
    position = (len(ordered) - 1) * q
    lo = int(position)
    return ordered[lo] + (ordered[min(lo + 1, len(ordered) - 1)] - ordered[lo]) * (position - lo)


def bootstrap(blocks):
    require(len(blocks) == 256, 'SEED_BLOCK_COUNT')
    require(all(len(b) == 3 and all(math.isfinite(x) for x in b) for b in blocks), 'FINITE_CONTRASTS')
    rng = random.Random(421)
    distributions = [[], [], []]
    for _ in range(10000):
        totals = [0., 0., 0.]
        for _ in blocks:
            b = blocks[rng.randrange(len(blocks))]
            for k in range(3):
                totals[k] += b[k]
        for k in range(3):
            distributions[k].append(totals[k] / len(blocks))
    intervals = []
    for values in distributions:
        values.sort()
        intervals.append([quantile(values, .05 / 6), quantile(values, 1 - .05 / 6)])
    return intervals


def primary(rows, vow):
    require(set(rows) == set(WORLDS), 'FOUR_WORLDS')
    expected = {(i, s) for first in range(0, 128, 2)
                for i in range(first, first + 2) for s in config(first, vow)['seeds']}
    indexed = {}
    for world in WORLDS:
        indexed[world] = {(r['index'], r['seed']): r for r in rows[world]}
        require(len(rows[world]) == len(indexed[world]) == 512 and set(indexed[world]) == expected,
                'COMPLETE_UNIQUE_RECTANGLE:' + world)
        for key, row in indexed[world].items():
            require(row['row']['outcome'] in ('win', 'loss') and not row['row'].get('error'), 'FAULT_NOT_LOSS')
            require(row['vow'] == vow, 'ROW_VOW')
            require(row['policy'] == indexed['00'][key]['policy'], 'MATCHED_POLICY')
    by_seed = {}
    outcome_patterns = Counter()
    for key in sorted(expected):
        y = {m: int(indexed[m][key]['row']['outcome'] == 'win') for m in WORLDS}
        vector = [y['11'] - y['01'], y['11'] - y['10'], y['11'] - y['10'] - y['01'] + y['00']]
        by_seed.setdefault(key[1], []).append(vector)
        outcome_patterns[''.join(str(y[m]) for m in WORLDS)] += 1
    require(len(by_seed) == 256 and all(len(v) == 2 for v in by_seed.values()), 'MATCHED_SEED_BLOCKS')
    blocks = [[sum(v[k] for v in by_seed[s]) / 2 for k in range(3)] for s in sorted(by_seed)]
    intervals = bootstrap(blocks)
    contrasts = {name: {'point': sum(b[k] for b in blocks) / 256,
                        'bonferroni_percentile_interval': intervals[k],
                        'positive_lower_bound': intervals[k][0] > 0}
                 for k, name in enumerate(CONTRASTS)}
    return {'rows_per_world': 512, 'policy_configurations': 128, 'distinct_seed_blocks': 256,
            'wins': {m: sum(r['row']['outcome'] == 'win' for r in rows[m]) for m in WORLDS},
            'contrasts': contrasts, 'primary_pass': all(c['positive_lower_bound'] for c in contrasts.values()),
            'outcome_patterns_world_order_00_01_10_11': dict(sorted(outcome_patterns.items())),
            'uncertainty': '10000 resamples of complete two-policy seed blocks, Random(421); linear percentile interpolation. Nominal simultaneous95% Bonferroni intervals for three contrasts; approximate bootstrap, not exact finite-sample or final P9 error control.'}


def resource_ok(costs):
    return set(costs) == set(WORLDS) and all(math.isfinite(v) and 0 <= v <= 3600 for v in costs.values())


def read_stage(folder, protocols, vow, reader, validate_extra):
    folder = Path(folder)
    all_rows, costs, support = {}, {}, {}
    for world in WORLDS:
        rows, policies, counts, durations = [], {}, Counter(), []
        cpu = 0.
        for first in range(0, 128, 2):
            cfg = config(first, vow)
            stem = f'v{vow}-{first:03d}'
            root = folder / world
            receipt = json.loads((root / (stem + '.RECEIPT.json')).read_bytes())
            require(receipt['status'] == 'COMPLETE' and receipt['cfg'] == cfg and receipt['rows'] == 8,
                    'CELL_RECEIPT:' + world + '/' + stem)
            pair = reader.outcome_records(root / (stem + '.outcomes.jsonl.xz'), cfg, protocols[world])
            validate_extra(pair, 'planner')
            traces, ct = reader.trace_summary(root / (stem + '.traces.jsonl.xz'), {r['row_key'] for r in pair})
            counts.update(ct)
            for r in pair:
                flags = reader.run_flags(r, traces[r['row_key']])
                if world[0] == '0':
                    require(traces[r['row_key']]['bloodfire_applied'] == 0 and traces[r['row_key']]['bloodfire_consumed'] == 0,
                            'SOURCE_OFF_NONZERO_CHARGE')
                if world[1] == '0':
                    require(traces[r['row_key']]['bloodfire_consumed'] == 0, 'CONSUMER_OFF_CONSUMED')
                identity = json.dumps(r['policy'], sort_keys=True, separators=(',', ':'))
                if r['index'] not in policies:
                    policies[r['index']] = {'identity': identity, **{k: False for k in flags}}
                require(policies[r['index']]['identity'] == identity, 'POLICY_DRIFT')
                for k, v in flags.items():
                    policies[r['index']][k] |= v
                durations.append({'row_key': r['row_key'], 'run_usec': r['run_usec'],
                                  'queries': r['query_count'], 'outcome': r['row']['outcome']})
            rows.extend(pair)
            values = [receipt['cpu']['user'], receipt['cpu']['system']]
            require(all(math.isfinite(x) and x >= 0 for x in values), 'INVALID_CPU')
            cpu += sum(values)
        require(len(policies) == 128 and len({p['identity'] for p in policies.values()}) == 128, 'POLICY_COVERAGE')
        all_rows[world], costs[world] = rows, cpu
        support[world] = {'necessary_support_only': reader.support_decision(policies, BOUNDS),
                          'clone_checks': dict(counts), 'durations': durations,
                          'limits': 'Post-treatment activation/support is descriptive, not the primary estimand or full Hand causality. Duration records are not a duration-regression PASS.'}
    result = primary(all_rows, vow)
    result.update(vow=vow, cpu_seconds=costs, resource_pass=resource_ok(costs), secondary=support,
                  pass_all=result['primary_pass'] and resource_ok(costs),
                  packages_admitted=0, p9_certified=False,
                  scope='Adaptive full-run incremental Bloodfire value at this fixed audit policy and assigned matched seed blocks. No controller promotion, descriptor certification or final package admission.')
    result['status'] = 'BLOODFIRE_ADAPTIVE_VALUE_SUPPORTED_NOT_CERTIFICATE' if result['pass_all'] else 'BLOODFIRE_ADAPTIVE_VALUE_NOT_ESTABLISHED'
    return result
