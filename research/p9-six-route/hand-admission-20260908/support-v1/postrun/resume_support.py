"""Resume only absent fixed Hand configurations after a terminated workflow.

Delivery-only: never rerun a completed policy, overwrite a partial policy, change
inputs, or reinterpret an existing scientific terminal. The controller and
native per-invocation containment remain those of the frozen support study.
"""
from __future__ import annotations
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

PROTOCOL_HASH = '9f7b3ccc6e9560fa8df7a60e29382c57c53da46bcf09d2be616fb76430e62ca2'
PASS = 'HAND_NATURAL_SUPPORT_GATE_PASS_NOT_PACKAGE_ADMISSION'
FAIL = 'HAND_NATURAL_SUPPORT_GATE_FAIL_IN_FIXED_POLICY_FAMILY'


def require(ok, reason):
    if not ok:
        raise ValueError(reason)


def load(path):
    return json.loads(Path(path).read_bytes())


def plan(stage, configs):
    """Classify existence only; complete bytes must subsequently be verified."""
    root = Path(stage)
    expected = {c['id'] for c in configs}
    if root.exists():
        require({p.name for p in root.iterdir() if p.is_dir()} <= expected,
                'UNASSIGNED_POLICY_DIRECTORY')
    old, missing = [], []
    for cfg in configs:
        folder = root / cfg['id']
        if not folder.exists():
            missing.append(cfg)
        else:
            require(folder.is_dir() and not folder.is_symlink(), 'INDIRECT_POLICY')
            require((folder / 'CELL.json').is_file() and (folder / 'EXECUTION.json').is_file(),
                    'PARTIAL_POLICY_REQUIRES_NAMED_DIAGNOSIS:' + cfg['id'])
            require(load(folder / 'EXECUTION.json')['status'] == 'COMPLETE',
                    'FAILED_POLICY_REQUIRES_REPAIR:' + cfg['id'])
            old.append(cfg)
    return old, missing


def existing_terminal(capture):
    path = Path(capture) / 'TERMINAL.json'
    if not path.exists():
        return None
    terminal = load(path)
    require(terminal['status'] in (PASS, FAIL), 'EXISTING_INCONCLUSIVE_REQUIRES_DIAGNOSIS')
    require(terminal['packages_admitted'] == 0 and terminal['p9_certified'] is False,
            'SUPPORT_IS_NOT_ADMISSION')
    return terminal


def validate_policy(folder, cfg, audit):
    require(load(folder / 'CONFIG.json') == cfg, 'PARENT_CONFIG')
    parent = load(folder / 'EXECUTION.json')
    require(parent['status'] == 'COMPLETE' and parent['config_id'] == cfg['id'], 'PARENT_STATUS')
    children, rows, observed = [], [], []
    for offset in range(cfg['runs']):
        child = dict(cfg, seed0=cfg['seed0'] + offset, runs=1,
                     id=cfg['id'] + '-s' + str(cfg['seed0'] + offset))
        receipt, row = audit.verify_child(folder / child['id'], child, observed)
        children.append(receipt)
        rows.append(row)
    require(parent['children'] == children, 'CHILD_RECEIPTS')
    require(parent['seeds_counted_once'] == [r['seed'] for r in rows], 'SEED_AGGREGATION')
    cell = dict(policy_id=cfg['policy_id'], policy_index=cfg['policy_index'],
                vow=cfg['vow'], route_preference=cfg['route'], runs=rows)
    require(load(folder / 'CELL.json') == cell, 'CELL_AGGREGATION')
    return cell


def main(repo, study, engine, push=False):
    repo, study, engine = (Path(p).resolve() for p in (repo, study, engine))
    sys.path[:0] = [str(study), str(Path(__file__).parent)]
    import audit_terminal as audit
    import run_support as runner
    import execute_support as delivery
    from cohort import configurations, ENGINE, CONTENT, identity, policies
    capture = study / 'capture-1'
    terminal = existing_terminal(capture)
    if terminal:
        print(json.dumps({'status': 'EXISTING_TERMINAL_NO_EXECUTION', 'terminal': terminal['status']}))
        return 0
    p = load(study / 'PROTOCOL.json')
    require(identity(p) == PROTOCOL_HASH, 'PROTOCOL_IDENTITY')
    require(identity(policies()) == p['policy_manifest_sha256'], 'POLICY_IDENTITY')
    require(runner.sha(engine.read_bytes()) == ENGINE, 'ENGINE_IDENTITY')
    for name, digest in p['source_sha256'].items():
        require(runner.sha((study / name).read_bytes()) == digest, 'FROZEN_SOURCE:' + name)
    require(runner.sha((study.parent / 'hand_rules.gd').read_bytes()) == p['hand_rules_sha256'], 'RULES')
    require(capture.is_dir(), 'ORIGINAL_CAPTURE_MISSING')
    # Reuse the fixed eight endpoints, not a fresh engine smoke or population row.
    delivery.bound_smoke(capture / 'integration')
    source_head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo).decode().strip()
    readbacks, stages, reused, executed = [], {}, {}, {}
    with tempfile.TemporaryDirectory(prefix='p9-fixed-resume-') as temp:
        project = Path(temp) / 'candidate'
        subprocess.run([sys.executable, str(study / 'assemble_support.py'), str(repo),
                        str(study.parent), str(project)], check=True, timeout=120)
        require(runner.sha((project / 'content/full-content.json').read_bytes()) == CONTENT, 'CONTENT')
        logs = capture / 'resume-delivery'; logs.mkdir(exist_ok=False)
        env = dict(os.environ, GODOT=str(engine), GODOT_SILENCE_ROOT_WARNING='1')
        for name, command in [('import', [str(engine), '--headless', '--path', str(project), '--import']),
                              ('parse', ['bash', 'tools/check_scripts.sh', 'hand_rules.gd',
                                         'hand_game.gd', 'support_runner.gd'])]:
            result = subprocess.run(command, cwd=project, env=env, capture_output=True, timeout=120)
            (logs / (name + '.stdout')).write_bytes(result.stdout)
            (logs / (name + '.stderr')).write_bytes(result.stderr)
            require(result.returncode == 0 and b'ERROR:' not in result.stderr, 'PREEXECUTION:' + name)
        for vow in (5, 0):
            stage = capture / f'v{vow}'; configs = configurations(vow)
            old, missing = plan(stage, configs); stage.mkdir(exist_ok=True)
            cells = {c['policy_index']: validate_policy(stage / c['id'], c, audit) for c in old}
            reused[str(vow)] = len(old); executed[str(vow)] = 0
            for start in range(0, len(missing), 8):
                batch = missing[start:start + 8]
                with ThreadPoolExecutor(max_workers=2) as pool:
                    receipts = list(pool.map(lambda c: delivery.sliced(c, project, engine, stage / c['id']), batch))
                complete = all(r['status'] == 'COMPLETE' for r in receipts)
                if complete:
                    for cfg in batch:
                        cells[cfg['policy_index']] = load(stage / cfg['id'] / 'CELL.json')
                    executed[str(vow)] += len(batch)
                runner.save(stage / 'PROGRESS.json', {'closed_policies': len(cells), 'complete_chunk': complete,
                    'whole_stage_decision': 'NOT_EVALUATED_UNTIL_COMPLETE', 'p9_certified': False})
                receipt = runner.publication(capture, f'research(p9): preserve fixed V{vow} missing support configurations', push)
                if receipt: readbacks.append(receipt)
                require(complete, 'NEW_INCOMPLETE_CAPTURE_REQUIRES_DIAGNOSIS')
            result = runner.summarize([cells[i] for i in range(128)])
            target = stage / 'RESULTS.json'
            if target.exists():
                require(target.read_bytes() == runner.dump(result), 'EXISTING_SCIENTIFIC_RESULT_CHANGED')
            else:
                runner.save(target, result)
            stages[str(vow)] = result['status']
            if result['status'] != PASS: break
        terminal = {'status': result['status'], 'last_completed_vow': vow, 'readbacks': readbacks,
                    'packages_admitted': 0, 'p9_certified': False,
                    'delivery_resume': {'source_head': source_head, 'reused_policies': reused,
                        'executed_missing_policies': executed, 'stages': stages,
                        'new_independent_samples': 0,
                        'scope': 'Existing complete bytes retained. Absent outputs may have been executed before venue interruption; no fresh-confirmation claim.'}}
        runner.save(capture / 'TERMINAL.json', terminal)
        runner.publication(capture, 'research(p9): close unchanged support assignment after delivery resume', push)
        print(json.dumps({'status': terminal['status'], 'reused': reused, 'executed': executed}))
    return 0


if __name__ == '__main__':
    raise SystemExit(main(*sys.argv[1:4], push='--push' in sys.argv))
