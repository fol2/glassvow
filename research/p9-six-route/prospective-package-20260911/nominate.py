"""One predeclared selection from EXPOSED development summaries, not admission.
No engine, fitting, optimization, seed generation, network, or historical rewrite.
"""
from __future__ import annotations
import hashlib
import json
from pathlib import Path
import sys

INPUT_HEAD = '1cea2c1a9f486cab6d04b69ed96b0a22e1644322'
INPUT_ROOT = 'research/p9-six-route/ash-inheritance-20260909/joint-controller-v1/execution-1'
MANIFEST_BLOB = 'cc2081e21e7c603ef0624e399aeaab978a63f9d6'
CONTENT = '4107c7c0bbed5d9acf8c2bdf97023552426920242ea958c8ebdec793b712afd9'
COMBAT = '3ccb89f69f50e41d5a46eadd8f48c0a907fd0e382cd492b2c34dd5f93e091ad0'
SEEDS = tuple(range(73414100, 73414104))
METHODS = ('stock', 'aware')
PACKAGES = ('hand', 'bloodfire')


def need(condition, message):
    if not condition:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def blob(data):
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()


def exact_int(value, label):
    need(type(value) is int, label + ':INTEGER')
    return value


def rank_rows(rows, package):
    """Outcome-dependent development nomination is explicit; no held-out claims.
    Existing necessary flags are intentionally NOT relabelled as causal effects.
    """
    need(package in PACKAGES, 'PACKAGE')
    seen, groups = set(), {index: [] for index in range(128)}
    for row in rows:
        index, seed = exact_int(row['index'], 'INDEX'), exact_int(row['seed'], 'SEED')
        need(index in groups and seed in SEEDS, 'ASSIGNMENT')
        key = (index, seed)
        need(key not in seen, 'DUPLICATE_ASSIGNMENT')
        seen.add(key)
        need(row['row_key'] == f'5:{index}:{seed}', 'ROW_KEY')
        need(row['outcome'] in ('win', 'loss'), 'OUTCOME')
        for flag in PACKAGES:
            need(type(row[flag]) is bool, 'TYPED_ACTIVATION')
        groups[index].append(row)
    need(seen == {(i, s) for i in groups for s in SEEDS}, 'COMPLETE_512_ASSIGNMENTS')
    peer = 'bloodfire' if package == 'hand' else 'hand'
    scores = []
    for index, subset in groups.items():
        wins = sum(r['outcome'] == 'win' for r in subset)
        active = sum(r[package] for r in subset)
        joint = sum(r[package] and r['outcome'] == 'win' for r in subset)
        exclusive = sum(r[package] and not r[peer] for r in subset)
        scores.append(dict(index=index, necessary_active_runs=active,
            exposed_wins=wins, exposed_win_and_necessary_activation=joint,
            necessary_exclusive_runs=exclusive))
    # One ordering fixed before execution. No search over ranking rules.
    eligible = [r for r in scores if r['necessary_active_runs'] > 0]
    eligible.sort(key=lambda r: (-r['exposed_win_and_necessary_activation'],
                                -r['exposed_wins'], -r['necessary_active_runs'],
                                -r['necessary_exclusive_runs'], r['index']))
    need(len(eligible) >= 2, 'INSUFFICIENT_DEVELOPMENT_NOMINEES')
    return eligible[:2], scores


def run(repo, output):
    repo, output = Path(repo), Path(output)
    need(not output.exists(), 'OUTPUT_ALREADY_EXISTS')
    root = repo / INPUT_ROOT
    manifest_bytes = (root / 'FILES.json').read_bytes()
    need(blob(manifest_bytes) == MANIFEST_BLOB, 'IMMUTABLE_MANIFEST')
    manifest = json.loads(manifest_bytes)
    entries = {r['path']: r for r in manifest}
    need(len(entries) == len(manifest), 'DUPLICATE_MANIFEST_PATH')
    inputs = []
    def bound(name):
        data = (root / name).read_bytes()
        wanted = entries[name]
        need(len(data) == wanted['bytes'] and digest(data) == wanted['sha256'], 'INPUT_BYTES:' + name)
        inputs.append(dict(path=INPUT_ROOT + '/' + name, bytes=len(data), sha256=digest(data), git_blob=blob(data)))
        return json.loads(data)
    source = bound('SOURCE-MANIFEST.json')
    for method in METHODS:
        need(source[method]['content/full-content.json']['sha256'] == CONTENT, 'SAME_CONTENT')
        need(source[method]['domain/rules/combat.gd']['sha256'] == COMBAT, 'SAME_NATIVE_LAW')
    nominees, tables = [], {}
    for method in METHODS:
        captured = bound(f'v5/{method}-support.json')
        need(captured['vow'] == 5 and type(captured['vow']) is int, 'VOW')
        need(captured['rows'] == 512 and captured['policy_configurations'] == 128, 'PANEL_SCOPE')
        for package in PACKAGES:
            chosen, scores = rank_rows(captured['row_results'], package)
            tables[method + ':' + package] = scores
            for item in chosen:
                nominees.append(dict(package=package, method=method, policy_root=73409000,
                    policy_index=item['index'], discovery_summary=item,
                    nomination_id=f"{package}:{method}:{item['index']}"))
    need(len(nominees) == 8, 'EXACT_EIGHT_NOMINATIONS')
    unique = sorted({(r['method'], r['policy_index']) for r in nominees})
    result = dict(status='EXPOSED_DEVELOPMENT_NOMINATIONS_FIXED_NOT_CERTIFICATES',
        input_head=INPUT_HEAD, content_sha256=CONTENT, combat_sha256=COMBAT,
        ranking=['win_and_necessary_activation descending', 'wins descending',
                 'necessary_active_runs descending', 'necessary_exclusive_runs descending',
                 'index ascending'],
        nominations=nominees, unique_enacted_policies=[dict(method=m,index=i) for m,i in unique],
        max_factual_confirmation_runs=2 * 256 * len(unique),
        maximum_same_product_random_build_runs=2 * 256,
        all_development_rows_retained_in_score_tables=True,
        new_native_runs=0, new_independent_samples=0, packages_admitted=0, p9_certified=False,
        scientific_status_of_old_terminals='UNCHANGED',
        limits=['Selection only. All old aggregate-win, support, controller and content failures keep their exact scope.',
                'Necessary activation in development is not causal contribution, descriptor validity or package membership.',
                'No nomination is counted as competent or distinct until the separately bound prospective contract passes.',
                'No new policy parameters, acquisition rule or planner are fitted.',
                'Fresh assignments, complete source/raw preservation and the complete prospective reader must be qualified before any observations.'])
    output.mkdir(parents=True)
    for name, value in [('NOMINATIONS.json',result),('DEVELOPMENT-SCORES.json',tables),('INPUTS.json',inputs)]:
        (output/name).write_text(json.dumps(value,indent=2)+'\n')
    files = [dict(path=p.name,bytes=p.stat().st_size,sha256=digest(p.read_bytes())) for p in sorted(output.iterdir())]
    (output/'FILES.json').write_text(json.dumps(files,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k not in ('nominations','limits')},indent=2))


if __name__ == '__main__':
    if len(sys.argv) != 3:
        raise SystemExit('nominate.py REPOSITORY FRESH_OUTPUT_DIRECTORY')
    run(*sys.argv[1:])
