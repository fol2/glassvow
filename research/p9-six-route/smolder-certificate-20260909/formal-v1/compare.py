"""Source-bound Smolder composition proof and its explicit scope countermodel.

This is a static research proof, not Godot execution or a package certificate.
The finite residue abstraction refutes equivalence only in its stated algebra.
A matching abstract signature never proves full behavioural equivalence.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import itertools
import json
from pathlib import Path
import re
import tarfile
import urllib.request

BASE = Path('research/p9-six-route/smolder-certificate-20260909')
ARCHIVE_HEAD = 'c802be36510273481b6d0f865b92fac43abf6aff'
ARCHIVE_PATH = 'research/issue-421/raw/post-directive-harness-v2.tar.gz'
ARCHIVE_BLOB = '0e963a6dfadb87912f9b1074b78d8629bbad2a47'
INPUTS = {
    'content/full-content.json': 'a0d608a5142d2e3aab799cdf33d3163922b402c2aaf2a895e46e096399b56cf1',
    'domain/rules/combat.gd': '3adb0e063a536bf249d3b5d9524427facf1398304206da59d97594d3fff246e8',
    str(BASE / 'source-1/SOURCE-INDEX.json'): '93d94268da77ab53385046f83ddc461f3d0501dfa50b018145adf5383457743f',
    str(BASE / 'source-1/HISTORICAL-FUNCTIONS.json'): '7158a8e070f583f5c5fd959183364f75c17009139adc27324bcfa504034177b0',
    str(BASE / 'source-1/NATIVE-FUNCTIONS.json'): '3998de0cb74fca7ad702c2d95799b37562589403f5abf15552393d7d1257c145',
}
DOCS = {
    'research/issue-421/protocols/post-v38-package-order-heldout-v1.json': '96e899bf6fbaa2dc6ab926621aa72340818d8dda',
    'research/issue-421/protocols/post-v38-hand-size-inventory-v1.json': '9526a5f3280b2e7ac02ba96f68620c00d30ae1cf',
    'research/issue-421/summaries/progress-post-directive-hand-size-ash-admission-v1.md': '8a24a986671427bd1a97cf7a847c001e14d6214d',
}
MODULUS = 8  # Divides 2**64, so integer wraparound cannot break this invariant.


def require(condition, reason):
    if not condition:
        raise ValueError(reason)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def blob(data):
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()


def dump(path, value):
    path.write_text(json.dumps(value, sort_keys=True, indent=2) + '\n')


def download(path):
    url = f'https://raw.githubusercontent.com/fol2/glassvow/{ARCHIVE_HEAD}/{path}'
    with urllib.request.urlopen(url, timeout=60) as response:
        data = response.read(4 * 1024 * 1024 + 1)
    require(len(data) <= 4 * 1024 * 1024, 'DOWNLOAD_SIZE')
    return data


def archive_content(data):
    require(blob(data) == ARCHIVE_BLOB, 'ARCHIVE_IDENTITY')
    with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as tf:
        members = tf.getmembers()
        names = [m.name for m in members]
        require(len(names) == len(set(names)), 'DUPLICATE_ARCHIVE_PATH')
        for m in members:
            require(not m.name.startswith('/') and '..' not in Path(m.name).parts,
                    'ARCHIVE_PATH')
            require(m.isdir() or m.isfile(), 'ARCHIVE_MEMBER_TYPE')
        member = tf.getmember('source/content/full-content.json')
        require(member.size < 2 * 1024 * 1024, 'ARCHIVE_MEMBER_SIZE')
        content = tf.extractfile(member).read()
    require(sha(content) == 'e475482c76a405814dba4638860bb799f610a220fcde5d931c78d1a447e18f48',
            'HISTORICAL_CONTENT')
    return json.loads(content)


def variants(card):
    yield 'base', card
    up = dict(card)
    up.update(card.get('up', {}))
    yield 'up', up


def integer(value):
    require(type(value) is int, 'NON_INTEGER_AUTHORED_PARAMETER')
    return value


def source_atoms(card):
    """Overapproximate role-effect decompositions, never split a target loop.

    These are effect categories, not a complete game-state projection.
    Full card definitions are retained in the output, including costs/lifecycle.
    """
    atoms = set()
    for fx in card['effects']:
        kind = fx['kind']
        if kind == 'status' and fx['id'] == 'poison':
            n = integer(fx['n'])
            require(n >= 0, 'UNSUPPORTED_NEGATIVE_SOURCE')
            if n:
                who = fx.get('who')
                require(who in ('allEnemies', 'target'), 'UNKNOWN_POISON_TARGETING')
                atoms.add('add_all' if who == 'allEnemies' else 'add_target')
        elif kind == 'special' and fx['id'] == 'catalyst':
            integer(fx['n'])
            integer(fx.get('mistboundBonus', 0))
            atoms.add('integer_scale_target')
        elif kind == 'status' and fx['id'] in ('mistbound', 'bloodfire'):
            integer(fx['n'])
            atoms.add('visible_marker')
        elif kind in ('dmg', 'draw', 'energy', 'loseHp'):
            integer(fx['n'])
            atoms.add('other_observable_' + kind)
        elif kind == 'special' and fx['id'] in ('leech', 'phantom'):
            atoms.add('other_observable_' + fx['id'])
        else:
            raise ValueError('UNMODELLED_ROLE_EFFECT:' + json.dumps(fx, sort_keys=True))
    return sorted(atoms)


def kernel_successors(state):
    """Every integer multiplier, linear transfer, deletion and neutral step.

    Repetition/guarded choice/interleaving of these generators is unbounded.
    These deliberately overapproximate actual Catalyst coefficients and costs.
    """
    a, b = state
    result = {state, (0, b), (a, 0), (0, (a + b) % MODULUS),
              ((a + b) % MODULUS, 0)}
    for k in range(MODULUS):
        result.add((a * k % MODULUS, b))
        result.add((a, b * k % MODULUS))
    return result


def fixed_point(initial, generators=kernel_successors):
    reached, pending = {initial}, [initial]
    while pending:
        for successor in generators(pending.pop()):
            if successor not in reached:
                reached.add(successor)
                pending.append(successor)
    return sorted(reached)


def source_law_checks(native, historical, cards):
    ns = native['_apply_special']
    hs = historical['source/domain/rules/combat.gd::_apply_special']['body']
    def arm(body, label):
        match = re.search(r'^\t\t"' + re.escape(label) + r'":\n(.*?)(?=^\t\t"|\Z)',
                          body, re.M | re.S)
        require(match is not None, 'MISSING_SOURCE_ARM:' + label)
        return match.group(1)
    ncat, hcat = arm(ns, 'catalyst'), arm(hs, 'catalyst')
    require('poison * (_ji(fx["n"]) - 1)' in ncat, 'NATIVE_CATALYST_LAW')
    require('poison * (multiplier - 1)' in hcat and 'mistboundBonus' in hcat
            and '"mistbound", -1' in hcat, 'HISTORICAL_CATALYST_LAW')
    checks = {'native_catalyst': sha(ncat.encode()), 'historical_catalyst': sha(hcat.encode())}
    for name in ('play_card', 'end_turn', '_jump_smolder', '_on_enemy_death'):
        old = historical['source/domain/rules/combat.gd::' + name]['body']
        require(native[name] == old, 'CHANGED_CHECKED_RUNTIME_BODY:' + name)
        checks[name] = sha(old.encode())
    require(cards['venomStrike']['target'] == 'enemy', 'NATIVE_SOURCE_TARGET')
    require(cards['venomStrike']['type'] == 'attack', 'NATIVE_SOURCE_TYPE')
    require(cards['catalyst']['exhaust'] is True, 'NATIVE_CONSUMER_LIFECYCLE')
    # Equal runtime bodies are bindings, not a theorem about public preview,
    # acquisition, autonomous policy decisions or whole products.
    return checks


def analyse(repo, out, offline=None):
    require(not out.exists(), 'OUTPUT_EXISTS')
    out.mkdir(parents=True)
    receipts = []
    for path, expected in INPUTS.items():
        data = (repo / path).read_bytes()
        require(sha(data) == expected, 'INPUT_IDENTITY:' + path)
        receipts.append({'path': path, 'sha256': expected, 'git_blob': blob(data), 'bytes': len(data)})
    material = out / 'inputs'
    material.mkdir()
    raw_archive = ((offline / 'history.tar.gz').read_bytes() if offline else download(ARCHIVE_PATH))
    old = archive_content(raw_archive)
    (material / 'history.tar.gz').write_bytes(raw_archive)
    historical_docs = {}
    for path, expected in DOCS.items():
        name = Path(path).name
        data = (offline / name).read_bytes() if offline else download(path)
        require(blob(data) == expected, 'DOCUMENT_IDENTITY:' + path)
        (material / name).write_bytes(data)
        historical_docs[path] = json.loads(data) if name.endswith('.json') else data.decode()
        receipts.append({'historical_path': path, 'head': ARCHIVE_HEAD,
                         'git_blob': expected, 'sha256': sha(data), 'bytes': len(data)})
    current = json.loads((repo / 'content/full-content.json').read_bytes())
    native = json.loads((repo / BASE / 'source-1/NATIVE-FUNCTIONS.json').read_bytes())
    historical = json.loads((repo / BASE / 'source-1/HISTORICAL-FUNCTIONS.json').read_bytes())
    source_bindings = source_law_checks(native, historical, current['cards'])
    package_protocol = historical_docs[next(iter(DOCS))]
    hand_protocol = historical_docs['research/issue-421/protocols/post-v38-hand-size-inventory-v1.json']
    packages = {k: v for k, v in package_protocol['packages'].items() if v['aspect'] == 'ashwarden'}
    require(set(packages) == {'ash-poison-catalyst', 'ash-bloodfire-leech'}, 'HISTORICAL_PACKAGE_SET')
    hand = hand_protocol['packages']['ash-hand-size-payoff']
    require(hand['producers'] == ['preparation', 'surge'] and hand['consumer'] == 'phantomBlades',
            'HAND_ROLE_BINDING')
    registry = {}
    ids = ('toxicMist', 'catalyst', 'bloodRite', 'leechBlade', 'preparation', 'surge', 'phantomBlades')
    for name in ids:
        registry[name] = {'full_card': old['cards'][name],
                         'variants': {label: source_atoms(card) for label, card in variants(old['cards'][name])}}
    all_atoms = set(itertools.chain.from_iterable(
        atoms for item in registry.values() for atoms in item['variants'].values()))
    require('add_target' not in all_atoms, 'POINT_SOURCE_IN_REGISTERED_DECOMPOSITIONS')
    require('add_all' in all_atoms and 'integer_scale_target' in all_atoms, 'POISON_KERNEL_MISSING')
    residues = fixed_point((0, 0))
    require(residues == [(0, 0)], 'KERNEL_INVARIANT')
    candidates = []
    for label, card in variants(current['cards']['venomStrike']):
        fx = [fx for fx in card['effects'] if fx['kind'] == 'status' and fx['id'] == 'poison']
        require(len(fx) == 1 and fx[0]['who'] == 'target', 'CANDIDATE_SOURCE_SHAPE')
        n = integer(fx[0]['n'])
        require(n in (4, 5), 'CANDIDATE_AUTHORED_AMOUNT')
        after = ((8 + n) % MODULUS, 0)
        candidates.append({'variant': label, 'positive_background_each_enemy': 8,
                           'source_addition': n, 'selected_stock_after_source': 8 + n,
                           'residue_after_source': list(after), 'in_kernel_closure': after in residues})
    background = {'full_historical_card': old['cards']['venomStrike'],
                  'full_current_card': current['cards']['venomStrike'],
                  'historical_atoms': {v: source_atoms(c) for v, c in variants(old['cards']['venomStrike'])},
                  'current_atoms': {v: source_atoms(c) for v, c in variants(current['cards']['venomStrike'])}}
    require(all('add_target' in atoms for atoms in background['historical_atoms'].values()),
            'BACKGROUND_COUNTERMODEL_BINDING')
    proof = {
        'status': 'SCOPED_UNBOUNDED_COMPOSITION_REFUTATION_WITH_BACKGROUND_REBINDING_COUNTERMODEL',
        'registered_packages': packages,
        'registered_hand': hand,
        'full_card_bindings': registry,
        'source_bindings': source_bindings,
        'algebra_atoms': sorted(all_atoms),
        'modulus': MODULUS,
        'integer_width_bits': 64,
        'residue_fixed_point': [list(x) for x in residues],
        'native_producer': candidates,
        'proof': [
            'Inspect one complete producer action with two living enemies, positive poison 8 on each, no Venomous, a surviving source target and no phase advance. This is a symbolic interface context, not a sampled natural run or a purity criterion.',
            'The registered poison producer applies every nonzero poison addition to ALL living enemies. Any such operation necessarily emits an untargeted-poison event. Later cancellation cannot erase that observable event. Splitting its target loop changes source multiplicity and is not a carrier rename.',
            'Discarding that generator from a putative matching trace leaves integer poison multiplications, linear transfer/deletion and operations that do not inject enemy poison. The residue fixed point is an overapproximation of arbitrarily many such operations, including coefficient changes, guarded choice and interleaving.',
            'All compatible poison stocks remain divisible by 8. This is preserved even under signed 64-bit wraparound because 8 divides 2**64. Current base/up VenomStrike yields 12/13 from selected stock 8 while leaving the other stock 8; neither is in that closure.',
            'The argument refutes these registered-role decompositions and composites, not just a few sampled words. It does not establish a full closed-family inventory or source-complete observational equivalence.',
        ],
        'background_rebinding_countermodel': background,
        'scope_countermodel': [
            'The historical BACKGROUND also contains a target-poison VenomStrike. If it can replace the registered producer, the generator add_target enters the algebra and the refutation is no longer applicable.',
            'The native Catalyst kernel is inherited. Rebinding that background producer and using the native kernel gives the source-level current role expression, not an equivalence of the archived complete product: its public-preview frame is already known to differ.',
            'Whether this is an allowed closed-family decomposition must be established from the exact closure/grammar authority. Do not decide by silently excluding background rebinding, or by labelling every background primitive closed.',
        ],
        'full_scope_obligations_not_discharged': [
            'A complete source-bound applicable closed/admitted component library, including the precisely scoped Emberglass/Kindle and other retained closures rather than assumed summary labels.',
            'An explicit permitted framing/port-rebinding/decomposition algebra and proof that the comparison covers it; names and a selection of old packages do not define this algebra.',
            'A full observable relation including public queries, acquisition and lifecycle for any proposed background-rebound comparator. Equal local runtime bodies do not supply it.',
        ],
        'formal_eligibility': False,
        'opens_population_confirmation': False,
        'new_native_runs': 0,
        'new_independent_samples': 0,
        'packages_admitted': 0,
        'p9_certified': False,
        'review_kind': 'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT',
    }
    dump(out / 'RESULTS.json', proof)
    dump(out / 'INPUTS.json', receipts)
    print(json.dumps({'status': proof['status'], 'formal_eligibility': False,
                      'native_variants_refuted_in_scoped_algebra': len(candidates),
                      'residue_states': len(residues), 'new_native_runs': 0}, sort_keys=True))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('repo', type=Path)
    parser.add_argument('out', type=Path)
    parser.add_argument('--offline-inputs', type=Path)
    args = parser.parse_args()
    analyse(args.repo, args.out, args.offline_inputs)
