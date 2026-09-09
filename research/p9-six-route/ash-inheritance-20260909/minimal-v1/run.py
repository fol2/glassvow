"""One finite preflight. Preserve partial captures, diagnostics and sources."""
from __future__ import annotations
import hashlib
import importlib.util
import json
import os
import subprocess
import sys
import time
import traceback
from pathlib import Path
import build

spec = importlib.util.spec_from_file_location('proof_read', Path(__file__).with_name('read.py'))
reader = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reader)
HERE = Path(__file__).resolve().parent
ENGINE = '8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e'


def command(args, out, tag, cwd=None, env=None):
    start = time.monotonic()
    record = {'argv': args, 'cwd': str(cwd) if cwd else None}
    with (out / (tag + '.stdout')).open('wb') as stdout, (out / (tag + '.stderr')).open('wb') as stderr:
        try:
            process = subprocess.run(args, cwd=cwd, env=env, stdout=stdout, stderr=stderr, timeout=120)
            record['returncode'] = process.returncode
        except subprocess.TimeoutExpired:
            record.update(returncode=None, failure='WATCHDOG')
    record['elapsed_seconds'] = time.monotonic() - start
    log = (out / (tag + '.stderr')).read_bytes()
    record['diagnostic_error'] = any(term in log for term in (b'SCRIPT ERROR', b'Parse Error', b'Failed to load script', b'ERROR:'))
    record['okay'] = record['returncode'] == 0 and not record['diagnostic_error']
    return record


def run(repo, engine, out):
    build.require(not out.exists(), 'NO_REPLAY')
    out.mkdir(parents=True)
    terminal = {'status': 'INCONCLUSIVE', 'commands': [], 'new_independent_samples': 0,
                'packages_admitted': 0, 'p9_certified': False}
    try:
        freeze = json.loads((HERE / 'FREEZE.json').read_bytes())
        for name, digest in freeze['source_sha256'].items():
            build.require(build.sha((HERE / name).read_bytes()) == digest, 'SOURCE:' + name)
        build.require(build.sha(engine.read_bytes()) == ENGINE, 'ENGINE')
        projection = build.selected_content(repo, out / 'binding')
        projects = {mode: out / mode for mode in ('baseline', 'candidate')}
        identities = {mode: build.assemble(repo, project, projection, mode == 'candidate')
                      for mode, project in projects.items()}
        build.dump(out / 'ASSEMBLY.json', identities)
        record = command([sys.executable, '-m', 'unittest', '-v', 'test_minimal'], out, 'tests', HERE)
        terminal['commands'].append(record)
        build.require(record['okay'], 'PYTHON_TESTS')
        for name, project in projects.items():
            record = command([str(engine), '--headless', '--path', str(project), '--import'], out, name + '-import')
            terminal['commands'].append(record)
            build.require(record['okay'], 'IMPORT:' + name)
            env = os.environ.copy()
            env['GODOT'] = str(engine)
            record = command(['bash', str(project / 'tools/check_scripts.sh'), 'domain/rules/combat.gd', 'probe.gd'],
                             out, name + '-parse', env=env)
            terminal['commands'].append(record)
            build.require(record['okay'], 'PARSE:' + name)
        raw = out / 'raw'
        raw.mkdir()
        for mode in reader.MODES:
            project = projects['baseline' if mode == 'baseline' else 'candidate']
            record = command([str(engine), '--headless', '--path', str(project), '-s', 'res://probe.gd',
                              '--', mode, str(raw / (mode + '.jsonl'))], out, 'native-' + mode)
            terminal['commands'].append(record)
            build.require(record['okay'], 'NATIVE:' + mode)
            build.require((raw / (mode + '.jsonl')).stat().st_size < 64 * 1024 * 1024, 'RAW_CAP')
        result = reader.analyse(raw)
        build.dump(out / 'RESULTS.json', result)
        terminal['status'] = result['status']
    except Exception as error:
        terminal['failure'] = repr(error)
        (out / 'failure.log').write_text(traceback.format_exc())
    terminal['raw'] = [{'path': str(path.relative_to(out)), 'bytes': path.stat().st_size,
                        'sha256': build.sha(path.read_bytes())} for path in sorted(out.rglob('*.jsonl'))]
    terminal['source_head'] = os.environ.get('GITHUB_SHA', 'LOCAL')
    build.dump(out / 'TERMINAL.json', terminal)
    print(json.dumps({key: value for key, value in terminal.items() if key != 'commands'}, sort_keys=True))
    return 0 if terminal['status'] != 'INCONCLUSIVE' else 3


if __name__ == '__main__':
    raise SystemExit(run(*[Path(value).resolve() for value in sys.argv[1:]]))
