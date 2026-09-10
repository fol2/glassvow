"""Qualify one inherited Hand intervention seam, preserve complete evidence.
No population, controller tuning, previous study replay, or P9 admission.
"""
from pathlib import Path
import argparse
import hashlib
import json
import lzma
import os
import shutil
import subprocess
import sys
import tarfile
import time

import build
import read_gate

ROOT = Path('research/p9-six-route/ash-inheritance-20260909')
HERE = ROOT / 'hand-adaptive-v1'
JOINT = ROOT / 'joint-controller-v1/execution-1'
ENGINE = '8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e'
FILES_BLOB = 'cc2081e21e7c603ef0624e399aeaab978a63f9d6'
BRANCH = 'research/p9-six-route-local-20260905'
NAMES = ('reference', 'qualified', 'public-mutant', 'exact-mutant')
require = build.require
sha = build.sha
blob = build.blob


def save(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def load(path): return json.loads(path.read_bytes())

def git(repo, *args):
    return subprocess.check_output(['git', '-C', str(repo), *args]).decode().strip()


def publish(repo, out, expected, message):
    require(git(repo, 'rev-parse', 'HEAD') == expected, 'LOCAL_WRITER_DRIFT')
    remote = git(repo, 'ls-remote', 'origin', 'refs/heads/' + BRANCH).split()[0]
    require(remote == expected, 'CONCURRENT_WRITER')
    rel = str(out.relative_to(repo))
    git(repo, 'add', '--sparse', rel)
    staged = git(repo, 'diff', '--cached', '--name-only').splitlines()
    require(staged and all(p.startswith(rel + '/') for p in staged), 'STAGED_SCOPE')
    git(repo, 'config', 'user.name', 'github-actions[bot]')
    git(repo, 'config', 'user.email', '41898282+github-actions[bot]@users.noreply.github.com')
    git(repo, 'commit', '-m', message)
    git(repo, 'push', 'origin', 'HEAD:refs/heads/' + BRANCH)
    head = git(repo, 'rev-parse', 'HEAD')
    require(git(repo, 'ls-remote', 'origin', 'refs/heads/' + BRANCH).split()[0] == head, 'PUSH_REF')
    if os.environ.get('GITHUB_ENV'):
        with open(os.environ['GITHUB_ENV'], 'a') as f: f.write('PUBLISHED_HEAD=' + head + '\n')
    return head


def setup(repo, work, out):
    source = repo / JOINT
    require(blob((source / 'FILES.json').read_bytes()) == FILES_BLOB, 'INPUT_MANIFEST')
    require(blob((source / 'REMOTE-READBACK.json').read_bytes()) == 'bf89a50cbc34c91689774d3fe25aab820f91076d', 'INPUT_READBACK')
    entries = {r['path']: r for r in load(source / 'FILES.json')}
    for name in ('SOURCE-MANIFEST.json', 'runtime-source.tar.xz'):
        data = (source / name).read_bytes(); record = entries[name]
        require(len(data) == record['bytes'] and sha(data) == record['sha256'], 'INPUT_BYTES:' + name)
    manifest = load(source / 'SOURCE-MANIFEST.json')
    expected = {m + '/' + p: r for m, files in manifest.items() for p, r in files.items()}
    reference = work / 'reference'; reference.mkdir(parents=True)
    with tarfile.open(source / 'runtime-source.tar.xz', 'r:xz') as tf:
        members = tf.getmembers()
        require(len(members) == len(expected) and {m.name for m in members} == set(expected), 'INPUT_ARCHIVE_COVERAGE')
        for m in members:
            p = Path(m.name)
            require(m.isfile() and not p.is_absolute() and '..' not in p.parts, 'ARCHIVE_PATH')
            data = tf.extractfile(m).read(); record = expected[m.name]
            require(len(data) == record['bytes'] and sha(data) == record['sha256'], 'MEMBER_BYTES:' + m.name)
            if p.parts[0] == 'aware':
                target = reference / Path(*p.parts[1:]); target.parent.mkdir(parents=True, exist_ok=True); target.write_bytes(data)
    paths = ('domain/rules/combat.gd', 'public_rollout.gd', 'observed_game.gd')
    original = tuple((reference / p).read_bytes() for p in paths)
    modified = build.patch(*original)
    projects = {'reference': reference}
    for name in NAMES[1:]:
        project = work / name; shutil.copytree(reference, project)
        for i, rel in enumerate(paths):
            data = original[i] if (name == 'public-mutant' and i == 1) or (name == 'exact-mutant' and i == 2) else modified[i]
            (project / rel).write_bytes(data)
        projects[name] = project
    manifests = {}
    for name, project in projects.items():
        shutil.copyfile(repo / HERE / 'gate.gd', project / 'gate.gd')
        manifests[name] = {str(p.relative_to(project)): {'bytes': p.stat().st_size, 'sha256': sha(p.read_bytes())}
                           for p in sorted(project.rglob('*')) if p.is_file()}
        changed = {rel for rel in manifest['aware'] if (project / rel).read_bytes() != (reference / rel).read_bytes()}
        wanted = set(paths) if name == 'qualified' else set(paths) - {'public_rollout.gd'} if name == 'public-mutant' else set(paths) - {'observed_game.gd'} if name == 'exact-mutant' else set()
        require(changed == wanted, 'EXACT_RUNTIME_DELTA:' + name)
    save(out / 'SOURCE-MANIFEST.json', manifests)
    with tarfile.open(out / 'runtime-source.tar.xz', 'w:xz') as tf:
        for name in NAMES:
            for rel in manifests[name]: tf.add(projects[name] / rel, arcname=name + '/' + rel, recursive=False)
    return projects


def command(cmd, cwd, out, label):
    started = time.monotonic()
    with (out / (label + '.stdout')).open('wb') as a, (out / (label + '.stderr')).open('wb') as b:
        try:
            p = subprocess.run(cmd, cwd=cwd, stdout=a, stderr=b, timeout=240, check=False)
            code = p.returncode
        except subprocess.TimeoutExpired:
            code = -999
    save(out / (label + '.receipt.json'), {'command': cmd, 'returncode': code, 'elapsed_seconds': time.monotonic() - started})
    errors = (out / (label + '.stderr')).read_text(errors='replace')
    require(code == 0 and not any(x in errors for x in ('SCRIPT ERROR:', 'Parse Error:', 'ERROR:')), 'COMMAND_FAILURE:' + label)


def run(repo, engine, out, work):
    require(not out.exists() and not work.exists(), 'NO_RERUN')
    out.mkdir(parents=True); work.mkdir(parents=True)
    head = git(repo, 'rev-parse', 'HEAD')
    t = {'status': 'INCONCLUSIVE', 'source_head': head, 'packages_admitted': 0, 'p9_certified': False, 'population_outcomes': 0}
    try:
        frozen = load(repo / HERE / 'FREEZE.json')
        for name, expected in frozen['source_sha256'].items():
            require(sha((repo / HERE / name).read_bytes()) == expected, 'FROZEN_SOURCE:' + name)
        require(sha(engine.read_bytes()) == ENGINE, 'ENGINE_IDENTITY')
        projects = setup(repo, work, out)
        head = publish(repo, out, head, 'research(p9): freeze exact Hand intervention and mutant runtimes before observations')
        command([str(engine), '--version'], work, out, 'engine')
        for name, project in projects.items():
            command([str(engine), '--headless', '--path', str(project), '--import'], project, out, name + '-import')
            command(['env', 'GODOT=' + str(engine), 'bash', 'tools/check_scripts.sh',
                     'domain/rules/combat.gd', 'public_rollout.gd', 'observed_game.gd', 'gate.gd'], project, out, name + '-parse')
            command([str(engine), '--headless', '--path', str(project), '-s', 'res://gate.gd', '--',
                     name, str(out / (name + '.jsonl')), str(out / (name + '.traces.jsonl'))], project, out, name + '-native')
        result = read_gate.check(out)
        save(out / 'RESULTS.json', result); t.update(result)
    except Exception as e:
        t['failure'] = repr(e)
    finally:
        for p in sorted(out.glob('*.jsonl')):
            p.with_suffix(p.suffix + '.xz').write_bytes(lzma.compress(p.read_bytes())); p.unlink()
        save(out / 'TERMINAL.json', t)
        save(out / 'FILES.json', [{'path': str(p.relative_to(out)), 'bytes': p.stat().st_size, 'sha256': sha(p.read_bytes())}
                                 for p in sorted(out.rglob('*')) if p.is_file() and p.name != 'FILES.json'])
        publish(repo, out, head, 'research(p9): preserve complete Hand clone qualification capture and actual terminal')
        print(json.dumps(t, indent=2))
    return 0 if t['status'] != 'INCONCLUSIVE' else 3


def verify(original, cold, receipt):
    require(not receipt.exists(), 'RECEIPT_EXISTS')
    data = (original / 'FILES.json').read_bytes(); require(data == (cold / 'FILES.json').read_bytes(), 'MANIFEST_BYTES')
    files = json.loads(data)
    require(len({r['path'] for r in files}) == len(files), 'DUPLICATE_PATH')
    for r in files:
        p = Path(r['path']); require(not p.is_absolute() and '..' not in p.parts, 'PATH')
        b = (cold / p).read_bytes()
        require(b == (original / p).read_bytes() and len(b) == r['bytes'] and sha(b) == r['sha256'], 'COLD_BYTES:' + str(p))
    t = load(cold / 'TERMINAL.json')
    reproduced = False
    if t['status'] != 'INCONCLUSIVE':
        r = read_gate.check(cold)
        require(r == load(cold / 'RESULTS.json') and all(t[k] == v for k, v in r.items()), 'DECISION_REPRODUCTION')
        reproduced = True
    save(receipt, {'kind': 'COMPLETE_HAND_ADAPTIVE_GATE_COLD_READBACK', 'files': len(files) + 1,
                   'all_bytes_equal': True, 'readout_reproduced': reproduced, 'status': t['status'],
                   'new_native_runs': 0, 'new_independent_samples': 0, 'packages_admitted': 0, 'p9_certified': False})


if __name__ == '__main__':
    if sys.argv[1] == 'run': raise SystemExit(run(*(Path(x).resolve() for x in sys.argv[2:])))
    elif sys.argv[1] == 'verify': verify(*(Path(x).resolve() for x in sys.argv[2:]))
    else: raise SystemExit('run REPO ENGINE OUT WORK | verify ORIGINAL COLD RECEIPT')
