"""Close the already-frozen Hand value experiment without executing a game.

This is an author self-review of exact source/capture bindings and the original
readout, not new inference, a new cohort or a package admission. The native
runner remains sole writer until its terminal AND cold-readback exist.
"""
from __future__ import annotations

from collections import Counter
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import subprocess
import sys

ROOT = Path('research/p9-six-route')
STUDY = ROOT / 'ash-inheritance-20260909/hand-value-v1'
WORLDS = ('00', '01', '10', '11')
CONTRASTS = ('source_group', 'consumer', 'interaction')
SOURCE_BLOBS = {
    'CONTRACT.json': '150b9f0e849cfec053a4457f8ca534d42cba0c53',
    'entry.gd': '69fff8e67e20f69d2ca5fbbaa6c69b650d53cffc',
    'read_hand.py': '37337fadd6daaf296b4abb075bc7eb07d4d4a230',
    'run_hand.py': 'dc27966b3901e31b0949e8dde5b9880c72490f67',
    'test_hand.py': '2a202d5d7842f3d34f52a25150e01a3424639452',
}
SUPPORTED = 'HAND_ADAPTIVE_GROUP_VALUE_SUPPORTED_NOT_CERTIFICATE'
NEGATIVE = 'HAND_ADAPTIVE_GROUP_VALUE_NOT_ESTABLISHED'


def require(ok: bool, why: str) -> None:
    if not ok:
        raise ValueError(why)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def blob(data: bytes) -> str:
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()


def load(path: Path):
    return json.loads(path.read_bytes())


def save(path: Path, value) -> None:
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + '\n')


def git(repo: Path, *args: str) -> str:
    return subprocess.check_output(['git', '-C', str(repo), *args]).decode().strip()


def relative(value: str) -> Path:
    path = Path(value)
    require(isinstance(value, str) and value != '' and not path.is_absolute()
            and '..' not in path.parts and '.' != value and path.as_posix() == value
            and '\\' not in value, 'UNSAFE_PATH')
    return path


def file_record(repo: Path, path: Path) -> dict:
    data = path.read_bytes()
    return {'path': path.relative_to(repo).as_posix(), 'bytes': len(data),
            'sha256': sha(data), 'git_blob': blob(data)}


def source_check(repo: Path) -> dict:
    root = repo / STUDY
    records = {}
    for name, expected in SOURCE_BLOBS.items():
        data = (root / name).read_bytes()
        require(blob(data) == expected, 'FROZEN_GIT_SOURCE:' + name)
        records[name] = file_record(repo, root / name)
    freeze = load(root / 'FREEZE.json')
    for name, expected in freeze['source_sha256'].items():
        require(sha((root / relative(name)).read_bytes()) == expected, 'SOURCE_FREEZE:' + name)
    return {'files': records, 'freeze': file_record(repo, root / 'FREEZE.json')}


def capture_check(capture: Path) -> tuple[dict, dict, list]:
    terminal = load(capture / 'TERMINAL.json')
    receipt = load(capture / 'REMOTE-READBACK.json')
    records = load(capture / 'FILES.json')
    require(receipt['kind'] == 'COMPLETE_HAND_ADAPTIVE_VALUE_COLD_READBACK'
            and receipt['all_bytes_equal'] is True, 'REMOTE_READBACK_REQUIRED')
    require(receipt['scientific_status'] == terminal['status'], 'READBACK_TERMINAL')
    require(receipt['reproduced_stages'] == list(terminal['stages']), 'READBACK_STAGES')
    require(type(receipt['files']) is int and receipt['files'] == len(records) + 1,
            'READBACK_FILE_COUNT')
    names = [r['path'] for r in records]
    require(len(set(names)) == len(names), 'DUPLICATE_MANIFEST_PATH')
    # The final receipt is necessarily published after the capture manifest.
    actual = {p.relative_to(capture).as_posix() for p in capture.rglob('*') if p.is_file()}
    require(actual == set(names) | {'FILES.json', 'REMOTE-READBACK.json'}, 'FULL_CAPTURE_COVERAGE')
    for record in records:
        path = capture / relative(record['path'])
        data = path.read_bytes()
        require(type(record['bytes']) is int and record['bytes'] == len(data)
                and sha(data) == record['sha256'], 'CAPTURE_BYTES:' + record['path'])
    require('TERMINAL.json' in names, 'TERMINAL_NOT_IN_MANIFEST')
    return terminal, receipt, records


def independent_counts(rows: dict, vow: int) -> dict:
    """Arithmetic reconciliation, not a replacement bootstrap/primary metric."""
    require(type(vow) is int and vow in (0, 5), 'VOW')
    require(set(rows) == set(WORLDS), 'FOUR_WORLDS')
    expected = {(index, 73620100 + 1000 * vow + 4 * (first // 2) + j)
                for first in range(0, 128, 2) for index in (first, first + 1) for j in range(4)}
    mapped = {}
    identities = {}
    for world in WORLDS:
        require(len(rows[world]) == 512, 'ROW_COUNT')
        table = {}
        configs = {}
        for row in rows[world]:
            require(type(row['index']) is int and type(row['seed']) is int
                    and type(row['vow']) is int and row['vow'] == vow, 'ROW_IDENTITY')
            key = (row['index'], row['seed'])
            require(key not in table, 'DUPLICATE_ROW')
            require(key in expected and row['row']['outcome'] in ('win', 'loss')
                    and not row['row'].get('error'), 'INVALID_ASSIGNED_OUTCOME')
            table[key] = row
            identity = json.dumps(row['policy'], sort_keys=True, separators=(',', ':'))
            require(configs.get(row['index'], identity) == identity, 'WITHIN_CONFIG_POLICY_DRIFT')
            configs[row['index']] = identity
        require(set(table) == expected and len(configs) == 128
                and len(set(configs.values())) == 128, 'POLICY_RECTANGLE')
        mapped[world], identities[world] = table, configs
    require(all(identities[w] == identities['00'] for w in WORLDS), 'CROSS_WORLD_POLICY_DRIFT')
    counts, wins, sums, by_seed = Counter(), {w: 0 for w in WORLDS}, [0, 0, 0], {}
    for key in sorted(expected):
        y = [int(mapped[w][key]['row']['outcome'] == 'win') for w in WORLDS]
        counts[''.join(map(str, y))] += 1
        for world, value in zip(WORLDS, y):
            wins[world] += value
        vector = [y[3] - y[1], y[3] - y[2], y[3] - y[2] - y[1] + y[0]]
        for k in range(3):
            sums[k] += vector[k]
        by_seed.setdefault(key[1], []).append(vector)
    require(len(by_seed) == 256 and all(len(v) == 2 for v in by_seed.values()), 'SEED_CLUSTER_UNIT')
    return {'wins': wins, 'contrasts': dict(zip(CONTRASTS, (x / 512 for x in sums))),
            'outcome_patterns_00_01_10_11': dict(sorted(counts.items())),
            'rows_per_world': 512, 'configurations': 128, 'matched_seed_blocks': 256}


def stage_check(actual: dict, saved: dict, terminal_stage: dict, counts: dict, costs: dict) -> dict:
    require(set(costs) == set(WORLDS) and all(type(x) in (float, int)
            and math.isfinite(x) and 0 <= x <= 3600 for x in costs.values()), 'RESOURCE_CONJUNCTION')
    require(actual['wins'] == counts['wins'] == saved['wins'], 'WIN_RECONCILIATION')
    require(actual['outcome_patterns_00_01_10_11'] == counts['outcome_patterns_00_01_10_11'], 'PATTERN_RECONCILIATION')
    for key, value in actual.items():
        require(saved[key] == value, 'ORIGINAL_PRIMARY_REPRODUCTION:' + key)
    for name in CONTRASTS:
        result = actual['contrasts'][name]
        lo, hi = result['interval']
        require(all(math.isfinite(x) for x in (lo, hi, result['point'])) and lo <= hi,
                'INVALID_INTERVAL')
        require(result['point'] == counts['contrasts'][name], 'CONTRAST_RECONCILIATION')
        require(result['positive_lower_bound'] is (lo > 0), 'CONTRAST_DECISION')
    primary = all(actual['contrasts'][n]['interval'][0] > 0 for n in CONTRASTS)
    require(actual['primary_pass'] is primary and saved['pass_all'] is primary
            and saved['resource_pass'] is True and saved['cpu_seconds'] == costs, 'STAGE_CONJUNCTION')
    require(all(saved[k] == v for k, v in terminal_stage.items()), 'TERMINAL_STAGE_BINDING')
    return {k: v for k, v in saved.items() if k != 'secondary'}


def terminal_check(terminal: dict, stages: dict, v0_present: bool) -> str:
    require(type(terminal['packages_admitted']) is int and terminal['packages_admitted'] == 0
            and terminal['p9_certified'] is False, 'FALSE_ADMISSION')
    require(list(stages) == list(terminal['stages']) and list(stages) in (['5'], ['5', '0']), 'ORDERED_STAGES')
    require('qualification' in terminal and terminal['qualification']['status'] == 'HAND_WORLD_ENTRY_BINDING_PASS',
            'MISSING_ENTRY_QUALIFICATION')
    if '0' in stages:
        require(stages['5']['pass_all'] is True and v0_present, 'PREMATURE_V0')
    else:
        require(not v0_present and stages['5']['pass_all'] is False, 'MISSING_OR_UNAUTHORISED_V0')
    supported = all(stage['pass_all'] for stage in stages.values()) and list(stages) == ['5', '0']
    expected = SUPPORTED if supported else NEGATIVE
    require(terminal['status'] == expected and 'failure' not in terminal, 'SCIENTIFIC_TERMINAL')
    if expected == NEGATIVE:
        require(terminal['last_vow'] == int(list(stages)[-1])
                and terminal['v0_skipped'] is ('0' not in stages), 'STOPPING_RULE')
    return expected


def audit(repo: Path, output: Path) -> dict:
    require(not output.exists(), 'OUTPUT_EXISTS_NO_OVERWRITE')
    sources = source_check(repo)
    capture = repo / STUDY / 'execution-1'
    terminal, receipt, records = capture_check(capture)
    require(terminal['status'] in (SUPPORTED, NEGATIVE), 'INCOMPLETE_DELIVERY_NOT_SCIENTIFIC_NEGATIVE')
    sys.path.insert(0, str(repo / STUDY))
    import run_hand
    import read_hand
    run_hand.validate_contract(load(repo / STUDY / 'CONTRACT.json'))
    require(run_hand.entry_result(capture / 'qualification') == terminal['qualification'], 'ENTRY_REPRODUCTION')
    _, value, _, reader = run_hand.dependencies(repo)
    protocols = load(capture / 'RESOLVED-PROTOCOLS.json')
    stages, arithmetic = {}, {}
    for key, terminal_stage in terminal['stages'].items():
        vow = int(key)
        rows, costs = {}, {}
        for world in WORLDS:
            rows[world], costs[world] = [], 0.
            for first in range(0, 128, 2):
                cfg = read_hand.config(first, vow)
                stem = f'v{vow}-{first:03d}'
                folder = capture / ('v' + key) / world
                cell = load(folder / (stem + '.RECEIPT.json'))
                require(cell['status'] == 'COMPLETE' and cell['cfg'] == cfg and cell['rows'] == 8, 'CELL_IDENTITY')
                pair = reader.outcome_records(folder / (stem + '.outcomes.jsonl.xz'), cfg, protocols[world])
                value.read_value.validate_extra(pair, 'planner')
                rows[world].extend(pair)
                times = (cell['cpu']['user'], cell['cpu']['system'])
                require(all(type(x) in (float, int) and math.isfinite(x) and x >= 0 for x in times), 'INVALID_CPU')
                costs[world] += sum(times)
        arithmetic[key] = independent_counts(rows, vow)
        actual = read_hand.primary(rows, vow, repo)
        saved = load(capture / ('v' + key) / 'RESULTS.json')
        stages[key] = stage_check(actual, saved, terminal_stage, arithmetic[key], costs)
    status = terminal_check(terminal, stages, (capture / 'v0').exists())
    output.mkdir(parents=True)
    decision = {'kind': 'EXACT_HAND_GROUP_ADAPTIVE_VALUE_DISPOSITION', 'status': status,
                'verified_input_head': git(repo, 'rev-parse', 'HEAD'), 'sources': sources,
                'terminal': file_record(repo, capture / 'TERMINAL.json'),
                'capture_manifest': file_record(repo, capture / 'FILES.json'),
                'original_readback': file_record(repo, capture / 'REMOTE-READBACK.json'),
                'capture_files_verified': len(records), 'stages': stages, 'arithmetic': arithmetic,
                'all_original_readout_and_stop_rules_reproduced': True,
                'review_kind': 'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT', 'new_native_runs': 0,
                'new_independent_samples': 0, 'packages_admitted': 0, 'p9_certified': False,
                'limits': [
                    'The original seed-block bootstrap is reproduced, not replaced or strengthened.',
                    'Fixed audit policy and direct-draw source group only; not individual-source indispensability, optimality or all Hand strategies.',
                    'A nonpositive confidence bound is not proof of no benefit, equivalence or universal futility.',
                    'Causal value, even if supported, is not a validated descriptor, independent package confirmation, detector, retention or product receipt.',
                    'Historical controller, Bloodfire, model and study negatives remain immutable.'
                ]}
    save(output / 'DECISION.json', decision)
    return decision


def sync(repo: Path, output: Path) -> None:
    decision = load(output / 'DECISION.json')
    state_path = repo / ROOT / 'SESSION-STATE.json'
    state = load(state_path)
    supported = decision['status'] == SUPPORTED
    next_action = (
        'Hand group value supported at both fixed vows: complete the precommitted descriptor validation, '
        'competent-policy/peer/economy and independently assigned confirmation obligations before package admission. '
        'Do not promote the audit controller or reopen its failed value nominations.' if supported else
        'Close this exact Hand group adaptive-value claim without extension or rescue. Reconcile the remaining '
        'package proof obligations and eligible already-authorized alternatives against the complete evidence; '
        'no new controller, seed reroll or descriptor-confirmation experiment is opened by this closure. '
        'A next study requires a genuinely different unmeasured acceptance claim, not a new threshold for this result.'
    )
    state.update(status='P9_UNFINISHED_HAND_ADAPTIVE_VALUE_CLOSED', packages_admitted=0, p9_certified=False,
                 no_active_research_processes=True, exact_next_action=next_action)
    state['hand_adaptive_group_value'] = {
        'status': decision['status'], 'stages': decision['stages'],
        'decision': str((STUDY / 'closure-1/DECISION.json').relative_to(ROOT)),
        'original_readback': str((STUDY / 'execution-1/REMOTE-READBACK.json').relative_to(ROOT)),
        'closure_readback': str((STUDY / 'closure-1/REMOTE-READBACK.json').relative_to(ROOT)),
        'source_group_not_individual_variants': True, 'descriptor_admitted': False}
    save(state_path, state)
    lines = ['# P9 current handoff — Hand adaptive-value decision complete', '',
             'Continue #421 on `research/p9-six-route-local-20260905`.',
             'Product reference: `2ed6cdb0302ba3aab5845a18d862841165e8aaf7`.',
             '**0/6 complete current certificates; no P9 PASS or product promotion.**', '',
             '## Completed decision', '', decision['status'], '',
             'Both direct Preparation/Surge draw effects form one source group; Phantom coefficient is the consumer factor.',
             'All four worlds share the unchanged aware one-sample audit policy and retain background effects.',
             'Commands adapt within each world. Post-treatment membership is not used to select the primary sample.', '']
    for vow, stage in decision['stages'].items():
        lines += [f'V{vow}: wins by world00/01/10/11: '+json.dumps(stage['wins'], sort_keys=True)+'.',
                  'Frozen contrasts: '+json.dumps(stage['contrasts'], sort_keys=True)+'.',
                  'CPU seconds: '+json.dumps(stage['cpu_seconds'], sort_keys=True)+'.', '']
    lines += ['Full raw and original cold-readback are in `ash-inheritance-20260909/hand-value-v1/execution-1/`.',
              'The post-run arithmetic/source/capture review is in `hand-value-v1/closure-1/`.',
              'A confidence interval crossing zero is not equality, no benefit or universal Hand nonviability.', '',
              '## Preserved earlier decisions', '',
              'Bloodfire adaptive value remains NOT_ESTABLISHED (298/512 in00/01/10;302/512 in11).',
              'The complete55-file source-utility packet and Hand384-case query/clone interface, actual inherited',
              'call-path and factual512-run provenance fields are remotely preserved. Do not repeat them.',
              'BloodRite is lose3HP and gain2/3Energy, NOT draw. Preparation/Surge are alternative sources in ONE family.',
              'The factual provenance fields have not acquired predictive/causal descriptor admission.',
              'All old controller/resource/acquisition, v25, cohort, model and source-negative scopes remain unchanged.',
              'Historical older raw gaps remain recorded in SESSION-STATE.json.', '',
              '## Exact continuation', '', next_action, '',
              'Remaining: complete package causality/descriptor/policy/peer/economy/independent proof;',
              'three strategies per aspect; seven-direction detector; corrected independent confirmation and',
              'unrestricted endpoint retention; hard guardrails; minimal lifecycle, exact-head review,',
              'one selected product integration and exact-product #108 receipt.',
              'Author self-review is not independent evidence. No native process is launched by this closure.', '']
    (repo / ROOT / 'SESSION-HANDOFF.md').write_text('\n'.join(lines))
    roadmap = repo / ROOT / 'package-disposition-20260908/ROADMAP.md'
    roadmap.write_text('# P9 current outcome roadmap\n\n0/6 complete current certificates.\n\n'
                       + 'Latest complete decision: '+decision['status']+'.\n\n'
                       + '1. '+next_action+'\n'
                       + '2. Complete three viable/reachable/distinct strategies per aspect; alternative producers do not create slots.\n'
                       + '3. Admit the seven-direction detector, corrected independent confirmation, unrestricted endpoint retention and all guardrails.\n'
                       + '4. Deliver minimal lifecycle and one selected exact-product integration/#108 receipt under current review/release authority.\n\n'
                       + 'No repeat recovery, source/clone matrices, v25, frozen models, closed controller tuning or sample extensions.\n')


def run(repo: Path, output: Path) -> None:
    audit(repo, output)
    sync(repo, output)
    owned = [repo / STUDY / 'close_value.py', repo / STUDY / 'test_close_value.py', output / 'DECISION.json']
    owned += [repo / ROOT / n for n in ('SESSION-HANDOFF.md', 'SESSION-STATE.json', 'package-disposition-20260908/ROADMAP.md')]
    save(output / 'FILES.json', [file_record(repo, p) for p in owned])


def verify(original: Path, cold: Path, receipt_path: Path) -> None:
    require(not receipt_path.exists(), 'RECEIPT_EXISTS')
    output = STUDY / 'closure-1'
    raw = (original / output / 'FILES.json').read_bytes()
    require(raw == (cold / output / 'FILES.json').read_bytes(), 'COLD_MANIFEST')
    records = json.loads(raw)
    require(len({r['path'] for r in records}) == len(records), 'DUPLICATE_CLOSURE_PATH')
    for r in records:
        rel = relative(r['path'])
        data = (cold / rel).read_bytes()
        require(data == (original / rel).read_bytes() and len(data) == r['bytes']
                and sha(data) == r['sha256'] and blob(data) == r['git_blob']
                == git(cold, 'rev-parse', 'HEAD:' + rel.as_posix()), 'COLD_CLOSURE_BYTES:' + str(rel))
    source_check(cold)
    terminal, proof, _ = capture_check(cold / STUDY / 'execution-1')
    decision = load(cold / output / 'DECISION.json')
    require(terminal['status'] == decision['status'] == proof['scientific_status'], 'COLD_DECISION')
    terminal_check(terminal, decision['stages'], (cold / STUDY / 'execution-1/v0').exists())
    save(receipt_path, {'kind': 'HAND_ADAPTIVE_VALUE_CLOSURE_COLD_READBACK',
                       'published_head': git(cold, 'rev-parse', 'HEAD'), 'files': records,
                       'all_bytes_equal': True, 'original_source_capture_and_terminal_verified': True,
                       'new_native_runs': 0, 'new_independent_samples': 0,
                       'packages_admitted': 0, 'p9_certified': False})


if __name__ == '__main__':
    action, *args = sys.argv[1:]
    if action == 'run' and len(args) == 2:
        run(*(Path(x).resolve() for x in args))
    elif action == 'verify' and len(args) == 3:
        verify(*(Path(x).resolve() for x in args))
    else:
        raise SystemExit('run REPO OUTPUT | verify ORIGINAL COLD RECEIPT')
