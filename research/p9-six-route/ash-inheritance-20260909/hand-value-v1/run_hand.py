"""Fixed Hand group-source/consumer worlds; reuse qualified runtime and readers."""
from concurrent.futures import ThreadPoolExecutor
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile

from read_hand import BASE, WORLDS, config, read_stage, require, resource_ok, blob

HERE = Path(__file__).resolve().parent
HAND = BASE / 'hand-adaptive-v1'
JOINT = BASE / 'joint-controller-v1'
FLAGS = ('hand_preparation_enabled', 'hand_surge_enabled', 'hand_phantom_enabled')
ENGINE = '8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e'


def sha(data): return hashlib.sha256(data).hexdigest()
def load(path): return json.loads(Path(path).read_bytes())
def save(path, value): Path(path).write_text(json.dumps(value, indent=2) + '\n')


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def dependencies(repo):
    path = repo / JOINT / 'joint.py'
    require(blob(path.read_bytes()) == '9571bfbc8005df4f9b8e425314eb83e892a6f283', 'DEPENDENCY_JOINT')
    one, value, base, reader, _, _, _ = module('hand_value_dependencies', path).dependencies(repo)
    return one, value, base, reader


def observer_world(data, world):
    require(world in WORLDS, 'WORLD')
    text = data.decode()
    require('func _init(' not in text, 'UNEXPECTED_INITIALIZER')
    require(all('"' + f + '"' in text for f in FLAGS), 'QUALIFIED_EXACT_CLONE_FLAGS')
    a, b = (x == '1' for x in world)
    values = (a, a, b)
    initialization = '\n\nfunc _init(db: ContentDB, state: RunState) -> void:\n\tsuper(db, state)\n'
    for flag, value in zip(FLAGS, values):
        initialization += '\trules.set("' + flag + '", ' + str(value).lower() + ')\n'
    anchor = 'func apply(cmd: Dictionary) -> Array[Dictionary]:\n'
    checks = ''.join('\tassert(rules.get("' + flag + '") == ' + str(value).lower() + ', "HAND_WORLD_DRIFT")\n'
                     for flag, value in zip(FLAGS, values))
    require(text.count(anchor) == 1, 'APPLY_ANCHOR')
    return (text.replace(anchor, anchor + checks, 1) + initialization).encode()



def validate_contract(contract):
    expected = {'policy_root': 73409000, 'policies': 128, 'policies_per_cell': 2,
                'seeds_per_cell': 4, 'seed_base': 73620100, 'seed_vow_stride': 1000,
                'qualification_seed': 73620010, 'vows': [5, 0], 'worlds': list(WORLDS)}
    require(contract['assignment'] == expected, 'FROZEN_ASSIGNMENT')
    require(contract['limits'] == {'cpu_seconds_per_world_per_vow': 3600, 'seconds_per_invocation': 240,
                                   'raw_bytes_per_stream': 536870912, 'max_workers': 4}, 'FROZEN_CONTAINMENT')
    require(contract['primary'] == {'outcome': 'native_win', 'contrasts': ['11-01', '11-10', '11-10-01+00'],
                                   'bootstrap_samples': 10000, 'bootstrap_seed': 421,
                                   'lower_quantile': 0.05/6, 'upper_quantile': 1-0.05/6,
                                   'positive_lower_bounds_required': 3}, 'FROZEN_READOUT')
    require(contract['packages_admitted'] == 0 and contract['p9_certified'] is False, 'NO_ADMISSION')


def setup(repo, work, out, one):
    root = repo / HAND
    proof = load(root / 'closure-1/REMOTE-READBACK.json')
    require(proof['all_bytes_equal'] and proof['call_path_reproduced'], 'HAND_CLOSURE_READBACK')
    bound = load(root / 'closure-1/PLANNER-CALL-PATH.json')
    require(bound['all_named_public_clone_call_sites_use_tested_wrapper'], 'ACTUAL_DISPATCH')
    for record in proof['files']:
        if record['path'].startswith(str(HAND) + '/'):
            data = (repo / record['path']).read_bytes()
            require(len(data) == record['bytes'] and sha(data) == record['sha256'], 'CLOSURE_DEPENDENCY')
    capture = root / 'execution-1'
    entries = {r['path']: r for r in load(capture / 'FILES.json')}
    for name in ('SOURCE-MANIFEST.json', 'runtime-source.tar.xz'):
        data = (capture / name).read_bytes(); record = entries[name]
        require(len(data) == record['bytes'] and sha(data) == record['sha256'], 'CAPTURE_SOURCE:' + name)
    source = load(capture / 'SOURCE-MANIFEST.json')
    expected = {name + '/' + rel: r for name, files in source.items() for rel, r in files.items()}
    reference = work / 'reference'; reference.mkdir()
    with tarfile.open(capture / 'runtime-source.tar.xz', 'r:xz') as archive:
        members = archive.getmembers()
        require(len(members) == len(expected) and {m.name for m in members} == set(expected), 'ARCHIVE_COVERAGE')
        for member in members:
            rel = Path(member.name)
            require(member.isfile() and not rel.is_absolute() and '..' not in rel.parts, 'ARCHIVE_PATH')
            data = archive.extractfile(member).read(); record = expected[member.name]
            require(len(data) == record['bytes'] and sha(data) == record['sha256'], 'ARCHIVE_BYTES')
            if rel.parts[0] == 'qualified':
                target = reference / Path(*rel.parts[1:]); target.parent.mkdir(parents=True, exist_ok=True); target.write_bytes(data)
    for name, record in bound['sources'].items():
        require(sha((reference / name).read_bytes()) == record['sha256'], 'QUALIFIED_POLICY:' + name)
    previous = load(repo / JOINT / 'execution-1/RESOLVED-PROTOCOLS.json')['aware']
    require(blob((repo / JOINT / 'execution-1/RESOLVED-PROTOCOLS.json').read_bytes()) == 'd4495e20d026c9a3a4fdafcb388c9367c124e7a2', 'TRANSPORT_PROTOCOL')
    requested = sorted({73620010} | {s for v in (5, 0) for i in range(0, 128, 2) for s in config(i, v)['seeds']})
    tracked = subprocess.check_output(['git', '-C', str(repo), 'ls-files', 'research/p9-six-route/**/*.config.json']).decode().splitlines()
    require(tracked and all((repo / p).is_file() for p in tracked), 'COMPLETE_SEED_METADATA_CHECKOUT')
    require(not any(5000 <= s <= 5199 for s in requested), 'PROTECTED_SEEDS')
    seed_check = one.seed_check(repo, HERE, requested)
    seed_check['tracked_configurations'] = len(tracked)
    save(out / 'SEED-METADATA.json', seed_check)
    projects, protocols = {}, {}
    original = (reference / 'observed_game.gd').read_bytes()
    for world in WORLDS:
        target = work / world; shutil.copytree(reference, target)
        (target / 'observed_game.gd').write_bytes(observer_world(original, world))
        changed = [rel for rel in source['qualified'] if (target / rel).read_bytes() != (reference / rel).read_bytes()]
        require(changed == ['observed_game.gd'], 'ONLY_WORLD_INITIALIZATION')
        p = {'kind': 'FIXED_HAND_GROUP_VALUE_TRANSPORT', 'method': 'planner', 'raw_bytes_per_stream': 536870912,
             'runtime': copy.deepcopy(previous['runtime']), 'scientific_contract': 'CONTRACT.json', 'world': world}
        for key, name in [('combat_sha256', 'domain/rules/combat.gd'), ('observer_sha256', 'observed_game.gd')]:
            p['runtime'][key] = sha((target / name).read_bytes())
        for name, digest in p['runtime']['sources'].items():
            require(sha((target / 'tools' / name).read_bytes()) == digest, 'UNCHANGED_TRANSPORT_SOURCE')
        for key, name in [('content_sha256', 'content/full-content.json'), ('probe_sha256', 'probe.gd'), ('bridge_sha256', 'combat_bridge.gd')]:
            require(sha((target / name).read_bytes()) == p['runtime'][key], 'UNCHANGED_RUNTIME:' + name)
        projects[world], protocols[world] = target, p
    all_projects = {'reference': reference, **projects}
    manifests = {}
    for name, target in all_projects.items():
        shutil.copyfile(HERE / 'entry.gd', target / 'entry.gd')
        manifests[name] = {str(p.relative_to(target)): {'bytes': p.stat().st_size, 'sha256': sha(p.read_bytes())}
                           for p in sorted(target.rglob('*')) if p.is_file()}
    save(out / 'SOURCE-MANIFEST.json', manifests)
    save(out / 'RESOLVED-PROTOCOLS.json', protocols)
    with tarfile.open(out / 'runtime-source.tar.xz', 'w:xz') as archive:
        for name, records in manifests.items():
            for rel in records: archive.add(all_projects[name] / rel, arcname=name + '/' + rel, recursive=False)
    return all_projects, protocols


def entry_result(out):
    records = {}
    for name in ('reference', *WORLDS):
        world = '11' if name == 'reference' else name
        records[name] = load(out / (name + '.json'))
        require(records[name]['kind'] == 'HAND_WORLD_ENTRY', 'ENTRY_KIND')
        require(records[name]['masks'] == [world[0] == '1', world[0] == '1', world[1] == '1'], 'ENTRY_MASKS')
        require(records[name]['clone_masks_preserved'] is True and records[name]['factual_untouched'] is True, 'ENTRY_CLONES')
        require(len(records[name]['steps']) == 3 and all(r['after']['return'] is True for r in records[name]['steps']), 'ENTRY_COMMANDS')
    for extension in ('.json', '.jsonl'):
        require((out / ('reference' + extension)).read_bytes() == (out / ('11' + extension)).read_bytes(), 'ALL_ON_ENTRY_PARITY')
    return {'status': 'HAND_WORLD_ENTRY_BINDING_PASS', 'worlds': list(WORLDS),
            'all_on_entry_state_events_equal': True, 'population_outcomes': 0,
            'scope': 'New constructor assignment and per-command invariant only; original384-mask qualification carried, not rerun.'}


def qualify(projects, engine, out, base):
    out.mkdir()
    for name, project in projects.items():
        base.command([str(engine), '--headless', '--path', str(project), '--import'], out, name + '-import')
        base.command(['env', 'GODOT=' + str(engine), 'bash', 'tools/check_scripts.sh', 'observed_game.gd', 'entry.gd'], out, name + '-parse', cwd=project)
        world = '11' if name == 'reference' else name
        base.command([str(engine), '--headless', '--path', str(project), '-s', 'res://entry.gd', '--', world,
                      str(out / (name + '.json')), str(out / (name + '.jsonl'))], out, name)
    result = entry_result(out)
    save(out / 'RESULTS.json', result)
    return result


def run(repo, engine, out, work):
    repo, engine, out, work = map(lambda p: Path(p).resolve(), (repo, engine, out, work))
    require(not out.exists() and not work.exists(), 'NO_RERUN')
    out.mkdir(parents=True); work.mkdir(parents=True)
    one, value, base, reader = dependencies(repo)
    head = base.git(repo, 'rev-parse', 'HEAD')
    terminal = {'status': 'INCONCLUSIVE', 'source_head': head, 'stages': {}, 'packages_admitted': 0, 'p9_certified': False}
    try:
        contract = load(HERE / 'CONTRACT.json')
        validate_contract(contract)
        freeze = load(HERE / 'FREEZE.json')
        for name, digest in freeze['source_sha256'].items():
            require(sha((HERE / name).read_bytes()) == digest, 'FROZEN_SOURCE:' + name)
        require(sha(engine.read_bytes()) == ENGINE, 'PINNED_ENGINE')
        projects, protocols = setup(repo, work, out, one)
        workers = min(4, len(os.sched_getaffinity(0)))
        require(workers >= 1, 'NO_WORKER')
        save(out / 'VENUE.json', {'worker_processes': workers, 'available_cpu_affinity': len(os.sched_getaffinity(0)),
                                   'runner_class': 'ubuntu-24.04', 'per_world_cpu_ceiling': 3600})
        head = base.publish(repo, out, head, 'research(p9): preserve fixed Hand world sources before observations')
        terminal['qualification'] = qualify(projects, engine, out / 'qualification', base)
        head = base.publish(repo, out, head, 'research(p9): preserve Hand world entry binding before population')
        for vow in (5, 0):
            stage = out / f'v{vow}'; stage.mkdir()
            for world in WORLDS: (stage / world).mkdir()
            specs = [(world, config(i, vow)) for i in range(0, 128, 2) for world in WORLDS]
            costs = {w: 0. for w in WORLDS}
            for offset in range(0, len(specs), 8):
                tasks = specs[offset:offset + 8]
                with ThreadPoolExecutor(max_workers=workers) as pool:
                    receipts = list(pool.map(lambda t: value.cell(t[1], projects[t[0]], engine, stage / t[0], protocols[t[0]], base, reader), tasks))
                for (world, _), receipt in zip(tasks, receipts):
                    if receipt['status'] == 'COMPLETE': costs[world] += receipt['cpu']['user'] + receipt['cpu']['system']
                save(stage / 'COST-PROGRESS.json', costs)
                head = base.publish(repo, out, head, f'research(p9): preserve Hand v{vow} matched group {offset // 8 + 1}')
                require(all(r['status'] == 'COMPLETE' for r in receipts), 'INCOMPLETE_ASSIGNED_CELL')
                require(resource_ok(costs), 'HAND_RESOURCE_CEILING')
            result = read_stage(stage, protocols, vow, repo, reader, value.read_value.validate_extra)
            save(stage / 'RESULTS.json', result)
            terminal['stages'][str(vow)] = {k: v for k, v in result.items() if k != 'secondary'}
            head = base.publish(repo, out, head, f'research(p9): preserve complete Hand v{vow} adaptive-value decision')
            if not result['pass_all']:
                terminal.update(status='HAND_ADAPTIVE_GROUP_VALUE_NOT_ESTABLISHED', last_vow=vow, v0_skipped=vow == 5)
                break
        else:
            terminal['status'] = 'HAND_ADAPTIVE_GROUP_VALUE_SUPPORTED_NOT_CERTIFICATE'
    except Exception as exc:
        terminal['failure'] = repr(exc)
    finally:
        save(out / 'TERMINAL.json', terminal)
        save(out / 'FILES.json', [{'path': str(p.relative_to(out)), 'bytes': p.stat().st_size, 'sha256': sha(p.read_bytes())}
                                  for p in sorted(out.rglob('*')) if p.is_file() and p.name != 'FILES.json'])
        head = base.publish(repo, out, head, 'research(p9): preserve actual Hand adaptive-value terminal and every captured byte')
        if os.environ.get('GITHUB_ENV'):
            with open(os.environ['GITHUB_ENV'], 'a') as env: env.write('PUBLISHED_HEAD=' + head + '\n')
        print(json.dumps(terminal, indent=2))
    return 3 if terminal['status'] == 'INCONCLUSIVE' else 0


def verify(repo, original, cold, receipt):
    repo, original, cold, receipt = map(Path, (repo, original, cold, receipt))
    require(not receipt.exists(), 'RECEIPT_EXISTS')
    _, value, _, reader = dependencies(repo)
    data = (original / 'FILES.json').read_bytes()
    require(data == (cold / 'FILES.json').read_bytes(), 'MANIFEST_EQUALITY')
    files = json.loads(data)
    require(len({r['path'] for r in files}) == len(files), 'DUPLICATE_PATH')
    for r in files:
        p = Path(r['path']); require(not p.is_absolute() and '..' not in p.parts, 'READBACK_PATH')
        b = (cold / p).read_bytes()
        require(b == (original / p).read_bytes() and len(b) == r['bytes'] and sha(b) == r['sha256'], 'READBACK_BYTES:' + str(p))
    terminal = load(cold / 'TERMINAL.json')
    protocols = load(cold / 'RESOLVED-PROTOCOLS.json') if terminal['stages'] else {}
    if 'qualification' in terminal:
        require(entry_result(cold / 'qualification') == terminal['qualification'] == load(cold / 'qualification/RESULTS.json'), 'ENTRY_REPRODUCTION')
    for vow, expected in terminal['stages'].items():
        actual = read_stage(cold / ('v' + vow), protocols, int(vow), repo, reader, value.read_value.validate_extra)
        require(actual == load(cold / ('v' + vow) / 'RESULTS.json'), 'EXACT_READOUT')
        require(all(actual[k] == v for k, v in expected.items()), 'TERMINAL_IDENTITY')
    save(receipt, {'kind': 'COMPLETE_HAND_ADAPTIVE_VALUE_COLD_READBACK', 'files': len(files) + 1,
                   'all_bytes_equal': True, 'reproduced_stages': list(terminal['stages']),
                   'scientific_status': terminal['status'], 'new_native_runs': 0, 'packages_admitted': 0, 'p9_certified': False})


if __name__ == '__main__':
    if sys.argv[1] == 'run': raise SystemExit(run(*sys.argv[2:]))
    elif sys.argv[1] == 'verify': verify(*sys.argv[2:])
    else: raise SystemExit('run REPO ENGINE OUT WORK | verify REPO ORIGINAL COLD RECEIPT')
