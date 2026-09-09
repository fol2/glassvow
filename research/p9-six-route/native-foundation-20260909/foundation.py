"""One baseline-restoration alternative, tested on disjoint signed-control seeds.

No scalar search: restore exactly Ash's original starter/Art definitions, not
arbitrary strength values. This wrapper reuses the existing signed driver and
reader; it never touches the earlier negative or the closed Hand support study.
"""
from concurrent.futures import ThreadPoolExecutor
from copy import deepcopy
import hashlib
import json
import lzma
import os
from pathlib import Path
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
OLD_HASH = 'f8eaf9dffc65fa30222c80083ca0397a80174837cf8be1134c39613bf1c860c7'
RESTORED = '91fd5de56727df42fdcb539b61e7cc7a32e77f3f85dbbe13baef3513e7003cfb'


def sha(data): return hashlib.sha256(data).hexdigest()
def require(ok, why):
    if not ok: raise ValueError(why)
def load(path): return json.loads(path.read_bytes())
def save(path, value): path.write_text(json.dumps(value, indent=2) + '\n')


def specification(old, contract):
    require(contract['seed0'] == 62090000 and contract['seeds_per_grid'] == 128, 'ONE_FIXED_NEW_PANEL')
    require(contract['candidate_sha256'] == RESTORED, 'NO_OTHER_CANDIDATE')
    p = deepcopy(old)
    p['seed0'] = contract['seed0']
    p['content_sha256']['candidate'] = RESTORED
    # Guard arithmetic, simulator, default policy, background rules stay unchanged.
    require(p['gates'] == old['gates'] and p['tool_sha256'] == old['tool_sha256'], 'GUARD_DRIFT')
    return p


def context(repo):
    guard = repo / 'research/p9-six-route/guardrail-confirmation-20260909'
    attribution = repo / 'research/p9-six-route/candidate-failure-20260909'
    require(sha((guard / 'PROTOCOL.json').read_bytes()) == OLD_HASH, 'OLD_PROTOCOL')
    c = load(HERE / 'PROTOCOL.json')
    require(sha((HERE / 'foundation.py').read_bytes()) == c['source_sha256']['foundation.py'], 'WRAPPER_IDENTITY')
    require(sha((attribution / 'attribution.py').read_bytes()) == c['attribution_sha256'], 'RESTORATION_FUNCTION_IDENTITY')
    old = load(guard / 'PROTOCOL.json')
    for name, digest in old['source_sha256'].items():
        require(sha((guard / name).read_bytes()) == digest, 'SIGNED_DRIVER:' + name)
    sys.path[:0] = [str(guard), str(attribution)]
    import execute_control as execution
    import read_control as reader
    from attribution import hybrids
    return old, specification(old, c), c, execution, reader, hybrids


def verify(repo, output):
    old, p, c, execution, reader, hybrids = context(repo)
    require(sha((output / 'content-candidate.json').read_bytes()) == RESTORED, 'PRESERVED_CONTENT')
    terminal = load(output / 'TERMINAL.json')
    require(terminal['status'] in ('SIGNED_CONTROL_NECESSARY_SCREEN_PASS_NOT_P9', 'SIGNED_CONTROL_NECESSARY_SCREEN_FAIL'), 'COMPLETE_TERMINAL')
    result = reader.analyze(output, p)
    require((json.dumps(result, indent=2) + '\n').encode() == (output / 'RESULTS.json').read_bytes(), 'READOUT_BYTES')
    for record in terminal['raw']:
        raw = lzma.decompress((output / (record['name'] + '.xz')).read_bytes())
        require(len(raw) == record['bytes'] and sha(raw) == record['sha256'], 'RAW_BYTES')
    return {'status': result['status'], 'result_sha256': sha((output / 'RESULTS.json').read_bytes()),
            'source_bound_raw_grids': len(terminal['raw']), 'new_native_runs': 0,
            'p9_certified': False, 'packages_admitted': 0}


def run(repo, engine, output):
    require(not output.exists(), 'NO_REPLAY')
    old, p, contract, execution, reader, hybrids = context(repo)
    require(sha(engine.read_bytes()) == old['engine_sha256'], 'ENGINE')
    output.mkdir(parents=True)
    terminal = {'status': 'INCONCLUSIVE', 'packages_admitted': 0, 'p9_certified': False}
    commands = []
    try:
        with tempfile.TemporaryDirectory(prefix='p9-native-foundation-') as tmp:
            projects = execution.prepare(repo, Path(tmp), old)
            baseline = (projects['baseline'] / 'content/full-content.json').read_bytes()
            candidate = (projects['candidate'] / 'content/full-content.json').read_bytes()
            restored = hybrids(baseline, candidate)['10']
            require(sha(restored) == RESTORED, 'EXACT_TWO_DEFINITION_RESTORATION')
            (projects['candidate'] / 'content/full-content.json').write_bytes(restored)
            (output / 'content-candidate.json').write_bytes(restored)
            for cat, project in projects.items():
                command = execution.command([str(engine), '--headless', '--path', str(project), '--import'],
                    output, cat + '-import', project, 120)
                commands.append(command); require(command['failure'] is None, 'IMPORT')
            with ThreadPoolExecutor(max_workers=2) as pool:
                children = list(pool.map(lambda cfg: execution.execute(cfg, projects[cfg['catalogue']],
                    engine, output, p), reader.specifications(p)))
            commands.extend(children)
            require(all(x['status'] == 'COMPLETE' for x in children), 'INCOMPLETE_RECTANGLE')
            result = reader.analyze(output, p); save(output / 'RESULTS.json', result)
            terminal['status'] = result['status']
    except Exception as exc:
        terminal['failure'] = repr(exc)
    raw = []
    for path in sorted(output.glob('*.ndjson')):
        data = path.read_bytes()
        path.with_suffix(path.suffix + '.xz').write_bytes(lzma.compress(data, preset=6))
        raw.append({'name': path.name, 'bytes': len(data), 'sha256': sha(data),
                    'captured_outcome_lines': max(0, len(data.splitlines()) - 1)})
        path.unlink()
    terminal.update(raw=raw, commands=commands, source_head=os.environ.get('GITHUB_SHA', 'LOCAL'),
                    protocol_sha256=sha((HERE / 'PROTOCOL.json').read_bytes()),
                    actually_captured_outcome_lines=sum(x['captured_outcome_lines'] for x in raw),
                    previous_candidate_remains_failed=True,
                    closed_hand_support_reopened=False,
                    scope='One separately specified restored-foundation candidate and disjoint control seeds only. Not package admission, C2, retention, duration or a release claim.')
    save(output / 'TERMINAL.json', terminal)
    return 0 if terminal['status'] != 'INCONCLUSIVE' else 3


if __name__ == '__main__':
    if len(sys.argv) == 4 and sys.argv[1] == '--verify':
        print(json.dumps(verify(Path(sys.argv[2]).resolve(), Path(sys.argv[3]).resolve()), sort_keys=True))
    elif len(sys.argv) == 4:
        raise SystemExit(run(*map(lambda x: Path(x).resolve(), sys.argv[1:])))
    else: raise SystemExit('foundation.py REPO ENGINE OUTPUT | --verify REPO OUTPUT')
