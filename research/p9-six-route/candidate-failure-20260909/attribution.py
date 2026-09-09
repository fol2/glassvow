"""Two missing cells of a fixed, exposed-seed causal decomposition; never admission.

Reuse the two already published signed-control Ash V0 cells. Execute only the
other two corners. The factor is the JOINT Ashen Core/Ashfall substrate, not an
individual card coefficient. All policy, seed, engine and remaining deltas stay.
"""
from __future__ import annotations
from concurrent.futures import ThreadPoolExecutor
from copy import deepcopy
import hashlib
import json
import lzma
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

BASE = 'a0d608a5142d2e3aab799cdf33d3163922b402c2aaf2a895e46e096399b56cf1'
CANDIDATE = '3c7b2f9dba362d19128ef82ad559d3f26e54925371d823a665767032255eadaa'
OLD_PROTOCOL = 'f8eaf9dffc65fa30222c80083ca0397a80174837cf8be1134c39613bf1c860c7'
OLD_RAW = {
    '00': ('baseline-ashwarden-v0.ndjson', '3e817d184a84cd16afeb10bac1f2a27b5b33e4aeb7f60466adde25eba11803d1'),
    '11': ('candidate-ashwarden-v0.ndjson', '025e25923d2d2fd30d08dcd3cee31c761eed21ce4d28b10f1d02cf8ea728b963'),
}
SEEDS = list(range(60909000, 60909128))
HERE = Path(__file__).resolve().parent


def require(ok, message):
    if not ok:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def render(value):
    return (json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode()


def save(path, value):
    path.write_bytes(render(value))


def hybrids(baseline, candidate):
    require(sha(baseline) == BASE and sha(candidate) == CANDIDATE, 'PARENT_CONTENT')
    b, c = json.loads(baseline), json.loads(candidate)
    require(render(b) == baseline and render(c) == candidate, 'NO_SERIALIZATION_DRIFT')
    require('startSmolder' not in b['relics']['ashenCore'], 'BASE_CORE_DEFAULT')
    require(c['relics']['ashenCore']['startSmolder'] == 1, 'CANDIDATE_CORE')
    require(b['arts']['ashfall']['effects'][0] ==
            {'kind': 'status', 'who': 'allEnemies', 'id': 'poison', 'n': 6}, 'BASE_ART')
    require(c['arts']['ashfall']['effects'][0] ==
            {'kind': 'status', 'who': 'allEnemies', 'id': 'poison', 'n': 3}, 'CANDIDATE_ART')
    x, y = deepcopy(b), deepcopy(c)
    # 01: baseline remaining system, candidate substrate. 10: converse.
    x['relics']['ashenCore'] = deepcopy(c['relics']['ashenCore'])
    x['arts']['ashfall'] = deepcopy(c['arts']['ashfall'])
    y['relics']['ashenCore'] = deepcopy(b['relics']['ashenCore'])
    y['arts']['ashfall'] = deepcopy(b['arts']['ashfall'])
    return {'01': render(x), '10': render(y)}


def identity_manifest(raw):
    return {'bytes': len(raw), 'sha256': sha(raw),
            'git_blob': hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest()}


def paired(a, b):
    """b minus a on the same fixed identities. No population-confidence claim."""
    require(len(a) == len(b) == 128, 'PAIRED_SIZE')
    require(all(type(v) is bool for v in a + b), 'BOOLEAN_RESPONSE')
    gained = sum(not x and y for x, y in zip(a, b))
    lost = sum(x and not y for x, y in zip(a, b))
    return {'net_wins': gained - lost, 'fraction': (gained - lost) / 128,
            'gained_wins': gained, 'lost_wins': lost}


def summarize(cells):
    require(set(cells) == {'00', '01', '10', '11'}, 'FOUR_CORNERS')
    values, counts = {}, {}
    for key, rows in cells.items():
        require([r['seed'] for r in rows] == SEEDS, 'IDENTICAL_SEED_ORDER')
        require(all(r['aspect'] == 'ashwarden' and r['vow'] == 0 and r['arm'] == 2 for r in rows), 'CONTEXT')
        require(all(r['outcome'] in ('win', 'loss', 'stall', 'error') for r in rows), 'OUTCOME')
        faults = [r['seed'] for r in rows if r['outcome'] in ('stall', 'error') or r.get('error')]
        require(not faults, 'FAULTED_ATTRIBUTION:' + key)
        values[key] = [r['outcome'] == 'win' for r in rows]
        counts[key] = {'wins': sum(values[key]), 'losses': 128 - sum(values[key]), 'faults': 0}
    # Existing cells must remain precisely the already observed negative.
    require(counts['00']['wins'] == 29 and counts['11']['wins'] == 10, 'REUSED_TERMINAL_COUNTS')
    b, s, r, c = (values[k] for k in ('00', '01', '10', '11'))
    interaction = [int(w) - int(z) - int(y) + int(x) for x, y, z, w in zip(b, s, r, c)]
    return {
        'status': 'FIXED_EXPOSED_ASSIGNMENT_DECOMPOSITION_COMPLETE_NOT_ADMISSION',
        'factors': {'first_digit': 'all remaining candidate content/runtime deltas',
                    'second_digit': 'joint universal Ash substrate reductions'},
        'cells': counts,
        'contrasts': {
            'substrate_in_baseline_background': paired(b, s),
            'substrate_in_candidate_background': paired(r, c),
            'remaining_deltas_under_native_substrate': paired(b, r),
            'remaining_deltas_under_reduced_substrate': paired(s, c),
            'restoring_native_substrate_in_candidate': paired(c, r),
            'original_full_candidate_minus_baseline': paired(b, c)},
        'factor_interaction': {'sum': sum(interaction), 'mean': sum(interaction) / 128,
                               'per_seed_values': interaction},
        'interpretation': 'Read conditional contrasts together. A factor effect can depend on the other factor; neither main effect is an individual-card attribution.',
        'original_screen_status': 'SIGNED_CONTROL_NECESSARY_SCREEN_FAIL',
        'old_outcomes_reused': 256, 'new_diagnostic_outcomes': 256,
        'new_independent_confirmation_samples': 0,
        'scope': 'The 128 already exposed signed-arm2 Ash V0 seeds only. No new screening or population inference; no hybrid is selected or certified here.',
        'forbidden_inference': ['No Hand causality from catalogue-wide change',
                               'No passing the original failed screen retrospectively',
                               'No other aspect/vow, duration, ceiling, C2, diversity or retention certification'],
        'packages_admitted': 0, 'p9_certified': False}


def run(repo, engine, output):
    repo, engine, output = map(lambda p: Path(p).resolve(), (repo, engine, output))
    require(not output.exists(), 'OUTPUT_EXISTS_DO_NOT_REPLAY')
    protocol = json.loads((HERE / 'PROTOCOL.json').read_bytes())
    for name, expected in protocol['source_sha256'].items():
        require(sha((HERE / name).read_bytes()) == expected, 'NEW_SOURCE:' + name)
    guard = repo / 'research/p9-six-route/guardrail-confirmation-20260909'
    require(sha((guard / 'PROTOCOL.json').read_bytes()) == OLD_PROTOCOL, 'ORIGINAL_PROTOCOL')
    p = json.loads((guard / 'PROTOCOL.json').read_bytes())
    require(sha(engine.read_bytes()) == p['engine_sha256'], 'ENGINE')
    for name, expected in p['source_sha256'].items():
        require(sha((guard / name).read_bytes()) == expected, 'ORIGINAL_DRIVER:' + name)
    sys.path.insert(0, str(guard))
    import execute_control as execution
    import read_control as reader
    cells, reuse = {}, {}
    for key, (name, expected) in OLD_RAW.items():
        path = guard / 'native-1' / (name + '.xz')
        raw = lzma.decompress(path.read_bytes())
        require(sha(raw) == expected, 'REUSED_RAW:' + name)
        cat = 'baseline' if key == '00' else 'candidate'
        spec = next(x for x in reader.specifications(p) if x['id'] == f'{cat}-ashwarden-v0')
        cells[key], _ = reader.validate([json.loads(x) for x in raw.splitlines()], spec, p)
        reuse[key] = {'path': str(path.relative_to(repo)), 'expanded': identity_manifest(raw),
                      'compressed': identity_manifest(path.read_bytes())}
    output.mkdir(parents=True)
    receipts = []; terminal = {'status': 'INCONCLUSIVE', 'packages_admitted': 0, 'p9_certified': False}
    try:
        with tempfile.TemporaryDirectory(prefix='p9-attribution-') as temp:
            projects = execution.prepare(repo, Path(temp), p)
            parent_raw = {k: (v / 'content/full-content.json').read_bytes() for k, v in projects.items()}
            recipes = hybrids(parent_raw['baseline'], parent_raw['candidate'])
            require({k: sha(v) for k, v in recipes.items()} == protocol['hybrid_content_sha256'], 'RECIPE_IDENTITY')
            modified_protocol = deepcopy(p); specs = []; project_map = {}
            for key, cat in [('01', 'baseline'), ('10', 'candidate')]:
                project = projects[cat]
                (project / 'content/full-content.json').write_bytes(recipes[key])
                modified_protocol['content_sha256'][key] = sha(recipes[key])
                modified_protocol['combat_sha256'][key] = p['combat_sha256'][cat]
                (output / f'content-{key}.json').write_bytes(recipes[key])
                imp = execution.command([str(engine), '--headless', '--path', str(project), '--import'],
                                        output, key + '-import', project, 120)
                receipts.append(imp); require(imp['failure'] is None, 'IMPORT:' + key)
                check = subprocess.run(['bash', 'tools/check_scripts.sh', 'probe.gd'], cwd=project,
                    env=dict(os.environ, GODOT=str(engine)), capture_output=True, timeout=120)
                (output / (key + '-parse.stdout')).write_bytes(check.stdout)
                (output / (key + '-parse.stderr')).write_bytes(check.stderr)
                require(check.returncode == 0 and b'ERROR:' not in check.stderr, 'PARSE:' + key)
                specs.append(dict(id='corner-' + key, catalogue=key, aspect='ashwarden', vow=0,
                                  arm=2, seed0=SEEDS[0], runs=128))
                project_map[key] = project
            with ThreadPoolExecutor(max_workers=2) as pool:
                receipts.extend(pool.map(lambda s: execution.execute(s, project_map[s['catalogue']], engine,
                                        output, modified_protocol), specs))
            require(all(r.get('status') == 'COMPLETE' for r in receipts[-2:]), 'INCOMPLETE_NEW_CELLS')
            for spec in specs:
                data = (output / (spec['id'] + '.ndjson')).read_bytes()
                cells[spec['catalogue']], _ = reader.validate([json.loads(x) for x in data.splitlines()], spec, modified_protocol)
            result = summarize(cells); save(output / 'RESULTS.json', result)
            terminal.update(status=result['status'])
    except Exception as exc:
        terminal['failure'] = repr(exc)
    raw_files = []
    for path in output.glob('*.ndjson'):
        raw = path.read_bytes()
        path.with_suffix(path.suffix + '.xz').write_bytes(lzma.compress(raw, preset=6))
        # Count actual exposed rows even if a later binding/analysis failed.
        lines = raw.splitlines(); captured = max(0, len(lines) - 1)
        raw_files.append({'name': path.name, 'raw': identity_manifest(raw), 'captured_outcome_lines': captured})
        path.unlink()
    terminal.update(reused=reuse, native_commands=receipts, new_capture=raw_files,
                    actual_new_captured_outcome_lines=sum(x['captured_outcome_lines'] for x in raw_files),
                    new_independent_confirmation_samples=0,
                    source_head=os.environ.get('GITHUB_SHA', 'LOCAL'),
                    source_sha256=protocol['source_sha256'])
    save(output / 'TERMINAL.json', terminal)
    return 0 if terminal['status'] != 'INCONCLUSIVE' else 3


def verify_completed(repo, output):
    """Read committed bytes only; never execute the engine during readback."""
    repo, output = Path(repo).resolve(), Path(output).resolve()
    p0 = json.loads((HERE / 'PROTOCOL.json').read_bytes())
    for name, digest in p0['source_sha256'].items():
        require(sha((HERE / name).read_bytes()) == digest, 'READBACK_SOURCE:' + name)
    guard = repo / 'research/p9-six-route/guardrail-confirmation-20260909'
    require(sha((guard / 'PROTOCOL.json').read_bytes()) == OLD_PROTOCOL, 'READBACK_OLD_PROTOCOL')
    p = json.loads((guard / 'PROTOCOL.json').read_bytes())
    sys.path.insert(0, str(guard))
    import read_control as reader
    cells = {}
    terminal = json.loads((output / 'TERMINAL.json').read_bytes())
    require(terminal['status'] != 'INCONCLUSIVE', 'UNFINISHED_CAPTURE')
    require(terminal['actual_new_captured_outcome_lines'] == 256, 'NEW_CAPTURE_COUNT')
    for key, (name, digest) in OLD_RAW.items():
        raw = lzma.decompress((guard / 'native-1' / (name + '.xz')).read_bytes())
        require(sha(raw) == digest, 'READBACK_REUSED_RAW')
        cat = 'baseline' if key == '00' else 'candidate'
        spec = next(x for x in reader.specifications(p) if x['id'] == f'{cat}-ashwarden-v0')
        cells[key], _ = reader.validate([json.loads(x) for x in raw.splitlines()], spec, p)
    require({x.name for x in output.glob('*.ndjson.xz')} == {'corner-01.ndjson.xz', 'corner-10.ndjson.xz'}, 'NEW_RAW_RECTANGLE')
    records = {r['name']: r for r in terminal['new_capture']}
    for key, parent in [('01', 'baseline'), ('10', 'candidate')]:
        content = (output / f'content-{key}.json').read_bytes()
        require(sha(content) == p0['hybrid_content_sha256'][key], 'READBACK_CONTENT')
        p['content_sha256'][key] = sha(content)
        p['combat_sha256'][key] = p['combat_sha256'][parent]
        raw = lzma.decompress((output / f'corner-{key}.ndjson.xz').read_bytes())
        require(identity_manifest(raw) == records[f'corner-{key}.ndjson']['raw'], 'NEW_RAW_IDENTITY')
        spec = dict(id='corner-' + key, catalogue=key, aspect='ashwarden', vow=0,
                    arm=2, seed0=SEEDS[0], runs=128)
        cells[key], _ = reader.validate([json.loads(x) for x in raw.splitlines()], spec, p)
    result = summarize(cells)
    require(render(result) == (output / 'RESULTS.json').read_bytes(), 'READOUT_BYTE_IDENTITY')
    return {'kind': 'OFFLINE_RECONSTRUCTION_OF_TWO_NEW_AND_TWO_REUSED_CORNERS',
            'result_sha256': sha(render(result)), 'new_native_runs': 0,
            'old_outcomes_reused': 256, 'new_diagnostic_outcomes_verified': 256,
            'packages_admitted': 0, 'p9_certified': False}


if __name__ == '__main__':
    if len(sys.argv) == 4 and sys.argv[1] == '--verify':
        print(json.dumps(verify_completed(sys.argv[2], sys.argv[3]), sort_keys=True))
    elif len(sys.argv) == 4:
        raise SystemExit(run(*sys.argv[1:]))
    else:
        raise SystemExit('usage: attribution.py REPO ENGINE FRESH_OUTPUT | --verify REPO OUTPUT')
