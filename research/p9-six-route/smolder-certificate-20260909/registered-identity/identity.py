"""Exact registered-template comparison. Archived Python is parsed, never run.

This proves source-semantic reuse under an identical command/query/economy
frame. It does not carry empirical outcomes, equate renderers, or qualify an
engine. A positive historical edge stays positive inside its failed package.
"""
from __future__ import annotations
import argparse
import ast
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import tarfile

OLD = '0f005282e8881d970da284f4868caedf60cc8142'
CURRENT = '2ed6cdb0302ba3aab5845a18d862841165e8aaf7'
EVIDENCE = 'f305b95d9e1d173e5d8150289afab9688c0ea7f0'
DOCS = {
 'campaign.py': ('research/issue-524/tools/campaign.py', '385540e03235d436d5d138ad2dbb3c9aaa5e03a5'),
 'finding.json': ('research/issue-524/artifacts/scope-insufficiency-finding-v1.json', 'dc09ab268e95d25879bf4cf087f7627bd1fb31a0'),
 'gate.json': ('research/issue-524/artifacts/stage-b-mechanism-package-gate-v1.json', '5817598436cabc19e72c0d5466d8cbea9a31ef54'),
 'preregistration.json': ('research/issue-524/protocols/preregistration-v1.json', 'ccaf8bbc54231ab8316a7f437a9ea76990ce7f4b'),
}
SCOPES = ('domain/game.gd', 'domain/game.gd.uid', 'domain/events', 'domain/rng',
          'domain/rules', 'domain/state', 'content', 'project.godot',
          'tools/balance_sim.gd', 'tools/balance_pilot.gd', 'tools/balance_policy.gd',
          'tools/balance_catalogue.gd', 'tools/balance_metrics.gd', 'tools/vow_incentives.gd')
CANDIDATES = (
 ('smolder', 'ash-poison-catalyst', 'venomStrike', 'catalyst', 'ashwarden'),
 ('fervor', 'strength-multihit', 'empower', 'flurry', 'duskblade'),
)
CONTENT_SHA = 'a0d608a5142d2e3aab799cdf33d3163922b402c2aaf2a895e46e096399b56cf1'


def require(ok, why):
    if not ok:
        raise ValueError(why)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def blob(data):
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()


def encode(value):
    return (json.dumps(value, sort_keys=True, indent=2) + '\n').encode()


def git(repo, *args):
    return subprocess.check_output(['git', '-C', str(repo), *args], timeout=60)


def tree_map(repo, ref):
    result = {}
    for entry in git(repo, 'ls-tree', '-rz', ref, '--', *SCOPES).split(b'\0'):
        if not entry:
            continue
        meta, path = entry.decode().split('\t')
        mode, kind, digest = meta.split()
        require(kind == 'blob' and mode in ('100644', '100755'), 'NON_REGULAR_SOURCE')
        require(path not in result, 'DUPLICATE_SOURCE_PATH')
        result[path] = {'mode': mode, 'git_blob': digest}
    require(bool(result), 'EMPTY_SOURCE_MAP')
    return result


def same_frame(old, new):
    require(old and new, 'EMPTY_SOURCE_MAP')
    require(set(old) == set(new), 'SOURCE_INVENTORY_CHANGED')
    changed = sorted(p for p in old if old[p] != new[p])
    require(not changed, 'SEMANTIC_SOURCE_CHANGED:' + ','.join(changed))
    return sorted(old)


def packages_from_source(data):
    module = ast.parse(data.decode())
    nodes = [n for n in module.body if isinstance(n, ast.Assign)
             and any(isinstance(t, ast.Name) and t.id == 'PACKAGES' for t in n.targets)]
    require(len(nodes) == 1, 'PACKAGE_REGISTRATION_COUNT')
    packages = ast.literal_eval(nodes[0].value)
    require(isinstance(packages, (tuple, list)), 'PACKAGE_REGISTRATION_TYPE')
    result = {}
    for p in packages:
        require(isinstance(p, dict) and p['id'] not in result, 'DUPLICATE_PACKAGE')
        result[p['id']] = p
    return result


def match_edge(registry, family, producer, consumer, aspect):
    require(family in registry, 'UNREGISTERED_FAMILY')
    p = registry[family]
    require(aspect in p['aspects'], 'UNREGISTERED_ASPECT')
    matches = [e for e in p['edges'] if e['producer'] == producer and e['consumer'] == consumer]
    require(len(matches) == 1, 'NOT_EXACT_REGISTERED_ROLE_EDGE')
    require(producer in p['nodes'] and consumer in p['nodes'], 'ROLE_OUTSIDE_PACKAGE')
    return p, matches[0]


def dependency_screen(sources, excluded_classes):
    """Conservative fail-closed screen; not a general GDScript call-graph solver."""
    references = set()
    for name, data in sources.items():
        if not name.endswith('.gd'):
            continue
        text = data.decode()
        for klass in excluded_classes:
            require(not re.search(r'\b' + re.escape(klass) + r'\b', text), 'EXCLUDED_CLASS_REFERENCE:' + name)
        require('res://domain/map_layout/' not in text, 'EXCLUDED_PATH_REFERENCE:' + name)
        require(not re.search(r'\b(?:ResourceLoader|ClassDB)\b', text), 'DYNAMIC_EXTERNAL_LOOKUP:' + name)
        for target in re.findall(r'\b(?:preload|load)\(\s*["\'](res://[^"\']+)["\']\s*\)', text):
            target = target.removeprefix('res://')
            require(target in sources, 'UNBOUND_STATIC_LOAD:' + target)
            references.add((name, target))
    return sorted(references)


def collect(repo, output):
    require(not output.exists(), 'OUTPUT_EXISTS')
    output.mkdir(parents=True)
    old, current = tree_map(repo, OLD), tree_map(repo, CURRENT)
    # Retain both complete maps even if the identity claim fails.
    (output / 'OLD-TREE.json').write_bytes(encode(old))
    (output / 'CURRENT-TREE.json').write_bytes(encode(current))
    same_frame(old, current)
    for leaf, (path, expected) in DOCS.items():
        data = git(repo, 'show', EVIDENCE + ':' + path)
        require(blob(data) == expected, 'HISTORICAL_DOCUMENT:' + leaf)
        (output / leaf).write_bytes(data)
    classes = set()
    for entry in git(repo, 'ls-tree', '-rz', CURRENT, '--', 'domain/map_layout').split(b'\0'):
        if not entry:
            continue
        _, path = entry.decode().split('\t')
        if path.endswith('.gd'):
            classes.update(re.findall(r'^class_name\s+(\w+)', git(repo, 'show', CURRENT + ':' + path).decode(), re.M))
    (output / 'EXCLUDED-CLASSES.json').write_bytes(encode(sorted(classes)))
    with tarfile.open(output / 'source.tar.xz', 'w:xz') as tf:
        for path in sorted(current):
            data = git(repo, 'show', CURRENT + ':' + path)
            require(blob(data) == current[path]['git_blob'], 'SOURCE_BYTE_IDENTITY:' + path)
            info = tarfile.TarInfo(path)
            info.size = len(data); info.mode = int(current[path]['mode'], 8) & 0o777
            info.mtime = 0
            tf.addfile(info, io.BytesIO(data))
    (output / 'DOMAIN-DIFF.patch').write_bytes(git(repo, 'diff', '--no-ext-diff', '--no-renames', OLD, CURRENT, '--', 'domain'))
    manifest = {p.name: {'sha256': sha(p.read_bytes()), 'bytes': p.stat().st_size}
                for p in sorted(output.iterdir()) if p.is_file()}
    (output / 'MANIFEST.json').write_bytes(encode(manifest))


def analyse(inputs):
    manifest = json.loads((inputs / 'MANIFEST.json').read_bytes())
    for name, row in manifest.items():
        require(Path(name).name == name, 'UNSAFE_INPUT_PATH')
        data = (inputs / name).read_bytes()
        require(len(data) == row['bytes'] and sha(data) == row['sha256'], 'INPUT_BYTES:' + name)
    for name, (_, expected) in DOCS.items():
        require(blob((inputs / name).read_bytes()) == expected, 'HISTORICAL_DOCUMENT:' + name)
    old = json.loads((inputs / 'OLD-TREE.json').read_bytes())
    current = json.loads((inputs / 'CURRENT-TREE.json').read_bytes())
    paths = same_frame(old, current)
    sources = {}
    with tarfile.open(inputs / 'source.tar.xz', 'r:xz') as tf:
        for member in tf.getmembers():
            require(member.isfile() and member.name in current and member.name not in sources, 'SOURCE_ARCHIVE_ENTRY')
            data = tf.extractfile(member).read()
            require(blob(data) == current[member.name]['git_blob'], 'SOURCE_BLOB:' + member.name)
            sources[member.name] = data
    require(set(sources) == set(paths), 'SOURCE_ARCHIVE_COVERAGE')
    require(sha(sources['content/full-content.json']) == CONTENT_SHA, 'NATIVE_CONTENT_IDENTITY')
    deps = dependency_screen(sources, json.loads((inputs / 'EXCLUDED-CLASSES.json').read_bytes()))
    registry = packages_from_source((inputs / 'campaign.py').read_bytes())
    finding = json.loads((inputs / 'finding.json').read_bytes())
    protocol = json.loads((inputs / 'preregistration.json').read_bytes())
    gate = json.loads((inputs / 'gate.json').read_bytes())
    require(protocol['architecture']['sourceCommit'] == OLD == finding['sourceCommit'], 'OLD_SOURCE_BINDING')
    content = json.loads(sources['content/full-content.json'])
    rows = []
    promoted = set(finding['positiveLocalEvidence']['heldOutPromotedEdgeAspects'])
    for name, family, a, b, aspect in CANDIDATES:
        package, edge = match_edge(registry, family, a, b, aspect)
        key = family + '|' + edge['id'] + '|' + aspect
        require(key in gate['controlled']['checks'], 'MISSING_EXECUTED_EDGE')
        check = finding['packageChecks'][family][aspect]
        require(check['admitted'] is False, 'HISTORICAL_ADMISSION_CHANGED')
        rows.append({'candidate': name, 'family': family, 'aspect': aspect,
                     'registered_edge': edge, 'registered_package': package,
                     'native_cards': {k: content['cards'][k] for k in (a, b)},
                     'source_relation': 'IDENTICAL_REGISTERED_ROLE_SUBSYSTEM_IN_IDENTICAL_NATIVE_SEMANTIC_FRAME',
                     'historical_controlled_edge': gate['controlled']['checks'][key],
                     'historical_heldout_edge_promoted': key in promoted,
                     'historical_package_checks': check,
                     'novelty_disposition': 'NOT_A_NEW_DISTINCT_PACKAGE_BY_RENAMING_OR_ROLE_RESTRICTION',
                     'new_confirmation_authorised': False})
    return {'kind': 'SOURCE_BOUND_EXISTENTIAL_ALIAS_WITNESS_NOT_UNIVERSAL_QUOTIENT',
            'old_product_source': OLD, 'current_product_source': CURRENT,
            'historical_evidence': EVIDENCE, 'equal_source_files': len(paths),
            'semantic_source_manifest_sha256': sha(encode(current)),
            'static_external_references': deps, 'rows': rows,
            'proof': [
              'The original literal PACKAGES registry explicitly contains both exact producer-consumer edges. No role is inferred from a label or substituted from unrelated background.',
              'All bound source files, content bytes and their insertion order match. The shared frame includes commands, public combat previews, reward/map topology rules, state/reset/save data, RNG and the shipped policy tool dependencies.',
              'For the same full initial native state, same external inputs, same runtime semantics and same commands, the identity relation on full state is preserved step by step, including events and returns. Induction covers arbitrary finite traces, not selected examples.',
              'Restricting the old registered package to the already-registered selected edge introduces no new law. A single exhibited member/subsystem is sufficient to refute novelty; an exhaustive library is required to prove absence, not to exhibit membership.',
              'Renderer geometry and application wrappers are not compared. Their excluded differences neither prove whole-product equivalence nor create a new producer-mediator-consumer law. No historical empirical outcome is transported to a changed workload.'],
            'scope': ['Source-level canonical membership only; not an executed source/runtime oracle or Node O PASS.',
                      'Old package failures retain their exact designs and thresholds; they do not prove every future policy or modified mechanism fails.',
                      'Smolder had a positive held-out edge. Rejecting its new-package label does not rewrite that positive evidence.',
                      'The later Mistbound extension and its preview mismatch are a different comparator, not a reason to ignore the original native #524 registration.',
                      'A valid new law requires its own bound claim. No new candidate, E0/E1 campaign or population confirmation is opened here.'],
            'new_native_runs': 0, 'new_independent_samples': 0,
            'packages_admitted': 0, 'p9_certified': False,
            'review_kind': 'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT'}


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('mode', choices=('collect', 'analyse'))
    p.add_argument('input', type=Path)
    p.add_argument('output', type=Path)
    a = p.parse_args()
    if a.mode == 'collect':
        collect(a.input, a.output)
    else:
        require(not a.output.exists(), 'OUTPUT_EXISTS')
        a.output.write_bytes(encode(analyse(a.input)))
