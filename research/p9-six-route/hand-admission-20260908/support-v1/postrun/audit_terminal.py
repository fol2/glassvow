"""Close the existing fixed support stage from committed evidence; run no engine.

This is a post-capture identity/aggregation audit. It does not change the frozen
observer, sampler, scientific stopping rules or admission bar. A missing terminal
is incomplete work, never a support failure. No new study is scheduled here.
"""
from __future__ import annotations
import hashlib
import json
import lzma
from pathlib import Path
import re
import sys

PROTOCOL_HASH = '9f7b3ccc6e9560fa8df7a60e29382c57c53da46bcf09d2be616fb76430e62ca2'
PASS = 'HAND_NATURAL_SUPPORT_GATE_PASS_NOT_PACKAGE_ADMISSION'
FAIL = 'HAND_NATURAL_SUPPORT_GATE_FAIL_IN_FIXED_POLICY_FAMILY'


def require(ok, reason):
    if not ok:
        raise ValueError(reason)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def rendered(value):
    return (json.dumps(value, indent=2) + '\n').encode()


def load(path):
    return json.loads(Path(path).read_bytes())


def safe_file(root, name):
    require(Path(name).name == name and name not in ('', '.', '..'), 'unsafe filename')
    path = root / name
    require(path.is_file() and not path.is_symlink(), 'missing or indirect evidence:' + str(path))
    return path


def raw_identity(path):
    n = 0
    digest = hashlib.sha256()
    with lzma.open(path, 'rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            n += len(block)
            require(n <= 536870912, 'raw bound exceeded')
            digest.update(block)
    return {'bytes': n, 'sha256': digest.hexdigest()}


def verify_child(folder, expected, observed):
    require(load(folder / 'CONFIG.json') == expected, 'child configuration mismatch')
    receipt = load(folder / 'EXECUTION.json')
    require(receipt['status'] == 'COMPLETE' and receipt['failure'] is None,
            'incomplete native child:' + expected['id'])
    require(receipt['config_id'] == expected['id'] and receipt['returncode'] == 0,
            'child execution identity')
    require(set(receipt['raw']) == {'endpoints.ndjson', 'trace.ndjson'}, 'raw coverage')
    required = {'CONFIG.json', 'CELL.json', 'stdout.log', 'stderr.log',
                'endpoints.ndjson.xz', 'trace.ndjson.xz'}
    require(set(receipt['files']) == required, 'child file coverage')
    for name, identity in receipt['files'].items():
        path = safe_file(folder, name)
        data = path.read_bytes()
        require({'bytes': len(data), 'sha256': sha(data)} == identity,
                'recorded file hash:' + str(path))
        observed.append({'path': str(path), **identity})
    for name, identity in receipt['raw'].items():
        require(raw_identity(folder / (name + '.xz')) == identity, 'full raw identity:' + name)
    cell = load(folder / 'CELL.json')
    for key in ('policy_id', 'policy_index', 'vow'):
        require(cell[key] == expected[key], 'child cell ' + key)
    require(cell['route_preference'] == expected['route'], 'child route')
    require(len(cell['runs']) == 1 and cell['runs'][0]['seed'] == expected['seed0'],
            'one exact assigned seed')
    row = cell['runs'][0]
    for key in ('historical_chain_active', 'positive_high_payoff', 'final_pair', 'consumer_reached'):
        require(type(row[key]) is bool, 'non-boolean state:' + key)
    require(row['result'] in ('win', 'loss', 'stall', 'error'), 'outcome vocabulary')
    require(not row['historical_chain_active'] or
            (row['positive_high_payoff'] and row['final_pair'] and row['consumer_reached']),
            'impossible active classification')
    require(re.fullmatch('[a-f0-9]{64}', row['decision_trace_sha256']) is not None,
            'trace identity')
    return receipt, row


def verify_stage(root, configs, summarize):
    cells, observed = [], []
    expected_names = {cfg['id'] for cfg in configs}
    require({p.name for p in root.iterdir() if p.is_dir()} == expected_names,
            'complete fixed policy rectangle')
    for cfg in configs:
        folder = root / cfg['id']
        require(load(folder / 'CONFIG.json') == cfg, 'parent configuration')
        parent = load(folder / 'EXECUTION.json')
        require(parent['status'] == 'COMPLETE' and parent['config_id'] == cfg['id'],
                'incomplete parent')
        children, runs = [], []
        for offset in range(cfg['runs']):
            child = dict(cfg, seed0=cfg['seed0'] + offset, runs=1,
                         id=cfg['id'] + '-s' + str(cfg['seed0'] + offset))
            receipt, row = verify_child(folder / child['id'], child, observed)
            children.append(receipt)
            runs.append(row)
        require(parent['children'] == children, 'parent child receipt binding')
        require(parent['seeds_counted_once'] == [row['seed'] for row in runs], 'counted seed binding')
        cell = {'policy_id': cfg['policy_id'], 'policy_index': cfg['policy_index'],
                'vow': cfg['vow'], 'route_preference': cfg['route'], 'runs': runs}
        require(load(folder / 'CELL.json') == cell, 'parent aggregation')
        cells.append(cell)
    result = summarize(cells)
    require((root / 'RESULTS.json').read_bytes() == rendered(result), 'frozen summary equality')
    return result, observed, cells


def activation_channels(cells):
    """Descriptive split only; do not alter the frozen support predicates."""
    direct = 'POSITIVE_SOURCE_BY_HIGH_PAYOFF_HEALTH_INTERACTION'
    opportunity = 'SOURCE_REQUIRED_FOR_RECORDED_COMMAND_OPPORTUNITY'
    allowed = {direct, opportunity, 'NO_POSITIVE_COMPLETE_HISTORICAL_CHAIN',
               'UNRESOLVED_PREFIX_DAMAGE_CONTRAST'}
    interaction_policies, opportunity_policies, active = set(), set(), set()
    for cell in cells:
        i = cell['policy_index']
        for row in cell['runs']:
            classes = {c['classification'] for c in row['consumers']}
            require(classes.issubset(allowed), 'unknown causal classification')
            a = row['final_pair'] and bool(classes & {direct, opportunity})
            require(row['historical_chain_active'] == a, 'active flag versus retained classifications')
            if not a:
                continue
            active.add(i)
            if direct in classes:
                interaction_policies.add(i)
            if opportunity in classes:
                opportunity_policies.add(i)
    require(active == interaction_policies | opportunity_policies, 'activation channel union')
    return {'positive_health_interaction_policy_indices': sorted(interaction_policies),
            'recorded_prefix_opportunity_policy_indices': sorted(opportunity_policies),
            'opportunity_only_policy_indices': sorted(opportunity_policies - interaction_policies),
            'interaction_only_policy_indices': sorted(interaction_policies - opportunity_policies),
            'both_policy_indices': sorted(interaction_policies & opportunity_policies),
            'scope': 'Descriptive partition of the frozen active predicate, not another gate. '
                     'A blocked recorded prefix does not prove inability of a reoptimised '
                     'counterfactual policy to reach the consumer.'}


def terminal_rules(terminal, stages, v0_exists):
    require(terminal['packages_admitted'] == 0 and terminal['p9_certified'] is False,
            'support is not admission')
    require(terminal['status'] in (PASS, FAIL), 'missing or inconclusive scientific terminal')
    require(5 in stages, 'V5 prerequisite')
    if stages[5]['status'] == FAIL:
        require(not v0_exists and set(stages) == {5}, 'V0 opened after failed V5')
        last = 5
    else:
        require(stages[5]['status'] == PASS and set(stages) == {5, 0} and v0_exists,
                'passing V5 requires complete V0 before final support success')
        last = 0
    require(terminal['last_completed_vow'] == last and terminal['status'] == stages[last]['status'],
            'terminal stage binding')
    return last


def audit(study):
    study = Path(study).resolve()
    sys.path.insert(0, str(study))
    from cohort import configurations
    from read_support import summarize
    protocol = load(study / 'PROTOCOL.json')
    canonical = json.dumps(protocol, sort_keys=True, separators=(',', ':')).encode()
    require(sha(canonical) == PROTOCOL_HASH, 'unchanged scientific protocol')
    for name, digest in protocol['source_sha256'].items():
        require(sha(safe_file(study, name).read_bytes()) == digest, 'frozen source:' + name)
    capture = study / 'capture-1'
    require((capture / 'TERMINAL.json').is_file(), 'terminal not yet present: do not restart or classify')
    terminal = load(capture / 'TERMINAL.json')
    require(terminal['status'] in (PASS, FAIL), 'INCONCLUSIVE: inspect named failure before any resume')
    vows = (5, 0) if terminal['last_completed_vow'] == 0 else (5,)
    stages, observed, channels = {}, [], {}
    for vow in vows:
        stages[vow], files, cells = verify_stage(capture / f'v{vow}', configurations(vow), summarize)
        channels[str(vow)] = activation_channels(cells)
        observed.extend(files)
    last = terminal_rules(terminal, stages, (capture / 'v0').exists())
    return {'kind': 'POST_CAPTURE_FULL_RAW_BINDING_AND_UNCHANGED_AGGREGATION',
            'review_kind': 'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT',
            'scientific_status': terminal['status'], 'last_completed_vow': last,
            'stage_counts': {str(v): {**{k: len(r[k]) for k in
                           ('active', 'inactive', 'ambiguous', 'reachable')},
                           'rows': r['rows'], 'gates': r['gates'],
                           'outcomes': r['outcomes'], 'trajectory_classes': r['trajectory_classes']}
                           for v, r in stages.items()},
            'activation_channels': channels,
            'child_files_hash_checked': len(observed),
            'full_raw_streams_hash_checked': len(observed) // 3,
            'checked_files': [{**r, 'path': str(Path(r['path']).relative_to(study))} for r in observed],
            'new_native_runs': 0, 'new_independent_samples': 0,
            'packages_admitted': 0, 'p9_certified': False,
            'scope': 'Reconciles every preserved child byte with its original execution receipt, '
                     'policy/seed identity, parent cell and unchanged aggregate. Does not rerun '
                     'the native observer, or claim independent semantic/provenance qualification.'}


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: audit_terminal.py SUPPORT_STUDY_DIRECTORY')
    print(json.dumps(audit(sys.argv[1]), indent=2))
