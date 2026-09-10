"""Close one completed joint trial from bound, cold-read evidence; no simulation.
Author self-review is not independent review. Old trials and all bars are immutable.
"""
from __future__ import annotations
import copy
import hashlib
import importlib.util
import json
import math
import lzma
from pathlib import Path
import subprocess
import sys

ROOT = Path('research/p9-six-route')
BASE = ROOT / 'ash-inheritance-20260909'
STUDY = BASE / 'joint-controller-v1'
SUCCESS = 'JOINT_CONTROLLER_AND_PAIR_SUPPORT_PASS_NOT_CERTIFICATE'
NEGATIVE = 'JOINT_CONTROLLER_VALUE_OR_SUPPORT_NOT_ESTABLISHED'
BOUNDS = {'active': 32, 'inactive': 32, 'reachable': 16, 'exclusive': 8}


def require(ok, message):
    if not ok:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def blob(data):
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()


def load(path):
    return json.loads(Path(path).read_bytes())


def save(path, value):
    Path(path).write_text(json.dumps(value, indent=2) + '\n')


def support_valid(packages):
    require(set(packages) == {'bloodfire', 'hand'}, 'PACKAGE_COVERAGE')
    cross = []
    for counts in packages.values():
        require(set(counts) == set(BOUNDS), 'SUPPORT_FIELDS')
        require(all(type(v) is int and 0 <= v <= 128 for v in counts.values()), 'SUPPORT_COUNTS')
        require(counts['active'] + counts['inactive'] == 128, 'POLICY_PARTITION')
        require(counts['exclusive'] <= counts['active'], 'EXCLUSIVE_SUBSET')
        cross.append(counts['active'] - counts['exclusive'])
    require(cross[0] == cross[1], 'COMMON_ACTIVE_INTERSECTION')
    return all(counts[key] >= threshold for counts in packages.values() for key, threshold in BOUNDS.items())


def summarize(terminal, readback, protocol):
    require(protocol['support_bounds'] == BOUNDS, 'UNCHANGED_SUPPORT_BOUNDS')
    require(protocol['containment']['cpu_seconds_per_method_per_vow'] == 3600, 'UNCHANGED_RESOURCE_BAR')
    require(protocol['value_bounds'] == {'minimum_activation_gain': .05, 'one_sided_alpha_per_vow': .025, 'win_noninferiority_margin': .05}, 'UNCHANGED_VALUE_BARS')
    require(terminal['status'] in (SUCCESS, NEGATIVE, 'JOINT_RESOURCE_FAIL', 'INCONCLUSIVE'), 'UNKNOWN_TERMINAL')
    require(readback['kind'] == 'COMPLETE_JOINT_COMPOSITION_COLD_READBACK' and readback['all_bytes_equal'] is True, 'NO_COMPLETE_COLD_READBACK')
    require(readback['scientific_status'] == terminal['status'], 'READBACK_TERMINAL')
    stages = terminal['stages']
    require(set(stages) <= {'5', '0'} and readback['reproduced_stages'] == list(stages), 'STAGE_COVERAGE')
    require(terminal['packages_admitted'] == readback['packages_admitted'] == 0 and terminal['p9_certified'] is readback['p9_certified'] is False, 'PREMATURE_PACKAGE_PROMOTION')
    reports = {}
    for vow, stage in stages.items():
        require(type(stage['vow']) is int and str(stage['vow']) == vow, 'VOW_BINDING')
        for name in ('stock', 'aware'):
            outcomes = stage[name + '_outcomes']
            require(set(outcomes) <= {'win', 'loss'} and all(type(v) is int and v >= 0 for v in outcomes.values()) and sum(outcomes.values()) == 512, 'COMPLETE_OUTCOMES')
            support_valid(stage[name + '_support'])
        old = stage['stock_support']['bloodfire']['active']
        new = stage['aware_support']['bloodfire']['active']
        gained, lost = stage['gained_policies'], stage['lost_policies']
        require(all(type(v) is int and v >= 0 for v in (gained, lost)) and gained <= 128 - old and lost <= old and gained - lost == new - old, 'PAIRED_ACTIVATION_COUNTS')
        require(stage['activation_old'] == old and stage['activation_new'] == new, 'ACTIVATION_BINDING')
        n = gained + lost
        probability = sum(math.comb(n, k) for k in range(gained, n + 1)) / 2 ** n if n else 1.0
        difference = (stage['aware_outcomes'].get('win', 0) - stage['stock_outcomes'].get('win', 0)) / 512
        require(stage['one_sided_exact_sign_p'] == probability and stage['paired_activation_difference'] == (new - old) / 128 and stage['win_difference'] == difference, 'REPORTED_EFFECT_BINDING')
        interval = stage['policy_cluster_bootstrap_interval']
        require(len(interval) == 2 and all(math.isfinite(x) and -1 <= x <= 1 for x in interval) and interval[0] <= interval[1], 'INTERVAL')
        gates = {'paired_activation_gain': (new - old) / 128 >= .05,
                 'paired_activation_sign_test': probability <= .025,
                 'win_point_not_worse': difference >= 0,
                 'win_noninferiority_lower_bound': interval[0] > -.05,
                 'inherited_pair_support': support_valid(stage['aware_support'])}
        require(set(stage['gates']) == set(gates) and all(type(v) is bool for v in stage['gates'].values()) and stage['gates'] == gates, 'GATE_RECONSTRUCTION')
        require(set(stage['costs']) == {'stock', 'aware'}, 'COST_METHODS')
        costs = {name: stage['costs'][name]['process_cpu_seconds'] for name in ('stock', 'aware')}
        require(all(math.isfinite(v) and v >= 0 for v in costs.values()), 'ACTUAL_COST')
        resource = all(v <= 3600 for v in costs.values())
        require(type(stage['resource_pass']) is bool and stage['resource_pass'] == resource, 'RESOURCE_RECONSTRUCTION')
        passed = all(gates.values()) and resource
        require(type(stage['pass']) is bool and stage['pass'] == passed, 'CONJUNCTION_RECONSTRUCTION')
        if vow == '0':
            require('5' in reports and reports['5']['pass'] is True, 'V0_WITHOUT_V5_PASS')
        reports[vow] = {'pass': passed, 'stock_wins': stage['stock_outcomes'].get('win', 0),
                        'aware_wins': stage['aware_outcomes'].get('win', 0), 'rows_per_arm': 512,
                        'stock_support': stage['stock_support'], 'aware_support': stage['aware_support'],
                        'cpu_seconds': costs, 'gates': gates, 'resource_pass': resource,
                        'failed_gates': [k for k, v in gates.items() if not v] + ([] if resource else ['resource']),
                        'paired_activation_difference': (new - old) / 128,
                        'one_sided_exact_sign_p': probability, 'win_difference': difference,
                        'configuration_bootstrap_interval': interval}
    if terminal['status'] == SUCCESS:
        require(list(reports) == ['5', '0'] and all(r['pass'] for r in reports.values()), 'FALSE_SUCCESS')
    elif terminal['status'] == NEGATIVE:
        require(reports and not reports[str(terminal['last_vow'])]['pass'], 'UNSUPPORTED_NEGATIVE')
        require(terminal['v0_skipped'] == ('0' not in reports), 'V0_DISPOSITION')
    return {'kind': 'EXACT_JOINT_CONTROLLER_DISPOSITION', 'status': terminal['status'],
            'stages': reports, 'v0_opened': '0' in reports,
            'controller_and_necessary_pair_support_pass': terminal['status'] == SUCCESS,
            'readback_files': readback['files'], 'all_source_and_capture_bytes_verified': True,
            'old_scientific_terminals_unchanged': True, 'new_native_runs': 0,
            'new_independent_confirmation_samples': 0, 'packages_admitted': 0, 'p9_certified': False,
            'review_kind': 'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT',
            'limits': ['Conditional on four common seeds and the fixed configuration family; not seed-independent confirmation.',
                       'Hand activation is not full producer attribution. Bloodfire local clones are not adaptive whole-run necessity.',
                       'Controller value and necessary support do not certify a package, descriptor, detector, retention or product.']}


def sync_capsule(repo, result, next_action):
    require(isinstance(next_action, str) and len(next_action.strip()) >= 40, 'SPECIFIC_NEXT_ACTION_REQUIRED')
    state_path = repo / ROOT / 'SESSION-STATE.json'
    state = load(state_path)
    require(state['product_reference'] == '2ed6cdb0302ba3aab5845a18d862841165e8aaf7', 'PRODUCT_REFERENCE_CHANGED')
    before = copy.deepcopy(state)
    state.update(status='P9_UNFINISHED_' + result['status'], packages_admitted=0, p9_certified=False,
                 exact_next_action=next_action, no_active_research_processes=True,
                 joint_controller_frontier={k: v for k, v in result.items() if k != 'source_inputs'})
    altered = {'status', 'packages_admitted', 'p9_certified', 'exact_next_action',
               'no_active_research_processes', 'joint_controller_frontier'}
    require(all(state[k] == v for k, v in before.items() if k not in altered), 'HISTORICAL_STATE_CHANGED')
    save(state_path, state)
    lines = ['# P9 current handoff — joint controller trial closed', '',
             'Continue #421 on `research/p9-six-route-local-20260905`.',
             'Product main remains `2ed6cdb0302ba3aab5845a18d862841165e8aaf7`.',
             'Owner target: three complete viable/reachable/distinct packages per aspect.',
             '**0/6 full exact-current certificates. No P9 PASS or product promotion.**', '',
             '## Complete current decision', '', '`' + result['status'] + '`.',
             'Read `ash-inheritance-20260909/joint-controller-v1/closure-1/DECISION.json`',
             'and the complete original `execution-1` capture and cold-readback receipt.',
             'Both arms use the same one-sample combat planner; only acquisition differs.', '']
    for vow, r in result['stages'].items():
        lines += [f"V{vow}: reference {r['stock_wins']}/512 wins; aware {r['aware_wins']}/512.",
                  f"Full CPU seconds: {json.dumps(r['cpu_seconds'], sort_keys=True)}.",
                  f"Aware support (active/inactive/reachable/exclusive): {json.dumps(r['aware_support'], sort_keys=True)}.",
                  f"Failed gates: {json.dumps(r['failed_gates'])}.", '']
    lines += ['V0 opened: ' + str(result['v0_opened']) + '.',
              'The unchanged comparator has been replayed. All stage/resource conjunctions',
              'are checked independently of runner colour. Claims stay conditional on four',
              'common seeds; configurations are not new independent seeds.', '',
              '## Closed history — do not restart', '',
              'The one-sample nomination passed value/cost (66->316 wins/512; 2187.73 CPU',
              'seconds) but Bloodfire active26<32 failed pair support. Its full audit and',
              '1119-file readback are complete. The two-sample cost failures, unsuccessful',
              'cache/float trials and acquisition-only value failure remain immutable.',
              'Minimum Bloodfire/signed RandomBuild evidence remains scoped positive evidence.',
              'Do not replay v25, old panels or fixed models, Hand bulk support, aliases,',
              'reunion/recovery, old controller nominations or this joint composition.', '',
              '## Exact next action', '', next_action, '',
              '## Remaining P9 claims', '',
              'Complete exact-current inherited package causality, descriptor, competent-policy,',
              'peer and natural-economy evidence with independently assigned confirmation.',
              'Fill three strategies per aspect with eligible distinct complete packages.',
              'Then seven-direction detector, corrected confirmation, unrestricted endpoint',
              'retention and every hard guardrail; minimal lifecycle, exact-head review under',
              'owner authority, one selected product integration and #108 receipt.',
              'Author self-review is not independent evidence. Historical raw gaps remain in',
              'SESSION-STATE.json. This closure launches no native research process.', '']
    (repo / ROOT / 'SESSION-HANDOFF.md').write_text('\n'.join(lines))
    roadmap = '# P9 current outcome roadmap\n\nCurrent exact terminal: `' + result['status'] + '`. Full certificates: 0/6.\n\n' + next_action + '\n\n'
    roadmap += '1. Complete full inherited Ash certificates: causal chain, descriptor, competent policy, peer separation, real economy and independent confirmation; carry only unchanged qualified dependencies.\n'
    roadmap += '2. Fill three validated strategies per aspect; check exact registered/closed identities before nominating other complete packages.\n'
    roadmap += '3. Admit the seven-direction detector, corrected untouched confirmation, unrestricted endpoint retention and every original hard guardrail.\n'
    roadmap += '4. Integrate one selected minimum product/detector/lifecycle packet, review exact head, and post the exact merged-product P9 receipt to #108.\n\n'
    roadmap += 'Completed research, exact negatives and old preservation gaps stay in the current capsule and immutable captures. No new sample or admission is created by this roadmap.\n'
    (repo / ROOT / 'package-disposition-20260908/ROADMAP.md').write_text(roadmap)


def describe_complete_pairs(reports):
    require(set(reports) == {'stock', 'aware'}, 'DESCRIPTIVE_METHODS')
    indexed = {m: {r['row_key']: r for r in q['row_results']} for m, q in reports.items()}
    require(set(indexed['stock']) == set(indexed['aware']) and len(indexed['stock']) == 512, 'DESCRIPTIVE_RECTANGLE')
    methods = {}
    for method, q in reports.items():
        rows = q['row_results']
        require(len(rows) == 512, 'DUPLICATE_DESCRIPTIVE_ROW')
        policies = {i: [] for i in range(128)}
        for r in rows:
            require(r['index'] in policies and r['outcome'] in ('win', 'loss'), 'DESCRIPTIVE_ROW')
            require(type(r['bloodfire']) is type(r['hand']) is bool, 'DESCRIPTIVE_BOOLEAN')
            policies[r['index']].append(r)
        require(all(len(v) == 4 and len({r['seed'] for r in v}) == 4 for v in policies.values()), 'DESCRIPTIVE_CLUSTERS')
        groups = {name: {'configurations': 0, 'wins_histogram_0_to_4': [0]*5} for name in ('bloodfire_only', 'hand_only', 'both', 'neither')}
        winning_activation = {'bloodfire': 0, 'hand': 0}
        for records in policies.values():
            bf, hand = any(r['bloodfire'] for r in records), any(r['hand'] for r in records)
            group = 'both' if bf and hand else 'bloodfire_only' if bf else 'hand_only' if hand else 'neither'
            wins = sum(r['outcome'] == 'win' for r in records)
            groups[group]['configurations'] += 1
            groups[group]['wins_histogram_0_to_4'][wins] += 1
            for name in winning_activation:
                winning_activation[name] += int(any(r[name] and r['outcome'] == 'win' for r in records))
        methods[method] = {'policy_membership_groups': groups, 'same_run_win_and_activation_configurations': winning_activation}
    outcome_pairs = {'both_win': 0, 'both_loss': 0, 'aware_only_win': 0, 'reference_only_win': 0}
    for key, old in indexed['stock'].items():
        new = indexed['aware'][key]
        require((old['index'], old['seed']) == (new['index'], new['seed']), 'DESCRIPTIVE_PAIR_IDENTITY')
        a, b = old['outcome'] == 'win', new['outcome'] == 'win'
        category = 'both_win' if a and b else 'reference_only_win' if a else 'aware_only_win' if b else 'both_loss'
        outcome_pairs[category] += 1
    return {'kind': 'COMPLETE_CAPTURE_POSTHOC_DESCRIPTION_NOT_ADMISSION', 'paired_rows': 512,
            'outcome_pairs': outcome_pairs, 'methods': methods,
            'limits': ['Realised route membership is post-treatment; these subgroups do not identify causal mediation or counterfactual optimality.',
                       'One to four wins are descriptive counts, not a new viability threshold or independent confirmation.',
                       'All 128 configurations and all four common seeds are retained; no selected-success subset or new gate.'],
            'new_native_runs': 0, 'admission_or_new_stage_opened': False}


def trace_ledger(records):
    runs = {}
    for r in records:
        key = r['row_key']
        if key not in runs:
            runs[key] = {'commands': 0, 'initial_stock': r['before']['bloodfire'],
                         'final_stock': r['before']['bloodfire'], 'applied': 0, 'consumed': 0,
                         'unconsumed_decreases': 0, 'unexplained_increases': 0, 'continuity_breaks': 0,
                         'source_plays': 0, 'source_command_net_hp_decrease': 0,
                         'decreases_by_command': {}}
        q = runs[key]
        require(r['kind'] == 'command' and r['sequence'] == q['commands'], 'LEDGER_COMMAND_SEQUENCE')
        q['commands'] += 1
        before, after = r['before']['bloodfire'], r['after']['bloodfire']
        require(type(before) is int and type(after) is int and min(before, after) >= 0, 'LEDGER_STOCK')
        q['continuity_breaks'] += int(before != q['final_stock'])
        applied = consumed = 0
        for e in r['events']:
            if e.get('t') != 'status' or e.get('id') != 'bloodfire': continue
            n = e['n']
            if n > 0:
                require(n == 1 and r['card'] == 'bloodRite' and r['ret'] is True, 'LEDGER_PRODUCER')
                applied += 1
            elif n < 0:
                require(n == -1 and r['card'] == 'leechBlade' and r['ret'] is True, 'LEDGER_CONSUMER')
                consumed += 1
        q['applied'] += applied; q['consumed'] += consumed
        remainder = after - before - applied + consumed
        if remainder < 0:
            q['unconsumed_decreases'] -= remainder
            cmd = str(r['command']['t'])
            q['decreases_by_command'][cmd] = q['decreases_by_command'].get(cmd, 0) - remainder
        else: q['unexplained_increases'] += remainder
        if r['card'] == 'bloodRite' and r['ret'] is True:
            q['source_plays'] += 1
            q['source_command_net_hp_decrease'] += r['before']['hp'] - r['after']['hp']
        q['final_stock'] = after
    for q in runs.values():
        q['conserved_without_unobserved_sources'] = (q['initial_stock'] == 0 and q['continuity_breaks'] == 0 and q['unexplained_increases'] == 0
            and q['applied'] - q['consumed'] - q['unconsumed_decreases'] == q['final_stock'])
    return runs


def describe_all_traces(repo, capture, terminal):
    manifest = {r['path']: r for r in load(capture / 'FILES.json')}
    protocols = load(capture / 'RESOLVED-PROTOCOLS.json')
    output, used = {}, []
    for vow in terminal['stages']:
        output[vow] = {}
        for method in ('stock', 'aware'):
            runs = {}
            for first in range(0, 128, 2):
                path = Path(f'v{vow}/{method}/v{vow}-{first:03d}.traces.jsonl.xz')
                b = (capture / path).read_bytes(); record = manifest[str(path)]
                require(len(b) == record['bytes'] and digest(b) == record['sha256'], 'LEDGER_INPUT_BYTES')
                parsed = trace_ledger(json.loads(line) for line in lzma.decompress(b).splitlines())
                expected = {f'{vow}:{i}:{seed}' for i in (first, first+1) for seed in protocols[method]['seeds']}
                require(set(parsed) == expected and not set(parsed) & set(runs), 'LEDGER_FULL_ASSIGNMENT')
                runs.update(parsed); used.append((capture/path).relative_to(repo))
            require(len(runs) == 512, 'LEDGER_ALL_RUNS')
            totals = {k: sum(r[k] for r in runs.values()) for k in ('commands', 'applied', 'consumed', 'unconsumed_decreases', 'unexplained_increases', 'continuity_breaks', 'source_plays', 'source_command_net_hp_decrease', 'final_stock')}
            totals['runs'] = len(runs)
            totals['conservation_failures'] = sum(not r['conserved_without_unobserved_sources'] for r in runs.values())
            by_command = {}
            for r in runs.values():
                for cmd, n in r['decreases_by_command'].items(): by_command[cmd] = by_command.get(cmd, 0) + n
            totals['unconsumed_decreases_by_command'] = by_command
            output[vow][method] = {'totals': totals, 'runs': runs}
    return {'kind': 'COMPLETE_FACTUAL_CHARGE_LEDGER_NOT_TREATMENT_EFFECT', 'stages': output,
            'limits': ['No counterfactual clone payoff is summed into a whole-run treatment effect.',
                       'BloodRite net command HP change includes its original draw/HP trade-off and all same-command effects; it is not the marginal HP cost of the added Bloodfire law.',
                       'An unconsumed decrease is an observed stock change without consumption, not proof the source card was a bad decision.',
                       'This is post-hoc complete-capture accounting; it cannot change a frozen verdict or open V0.'],
            'new_native_runs': 0, 'new_independent_samples': 0, 'p9_certified': False}, used


def main(repo, next_action=None):
    repo = Path(repo).resolve()
    out = repo / STUDY / 'closure-1'
    require(not out.exists(), 'CLOSURE_ALREADY_EXISTS')
    expected = {BASE / 'pair-v1/observed_game.gd': 'f1a60da814b2eff8b5c10bc7d2ce29e00d12268f',
                STUDY / 'joint.py': '9571bfbc8005df4f9b8e425314eb83e892a6f283',
                STUDY / 'PROTOCOL.json': 'a5eeedc90e78bdbc168a2d0ceeb01df61de104ed',
                BASE / 'acquisition-v1/compare_value.py': '22f1ba8575d91ff461e523370a139ccb3258ccc3'}
    for path, identity in expected.items():
        require(blob((repo / path).read_bytes()) == identity, 'SOURCE_IDENTITY:' + str(path))
    capture = repo / STUDY / 'execution-1'
    terminal = load(capture / 'TERMINAL.json')
    readback = load(capture / 'REMOTE-READBACK.json')
    protocol = load(repo / STUDY / 'PROTOCOL.json')
    spec = importlib.util.spec_from_file_location('frozen_comparison', repo / BASE / 'acquisition-v1/compare_value.py')
    comparison = importlib.util.module_from_spec(spec); spec.loader.exec_module(comparison)
    inputs = list(expected) + [STUDY / 'execution-1' / name for name in ('TERMINAL.json', 'REMOTE-READBACK.json', 'FILES.json')]
    manifest = {r['path']: r for r in load(capture / 'FILES.json')}
    descriptions = {}
    for vow, recorded in terminal['stages'].items():
        stage = capture / f'v{vow}'
        paths = [stage / (name + '-support.json') for name in ('stock', 'aware')]
        paths.append(stage / 'COMPARISON.json')
        for path in paths:
            b = path.read_bytes(); r = manifest[str(path.relative_to(capture))]
            require(len(b) == r['bytes'] and digest(b) == r['sha256'], 'FROZEN_STAGE_BYTES')
            inputs.append(path.relative_to(repo))
        reports = {'stock': load(paths[0]), 'aware': load(paths[1])}
        actual = comparison.compare(reports['stock'], reports['aware'], protocol)
        descriptions[vow] = describe_complete_pairs(reports)
        expected_base = copy.deepcopy(recorded)
        for key in ('comparison_scope', 'costs', 'resource_pass'): expected_base.pop(key)
        expected_base['pass'] = all(expected_base['gates'].values())
        require(actual == expected_base and load(paths[2]) == recorded, 'UNCHANGED_COMPARATOR_REPLAY')
    result = summarize(terminal, readback, protocol)
    result['descriptive_readout'] = descriptions
    ledger, trace_inputs = describe_all_traces(repo, capture, terminal)
    inputs += trace_inputs
    result['charge_ledger_totals'] = {v: {m: q['totals'] for m, q in methods.items()} for v, methods in ledger['stages'].items()}
    result['source_head'] = subprocess.check_output(['git', '-C', str(repo), 'rev-parse', 'HEAD'], text=True).strip()
    result['source_inputs'] = [{'path': str(p), 'bytes': (repo / p).stat().st_size,
                               'sha256': digest((repo / p).read_bytes()), 'git_blob': blob((repo / p).read_bytes())} for p in inputs]
    out.mkdir()
    save(out / 'TRACE-RESOURCE-LEDGER.json', ledger)
    if next_action is not None:
        result['exact_next_action'] = next_action
    save(out / 'DECISION.json', result)
    if next_action is not None:
        sync_capsule(repo, result, next_action)
    print(json.dumps({k: v for k, v in result.items() if k != 'source_inputs'}, indent=2))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2] if len(sys.argv) == 3 else None)
