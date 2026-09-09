"""One preselected Bloodfire signed-arm screen; reuse the existing exact reader.

No scalar selection, protected seed, historical replay, or package admission.
The candidate is the already captured minimum delta, not the failed substrate.
"""
from __future__ import annotations
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import importlib.util
import json
import lzma
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile

ROOT = Path('research/p9-six-route')
MINIMUM = ROOT / 'ash-inheritance-20260909/minimal-v1'
SHARED = ROOT / 'guardrail-confirmation-20260909'
HERE = Path(__file__).resolve().parent
BRANCH = 'research/p9-six-route-local-20260905'


def require(ok, why):
    if not ok:
        raise ValueError(why)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def blob(data):
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()


def save(path, obj):
    Path(path).write_text(json.dumps(obj, indent=2) + '\n')


def module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def remote_head(repo):
    text = subprocess.check_output(['git', 'ls-remote', 'origin', 'refs/heads/' + BRANCH], cwd=repo, timeout=60).decode()
    return text.split()[0]


def publish(repo, output, expected, message):
    require(remote_head(repo) == expected, 'CONCURRENT_WRITER')
    relative = str(output.relative_to(repo))
    subprocess.run(['git', 'add', '--', relative], cwd=repo, check=True)
    staged = subprocess.check_output(['git', 'diff', '--cached', '--name-only'], cwd=repo).decode().splitlines()
    require(all(p.startswith(relative + '/') for p in staged), 'STAGED_SCOPE')
    if not staged:
        return expected
    subprocess.run(['git', 'commit', '-m', message], cwd=repo, check=True)
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo).decode().strip()
    subprocess.run(['git', 'push', 'origin', 'HEAD:refs/heads/' + BRANCH], cwd=repo, check=True, timeout=90)
    require(remote_head(repo) == head, 'PUSH_REF_NOT_OBSERVED')
    # This verifies the ref only. A separate cold checkout verifies payload bytes.
    return head


def prerequisite(terminal, readback, protocol):
    require(terminal['status'] == 'BLOODFIRE_MINIMAL_PREFLIGHT_PASS', 'PREFLIGHT_NOT_PASS')
    require(readback['all_archive_bytes_verified'] and readback['readout_reproduced'], 'PREFLIGHT_READBACK')
    old = protocol['next_screen_if_pass']
    require(old['seed0'] == 73309200 and old['seeds_per_grid'] == 128, 'PRESELECTED_COHORT')


def build_protocol(template, contract, assembly):
    p = json.loads(json.dumps(template))
    p['seed0'], p['seeds_per_grid'], p['arm'] = contract['seed0'], contract['seeds_per_grid'], 2
    p['content_sha256'] = {c: assembly[c]['content/full-content.json']['sha256'] for c in ('baseline', 'candidate')}
    p['combat_sha256'] = {c: assembly[c]['domain/rules/combat.gd']['sha256'] for c in ('baseline', 'candidate')}
    p['engine_sha256'] = contract['engine_sha256']
    p['containment'].update(invocation_seconds=120, raw_bytes_per_cell=67108864, workers=2)
    p['scope'] = 'Exact inherited minimum Bloodfire delta. Necessary signed arm2 screen only; no historical result carry.'
    p['source_parent_contract'] = contract
    return p


def check_old_assembly(actual, expected):
    # Before swapping the driver, every file built by the captured assembler must match.
    require(actual == expected, 'ASSEMBLED_SOURCE_DIFFERS_FROM_PREFLIGHT')


def execute(repo, engine, output, work, do_publish):
    repo, engine, output, work = [Path(p).resolve() for p in (repo, engine, output, work)]
    require(not output.exists() and not work.exists(), 'OUTPUT_EXISTS_NO_IMPLICIT_RERUN')
    output.mkdir(parents=True); work.mkdir(parents=True)
    contract = json.loads((HERE / 'PROTOCOL.json').read_bytes())
    initial = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo).decode().strip()
    latest = initial
    terminal = {'status': 'INCONCLUSIVE', 'source_head': initial,
                'new_independent_confirmation_samples': 0, 'packages_admitted': 0, 'p9_certified': False}
    try:
        for relative, expected in contract['git_blob_inputs'].items():
            require(blob((repo / relative).read_bytes()) == expected, 'SOURCE_IDENTITY:' + relative)
        for name, expected in contract['own_sha256'].items():
            require(sha((HERE / name).read_bytes()) == expected, 'OWN_SOURCE:' + name)
        require(sha(engine.read_bytes()) == contract['engine_sha256'], 'ENGINE_IDENTITY')
        minimal = json.loads((repo / MINIMUM / 'PROTOCOL.json').read_bytes())
        prior = repo / MINIMUM / 'execution-1'
        prerequisite(json.loads((prior / 'TERMINAL.json').read_bytes()),
                     json.loads((prior / 'REMOTE-READBACK.json').read_bytes()), minimal)
        build = module(repo / MINIMUM / 'build.py', 'bloodfire_build')
        sys.path.insert(0, str(repo / SHARED))
        import execute_control as executor
        import read_control as reader
        old_assembly = json.loads((prior / 'ASSEMBLY.json').read_bytes())
        projection = build.selected_content(repo, output / 'selected-binding')
        projects = {}
        for cat in ('baseline', 'candidate'):
            project = work / cat
            actual = build.assemble(repo, project, projection, cat == 'candidate')
            check_old_assembly(actual, old_assembly[cat])
            shutil.copyfile(repo / SHARED / 'probe.gd', project / 'probe.gd')
            shutil.copyfile(repo / 'tools/balance_sweep.gd', project / 'tools/balance_sweep.gd')
            projects[cat] = project
        template = json.loads((repo / SHARED / 'PROTOCOL.json').read_bytes())
        p = build_protocol(template, contract, old_assembly)
        p['domain_manifest_sha256'] = {}
        manifests = {}
        for cat, project in projects.items():
            domain = {str(f.relative_to(project)): sha(f.read_bytes()) for f in sorted((project / 'domain').rglob('*')) if f.is_file()}
            p['domain_manifest_sha256'][cat] = sha(json.dumps(domain, sort_keys=True, separators=(',', ':')).encode())
            manifests[cat] = {str(f.relative_to(project)): {'bytes': f.stat().st_size, 'sha256': sha(f.read_bytes())}
                              for f in sorted(project.rglob('*')) if f.is_file()}
            for name, digest in p['tool_sha256'].items():
                require(sha((project / 'tools' / name).read_bytes()) == digest, 'SHIPPING_TOOL:' + name)
        save(output / 'RESOLVED-PROTOCOL.json', p)
        save(output / 'RUNTIME-SOURCE-MANIFEST.json', manifests)
        with tarfile.open(output / 'runtime-source.tar.xz', 'w:xz') as archive:
            for cat, project in projects.items():
                for relative in manifests[cat]:
                    archive.add(project / relative, arcname=cat + '/' + relative)
        # Derived identities are persisted remotely before any game or outcome.
        if do_publish:
            latest = publish(repo, output, latest, 'research(p9): freeze exact minimum Bloodfire screen inputs before outcomes')
        setup = output / 'setup'; setup.mkdir()
        for cat, project in projects.items():
            r = executor.command([str(engine), '--headless', '--path', str(project), '--import'], setup, cat + '-import', project, 120)
            require(r['failure'] is None, 'IMPORT:' + cat)
            env = dict(os.environ, GODOT=str(engine))
            r = subprocess.run(['bash', 'tools/check_scripts.sh', 'domain/rules/combat.gd', 'probe.gd'], cwd=project,
                               env=env, capture_output=True, timeout=120)
            (setup / (cat + '-parse.stdout')).write_bytes(r.stdout)
            (setup / (cat + '-parse.stderr')).write_bytes(r.stderr)
            require(r.returncode == 0 and b'SCRIPT ERROR' not in r.stderr, 'PARSE:' + cat)
        # Headers only: source and arm binding are validated before outcome rows.
        headers = output / 'headers'; headers.mkdir()
        for cat in ('baseline', 'candidate'):
            cfg = dict(id=cat + '-header', catalogue=cat, aspect='ashwarden', vow=0, arm=2, seed0=p['seed0'], runs=0)
            r = executor.execute(cfg, projects[cat], engine, headers, p)
            require(r['status'] == 'COMPLETE', 'HEADER_BINDING:' + cat)
        raw = output / 'raw'; raw.mkdir()
        specs = reader.specifications(p)
        receipts = []
        # Pair an unchanged baseline and candidate per context; no decision peeking.
        specs.sort(key=lambda c: (c['aspect'], c['vow'], c['catalogue']))
        for offset in range(0, len(specs), 2):
            with ThreadPoolExecutor(max_workers=2) as pool:
                batch = list(pool.map(lambda cfg: executor.execute(cfg, projects[cfg['catalogue']], engine, raw, p), specs[offset:offset + 2]))
            receipts.extend(batch)
            for cfg in specs[offset:offset + 2]:
                path = raw / (cfg['id'] + '.ndjson')
                if path.exists():
                    data = path.read_bytes(); packed = lzma.compress(data, preset=6)
                    require(lzma.decompress(packed) == data, 'COMPRESSION_IDENTITY')
                    path.with_suffix('.ndjson.xz').write_bytes(packed); path.unlink()
            save(output / 'PROGRESS.json', {'completed_cells': sum(r['status'] == 'COMPLETE' for r in receipts),
                                           'assigned_cells': 8, 'receipts': receipts, 'scientific_decision': 'NOT_EVALUATED_UNTIL_COMPLETE'})
            if do_publish:
                latest = publish(repo, output, latest, 'research(p9): preserve complete Bloodfire matched-control chunk')
            require(all(r['status'] == 'COMPLETE' for r in batch), 'INCOMPLETE_NATIVE_CAPTURE')
        result = reader.analyze(raw, p)
        save(output / 'RESULTS.json', result)
        terminal.update(status=result['status'], rows=result['rows'], decision=result['decision'])
    except Exception as exc:
        terminal['failure'] = repr(exc)
    finally:
        save(output / 'TERMINAL.json', terminal)
        inventory = [{'path': str(f.relative_to(output)), 'bytes': f.stat().st_size, 'sha256': sha(f.read_bytes())}
                     for f in sorted(output.rglob('*')) if f.is_file()]
        save(output / 'FILES.json', inventory)
        if do_publish:
            latest = publish(repo, output, latest, 'research(p9): preserve terminal of fixed minimum Bloodfire control screen')
        print(json.dumps({'published_head': latest, 'terminal': terminal}, sort_keys=True))
        if os.environ.get('GITHUB_ENV'):
            with open(os.environ['GITHUB_ENV'], 'a') as env:
                env.write('PUBLISHED_HEAD=' + latest + '\n')
    return 0 if terminal['status'] != 'INCONCLUSIVE' else 3


def cold_verify(repo, original, cold, receipt_path):
    repo, original, cold, receipt_path = map(Path, (repo, original, cold, receipt_path))
    entries = json.loads((original / 'FILES.json').read_bytes())
    for r in entries:
        a, b = original / r['path'], cold / r['path']
        require(a.read_bytes() == b.read_bytes(), 'REMOTE_BYTE_MISMATCH:' + r['path'])
        require(a.stat().st_size == r['bytes'] and sha(a.read_bytes()) == r['sha256'], 'FILE_MANIFEST:' + r['path'])
    require((original / 'FILES.json').read_bytes() == (cold / 'FILES.json').read_bytes(), 'MANIFEST_READBACK')
    terminal = json.loads((cold / 'TERMINAL.json').read_bytes())
    sys.path.insert(0, str(repo / SHARED))
    import read_control
    reproduced = False
    if terminal['status'] != 'INCONCLUSIVE':
        result = read_control.analyze(cold / 'raw', json.loads((cold / 'RESOLVED-PROTOCOL.json').read_bytes()))
        require(result == json.loads((cold / 'RESULTS.json').read_bytes()), 'READOUT_MISMATCH')
        reproduced = True
    save(receipt_path, {'kind': 'BLOODFIRE_CONTROL_FULL_COLD_READBACK', 'files_checked': len(entries) + 1,
                        'all_bytes_equal': True, 'readout_reproduced': reproduced,
                        'scientific_status': terminal['status'], 'rows': terminal.get('rows', 0),
                        'new_native_runs_in_readback': 0, 'packages_admitted': 0, 'p9_certified': False})


if __name__ == '__main__':
    p = argparse.ArgumentParser(); sub = p.add_subparsers(dest='mode', required=True)
    run = sub.add_parser('run')
    for key in ('repo', 'engine', 'output', 'work'): run.add_argument(key)
    run.add_argument('--publish', action='store_true')
    verify = sub.add_parser('verify')
    for key in ('repo', 'original', 'cold', 'receipt'): verify.add_argument(key)
    a = p.parse_args()
    if a.mode == 'run': raise SystemExit(execute(a.repo, a.engine, a.output, a.work, a.publish))
    cold_verify(a.repo, a.original, a.cold, a.receipt)
