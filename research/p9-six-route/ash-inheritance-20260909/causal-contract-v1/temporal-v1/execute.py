"""One bounded native qualification; reuse the immutable source archive.
No policy search, product edit, historical replay or implicit remote write.
"""
from __future__ import annotations
import hashlib
import json
import lzma
import os
from pathlib import Path
import resource
import shutil
import subprocess
import sys
import tarfile
import time
import check as C

HERE = Path(__file__).resolve().parent
SOURCES = ('CONTRACT.md', 'PROTOCOL.json', 'probe.gd', 'check.py', 'test_check.py', 'execute.py')


def load(path):
    return json.loads(Path(path).read_bytes())


def save(path, data):
    Path(path).write_text(json.dumps(data, indent=2) + '\n')


def normal(data):
    # JSON object keys are strings. Compare serialized readouts, not Python int keys.
    return json.loads(json.dumps(data))


def prepare(parent, project):
    p = load(HERE / 'PROTOCOL.json')
    parent, project = Path(parent), Path(project)
    C.require(not project.exists(), 'NEW_WORKSPACE_REQUIRED')
    packed = (parent / 'runtime-source.tar.xz').read_bytes()
    manifest_data = (parent / 'RUNTIME-MANIFEST.json').read_bytes()
    C.require(C.sha(packed) == p['runtime_archive_sha256'], 'ARCHIVE_IDENTITY')
    C.require(C.sha(manifest_data) == p['runtime_manifest_sha256'], 'MANIFEST_IDENTITY')
    manifest = json.loads(manifest_data)
    project.mkdir(parents=True)
    with tarfile.open(parent / 'runtime-source.tar.xz', 'r:xz') as archive:
        members = archive.getmembers()
        C.require(len(members) == len(manifest) and {m.name for m in members} == set(manifest), 'ARCHIVE_COVERAGE')
        for member in members:
            rel = Path(member.name)
            C.require(member.isfile() and not rel.is_absolute() and '..' not in rel.parts, 'ARCHIVE_PATH_TYPE')
            data = archive.extractfile(member).read()
            C.require(len(data) == manifest[member.name]['bytes'] and C.sha(data) == manifest[member.name]['sha256'], 'MEMBER_BYTES')
            target = project / rel; target.parent.mkdir(parents=True, exist_ok=True); target.write_bytes(data)
    C.require(C.sha((project / 'content/full-content.json').read_bytes()) == C.CONTENT, 'CONTENT')
    C.require(C.sha((project / 'domain/rules/combat.gd').read_bytes()) == C.COMBAT, 'COMBAT')
    shutil.copyfile(HERE / 'probe.gd', project / 'temporal_probe.gd')
    data = (project / 'temporal_probe.gd').read_bytes()
    manifest['temporal_probe.gd'] = {'bytes': len(data), 'sha256': C.sha(data)}
    return manifest


def command(args, out, name, seconds, cwd=None, cap=None):
    args = list(map(str, args)); started = time.monotonic()
    before = resource.getrusage(resource.RUSAGE_CHILDREN)
    env = dict(os.environ, GODOT_SILENCE_ROOT_WARNING='1', PYTHONDONTWRITEBYTECODE='1')
    code, error = None, None
    def limits():
        if cap is not None: resource.setrlimit(resource.RLIMIT_FSIZE, (cap, cap))
    with (out / (name + '.stdout')).open('wb') as stdout, (out / (name + '.stderr')).open('wb') as stderr:
        try:
            proc = subprocess.run(args, cwd=cwd, stdout=stdout, stderr=stderr, env=env,
                                  timeout=seconds, preexec_fn=limits if cap else None)
            code = proc.returncode
        except Exception as exc:
            error = repr(exc)
    after = resource.getrusage(resource.RUSAGE_CHILDREN)
    rec = {'command': args, 'cwd': str(cwd) if cwd else None, 'returncode': code,
           'failure': error, 'wall_seconds_report_only': time.monotonic()-started,
           'cpu_seconds_report_only': after.ru_utime+after.ru_stime-before.ru_utime-before.ru_stime,
           'stdout_sha256': C.sha((out/(name+'.stdout')).read_bytes()),
           'stderr_sha256': C.sha((out/(name+'.stderr')).read_bytes())}
    save(out/(name+'.RECEIPT.json'), rec)
    C.require(code == 0 and error is None, 'COMMAND_FAILURE:' + name)
    logs = (out/(name+'.stderr')).read_bytes()
    C.require(not any(x in logs for x in (b'SCRIPT ERROR', b'ERROR:', b'Failed to load script')), 'NATIVE_DIAGNOSTIC:' + name)
    return rec


def index(out):
    save(out/'FILES.json', [{'path': p.name, 'bytes': p.stat().st_size, 'sha256': C.sha(p.read_bytes())}
        for p in sorted(out.iterdir()) if p.is_file() and p.name != 'FILES.json'])


def run(parent, engine, out, project):
    parent, engine, out, project = (Path(x).resolve() for x in (parent, engine, out, project))
    C.require(not out.exists() and not project.exists(), 'NO_OVERWRITE_OR_BLIND_RERUN')
    out.mkdir(parents=True)
    terminal = {'status': 'INCONCLUSIVE', 'new_population_runs': 0, 'new_independent_samples': 0,
                'packages_admitted': 0, 'p9_certified': False, 'review_kind': 'SELF_REVIEW_NOT_INDEPENDENT'}
    stage = 'setup'
    try:
        protocol = load(HERE/'PROTOCOL.json'); freeze = load(HERE/'FREEZE.json')
        C.require(set(freeze['source_sha256']) == set(SOURCES), 'COMPLETE_SOURCE_FREEZE')
        for name, digest in freeze['source_sha256'].items():
            C.require(C.sha((HERE/name).read_bytes()) == digest, 'FROZEN_SOURCE:' + name)
        C.require(C.sha(engine.read_bytes()) == protocol['engine_sha256'], 'PINNED_ENGINE')
        manifest = prepare(parent, project); save(out/'RUNTIME-MANIFEST.json', manifest)
        save(out/'SOURCE-BINDING.json', {'freeze': freeze, 'runtime_archive_sha256': protocol['runtime_archive_sha256'],
            'content_sha256': C.CONTENT, 'combat_sha256': C.COMBAT,
            'venue': {'runner_os': os.environ.get('RUNNER_OS', sys.platform),
                      'github_run_id': os.environ.get('GITHUB_RUN_ID'),
                      'timing_scope': 'report-only; not the attested provenance profile'}})
        command([sys.executable, '-m', 'unittest', '-v', 'test_check'], out, 'tests', 30, HERE)
        command([engine, '--version'], out, 'engine', 20)
        command([engine, '--headless', '--path', project, '--import'], out, 'import', protocol['limits']['import_seconds'])
        command(['env', 'GODOT='+str(engine), 'bash', 'tools/check_scripts.sh', 'temporal_probe.gd'],
                out, 'parse', protocol['limits']['parse_seconds'], project)
        stage = 'native'
        target = out/'raw.jsonl'
        command([engine, '--headless', '--path', project, '-s', 'res://temporal_probe.gd', '--', target],
                out, 'native', protocol['limits']['native_seconds'], cap=protocol['limits']['raw_bytes'])
        raw = target.read_bytes(); C.require(len(raw) <= protocol['limits']['raw_bytes'], 'RAW_CEILING')
        packed = lzma.compress(raw); C.require(lzma.decompress(packed) == raw, 'LOSSLESS_CAPTURE')
        (out/'raw.jsonl.xz').write_bytes(packed); target.unlink()
        stage = 'readout'
        result = normal(C.read(out/'raw.jsonl.xz', manifest, freeze['source_sha256']['probe.gd']))
        save(out/'RESULTS.json', result)
        stage = 'native-mutation-tests'
        command(['env', 'P9_NATIVE_CAPTURE='+str(out/'raw.jsonl.xz'), sys.executable, '-m', 'unittest', '-v', 'test_check'],
                out, 'native-mutation-tests', 60, HERE)
        terminal.update({k: result[k] for k in ('status', 'fixtures', 'trajectories', 'native_reference_pairs', 'consumer_contrasts')})
    except Exception as exc:
        terminal.update(failure=repr(exc), failed_stage=stage)
        if stage == 'readout': terminal['status'] = 'TEMPORAL_QUALIFICATION_FAIL'
    finally:
        # Preserve partial native output after a delivery fault, without making
        # a missing terminal a complete scientific result.
        partial = out/'raw.jsonl'
        if partial.exists():
            raw = partial.read_bytes(); packed = lzma.compress(raw)
            C.require(lzma.decompress(packed) == raw, 'PARTIAL_LOSSLESS_CAPTURE')
            (out/'raw.jsonl.xz').write_bytes(packed); partial.unlink()
        save(out/'TERMINAL.json', terminal); index(out)
        print(json.dumps(terminal, indent=2))
    return 0 if terminal['status'] == C.PASS else 3


def verify(original, cold, receipt):
    original, cold, receipt = map(Path, (original, cold, receipt))
    C.require(not receipt.exists(), 'NO_RECEIPT_OVERWRITE')
    a, b = load(original/'FILES.json'), load(cold/'FILES.json')
    C.require(a == b, 'MANIFEST_EQUALITY')
    names = [r['path'] for r in a]
    C.require(len(names) == len(set(names)), 'DUPLICATE_MANIFEST_ENTRY')
    C.require({p.name for p in cold.iterdir() if p.is_file()} == set(names)|{'FILES.json'}, 'COLD_CAPTURE_COVERAGE')
    for row in a:
        name = row['path']; C.require(Path(name).name == name, 'MANIFEST_PATH')
        x, y = (original/name).read_bytes(), (cold/name).read_bytes()
        C.require(x == y and len(y) == row['bytes'] and C.sha(y) == row['sha256'], 'COLD_BYTES:'+name)
    binding = load(cold/'SOURCE-BINDING.json')
    for name, digest in binding['freeze']['source_sha256'].items():
        C.require(C.sha((HERE/name).read_bytes()) == digest, 'COLD_READER_SOURCE:'+name)
    terminal = load(cold/'TERMINAL.json')
    reproduced = False
    if terminal['status'] == C.PASS:
        got = normal(C.read(cold/'raw.jsonl.xz', load(cold/'RUNTIME-MANIFEST.json'), binding['freeze']['source_sha256']['probe.gd']))
        C.require(got == load(cold/'RESULTS.json'), 'COLD_NATIVE_READOUT')
        C.require(all(terminal[k] == got[k] for k in ('status','fixtures','trajectories','native_reference_pairs','consumer_contrasts')), 'TERMINAL_BINDING')
        reproduced = True
    save(receipt, {'kind':'TEMPORAL_CAPTURE_COLD_READBACK', 'files':len(names)+1,
         'all_bytes_equal':True, 'readout_reproduced':reproduced, 'status':terminal['status'],
         'new_native_runs':0, 'new_independent_samples':0, 'packages_admitted':0, 'p9_certified':False})


if __name__ == '__main__':
    action, *args = sys.argv[1:]
    if action == 'prepare': print(json.dumps(prepare(*args), indent=2))
    elif action == 'run': raise SystemExit(run(*args))
    elif action == 'verify': verify(*args)
    else: raise SystemExit('prepare PARENT PROJECT | run PARENT ENGINE OUTPUT PROJECT | verify ORIGINAL COLD RECEIPT')
