"""Fixed two-slope Hand contrasts. Pure arithmetic; no admission or model fit."""
from collections import Counter
import json
import math
from pathlib import Path

WORLDS = ('00', '01', '10', '11')
NAMES = ('source_group', 'consumer', 'interaction')
SEED_BASE = 73830100
QUALIFICATION_SEED = 73830010
ROOT = 73409000
SUPPORTED = 'TWO_SLOPE_HAND_ADAPTIVE_VALUE_SUPPORTED_NOT_CERTIFICATE'
NEGATIVE = 'TWO_SLOPE_HAND_ADAPTIVE_VALUE_NOT_ESTABLISHED'


def require(ok, why):
    if not ok:
        raise ValueError(why)


def config(first, vow):
    require(type(first) is int and first in range(0, 128, 2), 'CONFIG_INDEX')
    require(type(vow) is int and vow in (0, 5), 'VOW')
    start = SEED_BASE + 1000 * vow + 4 * (first // 2)
    return {'root': ROOT, 'first': first, 'count': 2, 'seeds': list(range(start, start + 4)),
            'vow': vow, 'integration': False}


def resource_ok(costs):
    return set(costs) == set(WORLDS) and all(type(x) in (float, int)
        and math.isfinite(x) and 0 <= x <= 3600 for x in costs.values())


def paired(rows, vow):
    require(set(rows) == set(WORLDS), 'FOUR_WORLDS')
    expected = {(i, s) for first in range(0, 128, 2) for i in (first, first+1)
                for s in config(first, vow)['seeds']}
    mapped, identities = {}, {}
    for world in WORLDS:
        table, policies = {}, {}
        require(len(rows[world]) == 512, 'ROW_COUNT')
        for r in rows[world]:
            require(type(r['index']) is int and type(r['seed']) is int
                    and type(r['vow']) is int and r['vow'] == vow, 'ROW_IDENTITY')
            key = (r['index'], r['seed'])
            require(key in expected and key not in table, 'ASSIGNMENT_OR_DUPLICATE')
            require(r['row']['outcome'] in ('win', 'loss') and not r['row'].get('error'), 'FAULT_NOT_LOSS')
            identity = json.dumps(r['policy'], sort_keys=True, separators=(',', ':'))
            require(policies.get(r['index'], identity) == identity, 'WITHIN_POLICY_DRIFT')
            policies[r['index']] = identity
            table[key] = r
        require(set(table) == expected and len(policies) == len(set(policies.values())) == 128, 'RECTANGLE')
        mapped[world], identities[world] = table, policies
    require(all(identities[w] == identities['00'] for w in WORLDS), 'CROSS_WORLD_POLICY_DRIFT')
    by_seed, patterns, wins = {}, Counter(), {w: 0 for w in WORLDS}
    for key in sorted(expected):
        y = [int(mapped[w][key]['row']['outcome'] == 'win') for w in WORLDS]
        patterns[''.join(map(str, y))] += 1
        for w, value in zip(WORLDS, y):
            wins[w] += value
        by_seed.setdefault(key[1], []).append([y[3]-y[1], y[3]-y[2], y[3]-y[2]-y[1]+y[0]])
    require(len(by_seed) == 256 and all(len(v) == 2 for v in by_seed.values()), 'SEED_BLOCKS')
    blocks = [[sum(x[k] for x in by_seed[s])/2 for k in range(3)] for s in sorted(by_seed)]
    return blocks, wins, dict(sorted(patterns.items()))


def primary(rows, vow, bootstrap):
    blocks, wins, patterns = paired(rows, vow)
    intervals = bootstrap(blocks)
    require(len(intervals) == 3, 'INTERVAL_COUNT')
    contrasts = {}
    for k, name in enumerate(NAMES):
        lo, hi = intervals[k]
        require(all(math.isfinite(x) for x in (lo, hi)) and lo <= hi, 'INTERVAL')
        contrasts[name] = {'point': sum(b[k] for b in blocks)/256, 'interval': [lo, hi],
                           'positive_lower_bound': lo > 0}
    return {'rows_per_world': 512, 'policy_configurations': 128, 'distinct_seed_blocks': 256,
            'wins': wins, 'contrasts': contrasts, 'outcome_patterns_00_01_10_11': patterns,
            'primary_pass': all(x['positive_lower_bound'] for x in contrasts.values()),
            'uncertainty': 'Pinned 10000-resample paired-seed bootstrap Random(421); Bonferroni percentile bounds .05/6 and 1-.05/6. Approximate fixed-policy/context inference, not final P9 multiplicity control.'}


def stage(folder, protocols, vow, reader, validate_extra, bootstrap):
    folder = Path(folder)
    rows, costs, counts = {}, {}, {}
    for world in WORLDS:
        rows[world], costs[world], ct = [], 0., Counter()
        for first in range(0, 128, 2):
            cfg, stem = config(first, vow), f'v{vow}-{first:03d}'
            base = folder/world
            receipt = json.loads((base/(stem+'.RECEIPT.json')).read_bytes())
            require(receipt['status'] == 'COMPLETE' and receipt['cfg'] == cfg and receipt['rows'] == 8, 'CELL_RECEIPT')
            records = reader.outcome_records(base/(stem+'.outcomes.jsonl.xz'), cfg, protocols[world])
            validate_extra(records, 'planner')
            _, summary = reader.trace_summary(base/(stem+'.traces.jsonl.xz'), {r['row_key'] for r in records})
            ct.update(summary)
            rows[world].extend(records)
            cpu = [receipt['cpu']['user'], receipt['cpu']['system']]
            require(all(type(x) in (int, float) and math.isfinite(x) and x >= 0 for x in cpu), 'INVALID_CPU')
            costs[world] += sum(cpu)
        counts[world] = dict(ct)
    result = primary(rows, vow, bootstrap)
    result.update(vow=vow, cpu_seconds=costs, resource_pass=resource_ok(costs),
                  pass_all=result['primary_pass'] and resource_ok(costs), trace_counts=counts,
                  packages_admitted=0, p9_certified=False)
    result['status'] = SUPPORTED if result['pass_all'] else NEGATIVE
    return result


def next_stage(result, vow):
    require(type(vow) is int and vow in (0, 5), 'VOW')
    require(result['resource_pass'] is True, 'RESOURCE_INCONCLUSIVE')
    require(result['pass_all'] is result['primary_pass'], 'CONJUNCTION')
    if not result['pass_all']:
        return 'CLOSE_NOT_ESTABLISHED'
    return 'OPEN_FIXED_V0' if vow == 5 else 'CLOSE_SUPPORTED_NOT_CERTIFICATE'
