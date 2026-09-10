"""One fixed package-effect experiment. All old controller terminals stay closed."""
from concurrent.futures import ThreadPoolExecutor
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import sys
import tarfile

from read_causal import WORLDS, config, primary, read_stage, require, resource_ok
import qualify

HERE = Path(__file__).resolve().parent
BASE = Path('research/p9-six-route/ash-inheritance-20260909')
JOINT = BASE / 'joint-controller-v1'
ONE = BASE / 'planner-v1/one-sample-v1'
ENGINE = '8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e'
CONTRACT_BLOB = '1172fdaa598b2d3f9c02ba19d1c23fb2f029f5e7'
OBSERVER_BLOB = 'f1a60da814b2eff8b5c10bc7d2ce29e00d12268f'
FLAGS = ('bloodfire_enabled', 'bloodfire_producer_enabled', 'bloodfire_consumer_enabled')


def sha(b): return hashlib.sha256(b).hexdigest()
def blob(b): return hashlib.sha1(b'blob ' + str(len(b)).encode() + b'\0' + b).hexdigest()
def load(p): return json.loads(Path(p).read_bytes())
def save(p, x): Path(p).write_text(json.dumps(x, indent=2) + '\n')


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def once(text, old, new):
    require(text.count(old) == 1, 'SOURCE_ANCHOR:' + old[:60])
    return text.replace(old, new, 1)


def observer_source(data, world, unsafe=False):
    require(blob(data) == OBSERVER_BLOB and world in WORLDS, 'OBSERVER_OR_WORLD_IDENTITY')
    text = data.decode()
    text = once(text, '\tg.last_ret = clone_value(last_ret, memo)\n\treturn g',
                '\tg.last_ret = clone_value(last_ret, memo)\n'
                '\tfor flag: String in ["bloodfire_enabled", "bloodfire_producer_enabled", "bloodfire_consumer_enabled"]:\n'
                '\t\tg.rules.set(flag, rules.get(flag))\n\treturn g')
    old = 'g.rules.set("bloodfire_consumer_enabled", arm in ["B", "AB"])'
    if not unsafe:
        text = once(text, old, 'g.rules.set("bloodfire_consumer_enabled", bool(rules.get("bloodfire_consumer_enabled")) and arm in ["B", "AB"])')
    a, b = ('true' if x == '1' else 'false' for x in world)
    text += '\n\nfunc _init(db: ContentDB, state: RunState) -> void:\n\tsuper(db, state)\n'
    text += f'\trules.set("bloodfire_producer_enabled", {a})\n\trules.set("bloodfire_consumer_enabled", {b})\n'
    return text.encode()


def dependencies(repo):
    p = repo / JOINT / 'joint.py'
    require(blob(p.read_bytes()) == '9571bfbc8005df4f9b8e425314eb83e892a6f283', 'JOINT_DEPENDENCY')
    j = module('causal_joint_dependencies', p)
    return j.dependencies(repo)


def input_bytes(folder, entries, rel):
    require(rel in entries, 'UNMANIFESTED_INPUT:' + rel)
    data = (folder / rel).read_bytes()
    r = entries[rel]
    require(len(data) == r['bytes'] and sha(data) == r['sha256'], 'INPUT_BYTES:' + rel)
    return data


def setup(repo, work, out, one):
    p = load(HERE / 'CONTRACT.json')
    require(blob((HERE / 'CONTRACT.json').read_bytes()) == CONTRACT_BLOB, 'CONTRACT_IDENTITY')
    old = repo / JOINT / 'execution-1'
    require(blob((old / 'REMOTE-READBACK.json').read_bytes()) == 'bf89a50cbc34c91689774d3fe25aab820f91076d', 'INPUT_READBACK')
    require(blob((old / 'TERMINAL.json').read_bytes()) == '22f7efde277502c2cca68f70a9b476eb82a3b407', 'INPUT_TERMINAL')
    entries = {r['path']: r for r in load(old / 'FILES.json')}
    require(blob((old / 'FILES.json').read_bytes()) == 'cc2081e21e7c603ef0624e399aeaab978a63f9d6', 'INPUT_MANIFEST')
    sources = json.loads(input_bytes(old, entries, 'SOURCE-MANIFEST.json'))
    input_bytes(old, entries, 'runtime-source.tar.xz')
    protocols = json.loads(input_bytes(old, entries, 'RESOLVED-PROTOCOLS.json'))
    requested = sorted({73520010} | {s for v in (5, 0) for first in range(0, 128, 2) for s in config(first, v)['seeds']})
    require(not any(5000 <= s <= 5199 for s in requested), 'PROTECTED_SEED_RANGE')
    save(out / 'SEED-METADATA.json', one.seed_check(repo, HERE, requested))
    reference = work / 'reference'
    reference.mkdir()
    expected = {method + '/' + rel: r for method, files in sources.items() for rel, r in files.items()}
    with tarfile.open(old / 'runtime-source.tar.xz', 'r:xz') as tf:
        members = tf.getmembers()
        require(len(members) == len(expected) and {m.name for m in members} == set(expected), 'FULL_ARCHIVE_COVERAGE')
        for m in members:
            rel = Path(m.name)
            require(m.isfile() and not rel.is_absolute() and '..' not in rel.parts, 'ARCHIVE_PATH')
            b = tf.extractfile(m).read(); r = expected[m.name]
            require(len(b) == r['bytes'] and sha(b) == r['sha256'], 'ARCHIVE_MEMBER:' + m.name)
            if rel.parts[0] == 'aware':
                target = reference / Path(*rel.parts[1:]); target.parent.mkdir(parents=True, exist_ok=True); target.write_bytes(b)
    require(sha((reference / 'content/full-content.json').read_bytes()) == p['candidate_content_sha256'], 'CONTENT')
    require(sha((reference / 'domain/rules/combat.gd').read_bytes()) == p['candidate_combat_sha256'], 'COMBAT')
    cards = load(reference / 'content/full-content.json')['cards']
    for up in (False, True):
        effects = cards['bloodRite']['up']['effects'] if up else cards['bloodRite']['effects']
        base = p['source_erratum']['upgraded_effects' if up else 'base_effects']
        require(effects[:-1] == base and effects[-1] == {'kind': 'status', 'who': 'self', 'id': 'bloodfire', 'n': 1}, 'HP_ENERGY_NOT_DRAW')
    observer = (reference / 'observed_game.gd').read_bytes()
    require(blob(observer) == OBSERVER_BLOB, 'ORIGINAL_OBSERVER')
    planner = (reference / 'public_rollout.gd').read_bytes()
    require(blob(planner) == '5fa5655a93b06d05ad88d8b7a8bff2f93fac44e0', 'PLANNER_CLONE_FLAG_PROPAGATION')
    projects, resolved = {}, {}
    for world in WORLDS:
        project = work / world; shutil.copytree(reference, project)
        (project / 'observed_game.gd').write_bytes(observer_source(observer, world))
        changed = [str(f.relative_to(reference)) for f in reference.rglob('*') if f.is_file()
                   and f.read_bytes() != (project / f.relative_to(reference)).read_bytes()]
        require(changed == ['observed_game.gd'], 'UNRELATED_RUNTIME_CHANGE')
        q = copy.deepcopy(protocols['aware'])
        q.update(policy_root=73409000, policies=128, policies_per_cell=2, method='planner', causal_world=world)
        q['runtime']['observer_sha256'] = sha((project / 'observed_game.gd').read_bytes())
        projects[world], resolved[world] = project, q
    mutant = work / 'unsafe-mutant'; shutil.copytree(reference, mutant)
    (mutant / 'observed_game.gd').write_bytes(observer_source(observer, '10', unsafe=True))
    for project in [reference, mutant, *projects.values()]:
        shutil.copyfile(HERE / 'plumbing_gate.gd', project / 'plumbing_gate.gd')
    manifests = {name: {str(f.relative_to(project)): {'bytes': f.stat().st_size, 'sha256': sha(f.read_bytes())}
                        for f in sorted(project.rglob('*')) if f.is_file()}
                 for name, project in [('reference', reference), ('unsafe-mutant', mutant), *projects.items()]}
    save(out / 'SOURCE-MANIFEST.json', manifests)
    save(out / 'RESOLVED-PROTOCOLS.json', resolved)
    with tarfile.open(out / 'runtime-source.tar.xz', 'w:xz') as tf:
        for name, records in manifests.items():
            for rel in records: tf.add(work / name / rel, arcname=name + '/' + rel, recursive=False)
    return projects, resolved


def gate(work, engine, out, base, reader):
    q = out / 'qualification'; q.mkdir()
    for name in ('reference', *WORLDS, 'unsafe-mutant'):
        project = work / name
        base.command([str(engine), '--headless', '--path', str(project), '--import'], q, name + '-import')
        base.command(['env', 'GODOT=' + str(engine), 'bash', 'tools/check_scripts.sh', 'observed_game.gd', 'plumbing_gate.gd'], q, name + '-parse', cwd=project)
        world = '11' if name == 'reference' else '10' if name == 'unsafe-mutant' else name
        base.command([str(engine), '--headless', '--path', str(project), '-s', 'res://plumbing_gate.gd', '--',
                      str(q / (name + '.jsonl')), str(q / (name + '.traces.jsonl')), world], q, name)
    require((q / 'reference.jsonl').read_bytes() == (q / '11.jsonl').read_bytes(), 'DEFAULT_ON_FULL_PREFIX_PARITY')
    require((q / 'reference.traces.jsonl').read_bytes() == (q / '11.traces.jsonl').read_bytes(), 'DEFAULT_ON_FULL_TRACE_PARITY')
    result = qualify.check(q, reader)
    killed = 0
    for r in reader.stream(q / 'unsafe-mutant.traces.jsonl'):
        if r['card'] == 'leechBlade':
            try: reader.clones(r)
            except ValueError as exc:
                require('FACTUAL_PARITY' in str(exc), 'UNRELATED_MUTANT_FAILURE')
                killed += 1
    require(killed > 0, 'UNSAFE_AB_CLONE_MUTANT_NOT_KILLED')
    result['unsafe_clone_mutant_failures'] = killed
    result['default_on_complete_trace_equal'] = True
    save(q / 'RESULTS.json', result)
    return result


def run(repo, engine, out, work, publish=False):
    repo, engine, out, work = map(lambda x: Path(x).resolve(), (repo, engine, out, work))
    require(not out.exists() and not work.exists(), 'OUTPUT_EXISTS_NO_RERUN')
    out.mkdir(parents=True); work.mkdir(parents=True)
    base = None; head = None
    t = {'status': 'INCONCLUSIVE', 'stages': {}, 'packages_admitted': 0, 'p9_certified': False}
    try:
        one, value, base, reader, bench, bridge, comparison = dependencies(repo)
        head = base.git(repo, 'rev-parse', 'HEAD'); t['source_head'] = head
        freeze = load(HERE / 'SOURCE-FREEZE.json')
        for name, expected in freeze['source_sha256'].items(): require(sha((HERE / name).read_bytes()) == expected, 'FROZEN_SOURCE:' + name)
        require(sha(engine.read_bytes()) == ENGINE, 'PINNED_ENGINE')
        projects, ps = setup(repo, work, out, one)
        if publish: head = base.publish(repo, out, head, 'research(p9): bind four unchanged-policy causal worlds before observations')
        t['qualification'] = gate(work, engine, out, base, reader)
        if publish: head = base.publish(repo, out, head, 'research(p9): preserve source utility and four-world observer qualification')
        for vow in (5, 0):
            stage = out / f'v{vow}'; stage.mkdir()
            for world in WORLDS: (stage / world).mkdir()
            specs = [(world, config(first, vow)) for first in range(0, 128, 2) for world in WORLDS]
            costs = {w: 0. for w in WORLDS}
            for offset in range(0, len(specs), 8):
                tasks = specs[offset:offset + 8]
                with ThreadPoolExecutor(max_workers=2) as pool:
                    receipts = list(pool.map(lambda x: value.cell(x[1], projects[x[0]], engine, stage / x[0], ps[x[0]], base, reader), tasks))
                for (world, cfg), rec in zip(tasks, receipts):
                    if rec['status'] == 'COMPLETE': costs[world] += rec['cpu']['user'] + rec['cpu']['system']
                save(stage / 'COST-PROGRESS.json', costs)
                if publish: head = base.publish(repo, out, head, f'research(p9): preserve causal v{vow} matched group {offset // 8 + 1}')
                require(all(r['status'] == 'COMPLETE' for r in receipts), 'INCOMPLETE_ASSIGNED_CELL')
                if not resource_ok(costs):
                    t.update(status='CAUSAL_VALUE_RESOURCE_FAIL', last_vow=vow, v0_skipped=vow == 5, partial_costs=costs)
                    break
            else:
                r = read_stage(stage, ps, vow, reader, value.read_value.validate_extra)
                save(stage / 'RESULTS.json', r)
                t['stages'][str(vow)] = {k: v for k, v in r.items() if k != 'secondary'}
                if publish: head = base.publish(repo, out, head, f'research(p9): preserve fixed four-world v{vow} causal decision')
                if not r['pass_all']:
                    t.update(status='BLOODFIRE_ADAPTIVE_VALUE_NOT_ESTABLISHED', last_vow=vow, v0_skipped=vow == 5)
                    break
                continue
            break
        else: t['status'] = 'BLOODFIRE_ADAPTIVE_VALUE_SUPPORTED_NOT_CERTIFICATE'
    except Exception as exc:
        t['failure'] = repr(exc)
    finally:
        save(out / 'TERMINAL.json', t)
        save(out / 'FILES.json', [{'path': str(f.relative_to(out)), 'bytes': f.stat().st_size, 'sha256': sha(f.read_bytes())}
                                 for f in sorted(out.rglob('*')) if f.is_file() and f != out / 'FILES.json'])
        if publish and base is not None and head is not None:
            head = base.publish(repo, out, head, 'research(p9): preserve actual adaptive causal terminal and all available evidence')
        if head and os.environ.get('GITHUB_ENV'):
            with open(os.environ['GITHUB_ENV'], 'a') as f: f.write('PUBLISHED_HEAD=' + head + '\n')
        print(json.dumps(t, indent=2))
    return 3 if t['status'] == 'INCONCLUSIVE' else 0


def verify(repo, original, cold, receipt):
    repo, original, cold, receipt = map(Path, (repo, original, cold, receipt))
    require(not receipt.exists(), 'RECEIPT_EXISTS')
    _, value, _, reader, _, _, _ = dependencies(repo)
    raw = (original / 'FILES.json').read_bytes(); require(raw == (cold / 'FILES.json').read_bytes(), 'MANIFEST_EQUALITY')
    entries = json.loads(raw); require(len({r['path'] for r in entries}) == len(entries), 'DUPLICATE_MANIFEST')
    for r in entries:
        rel = Path(r['path']); require(not rel.is_absolute() and '..' not in rel.parts, 'READBACK_PATH')
        b = (cold / rel).read_bytes()
        require(b == (original / rel).read_bytes() and len(b) == r['bytes'] and sha(b) == r['sha256'], 'REMOTE_BYTES:' + str(rel))
    t = load(cold / 'TERMINAL.json')
    if 'qualification' in t:
        actual = qualify.check(cold / 'qualification', reader)
        for k, v in actual.items(): require(v == t['qualification'][k], 'QUALIFICATION_REPRODUCTION')
    if t['stages']:
        ps = load(cold / 'RESOLVED-PROTOCOLS.json')
        for vow, expected in t['stages'].items():
            r = read_stage(cold / f'v{vow}', ps, int(vow), reader, value.read_value.validate_extra)
            require(r == load(cold / f'v{vow}/RESULTS.json'), 'FULL_READOUT_REPRODUCTION')
            require({k: v for k, v in r.items() if k != 'secondary'} == expected, 'TERMINAL_STAGE')
            if vow == '0': require(t['stages']['5']['pass_all'] is True, 'V0_GATE')
    save(receipt, {'kind': 'COMPLETE_ADAPTIVE_CAUSAL_COLD_READBACK', 'files': len(entries) + 1,
                  'all_bytes_equal': True, 'reproduced_stages': list(t['stages']), 'scientific_status': t['status'],
                  'new_native_runs': 0, 'packages_admitted': 0, 'p9_certified': False})


if __name__ == '__main__':
    if sys.argv[1] == 'run': raise SystemExit(run(*sys.argv[2:6], publish='--publish' in sys.argv))
    elif sys.argv[1] == 'verify': verify(*sys.argv[2:])
    else: raise SystemExit('run REPO ENGINE OUTPUT WORK [--publish] | verify REPO ORIGINAL COLD RECEIPT')
