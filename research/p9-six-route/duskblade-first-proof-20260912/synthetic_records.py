"""Complete deterministic TEST-ONLY extractor fixture, generated from primitives.

These component/policy/native records are fabricated test inputs, not Glassvow
content, a nominated candidate, native outcomes, real receipts or an allocation
spend. No empirical context can be produced by this fixture factory.
"""
from __future__ import annotations

import copy
import random
from functools import lru_cache
import reference_kernel as kernel
import evidence_boundary as boundary
import model_contract
from record_io import ARMS, STRATA, PACKAGES, PAIRS, flatten
from admission_pipeline import TrustedContext, load_allocation

CANDIDATE = 'synthetic-candidate'
HEAD = '0' * 40
MASKS = [f'{i:03b}' for i in range(8)]
SOURCE = b'# D547 test-only typed exporter; not a native implementation\n'
PRODUCER = boundary.digest(SOURCE)


def dumps(value):
    return boundary.canonical(value)


def load_json(context, locator):
    return boundary.loads(context.store[locator], locator)


def store_json(context, locator, value):
    """Mutation does NOT update external bindings. Use repin explicitly in tests."""
    context.store[locator] = dumps(value)


def ref(role, *path):
    return {'role': role, 'path': list(path)}


def native_label(active):
    return {'eligible': int(active), 'payoff': int(active), **({} if active else {'unavailable_tail': 'UNKNOWN'})}


def view(root, sequence, k, mask, active, oracle):
    return {'mask': mask, 'root': root, 'sequence': sequence, 'package': f'K{k}',
            'reader_sha256': oracle, 'public': {'energy': 2, 'chain_signal': int(active)},
            'native': native_label(active)}


def trajectory(root, arm, index, oracle, development=False):
    target = int(arm[1]) if arm.startswith('K') else None
    limit_acquire, limit_enact, limit_win = (48, 40, 52) if development else (1200, 1000, 1600)
    active = [target] if target and index < limit_enact else []
    acquired = [target] if target and index < limit_acquire else []
    # Genuine multi-route rows remain multi-label. Other-route observations are
    # taken in this SAME arm, not borrowed from another policy's trajectory.
    if target and not development and 700 <= index < 1000:
        other = target % 3 + 1
        active.append(other); acquired.append(other)
    snapshots = [{'sequence': 5, 'components': [f'component-{k}' for k in acquired], 'resources': {'charge': 1}}]
    decisions = {f'K{k}': [] for k in PACKAGES}
    if target:
        decisions[f'K{target}'].append({'sequence': 10, 'native': {
            **native_label(False), 'chain_complete': 0, 'reader_sha256': oracle},
            'views': {'111': view(root, 10, target, '111', False, oracle)}})
    for k in active:
        masks = MASKS if k == target else ['111']
        decisions[f'K{k}'].append({'sequence': 20, 'snapshot_index': 0,
            'native': {**native_label(True), 'chain_complete': 1, 'reader_sha256': oracle},
            'views': {mask: view(root, 20, k, mask, mask == '111', oracle) for mask in masks}})
    win = index < (16 if development else 400) if arm == 'B' else index < limit_win
    return {'root': root, 'terminal': {'kind': 'ordinary', 'outcome': 'win' if win else 'loss', 'sequence': 100},
            'snapshots': snapshots, 'decisions': decisions,
            'public_fingerprint': {'tempo': (target or 0) * 6, 'guarding': 1},
            'work': {'forward_evaluations': [0, 2, 4], 'cpu_seconds': .01}}


def repin(packet, context):
    """Explicit trusted-fixture repair, ONLY in test-created synthetic contexts.

    Semantic mutants use this after altering primitives, to prove a rejection
    is not merely an old digest mismatch. Ordinary store mutations never repin.
    """
    if context.kind != 'synthetic':
        raise ValueError('fixture repinning is synthetic-only')
    roles = {role: {'locator': loc, 'sha256': boundary.digest(context.store[loc])}
             for role, loc in flatten(packet['evidence']).items()}
    inputs, evidence = boundary.manifest_digests(roles)
    expected = {'environment': 'synthetic', 'epoch': kernel.EPOCH, 'artifact_head': HEAD,
                'candidate': CANDIDATE, 'roles': roles, 'inputs_sha256': inputs,
                'evidence_sha256': evidence, 'required_namespaces': ['historical-fixture'], 'receipt_authorities': {}}
    receipts = {}
    dates = {'independent_review': 1, 'binding': 2, 'freeze': 60, 'extraction': 100, 'guardrails': 101}
    for role, (scope, verdict) in boundary.SCOPES.items():
        receipt = {'schema': 'D547-RECEIPT-1', 'environment': 'synthetic', 'epoch': kernel.EPOCH,
                   'artifact_head': HEAD, 'scope': scope, 'verdict': verdict,
                   'authority': 'synthetic:' + role, 'timestamp': dates[role]}
        if role in ('freeze', 'extraction', 'guardrails'):
            receipt.update(candidate=CANDIDATE, inputs_sha256=inputs)
        if role in ('extraction', 'guardrails'):
            receipt['evidence_sha256'] = evidence
        if role == 'binding':
            receipt['review_sha256'] = boundary.digest(receipts['independent_review'])
        if role == 'extraction':
            receipt.update(producer_sha256=PRODUCER, supported_semantics=boundary.SEMANTICS)
        if role == 'guardrails':
            receipt['checks'] = {name: 'PASS' for name in boundary.GUARDS}
        receipts[role] = dumps(receipt)
        expected['receipt_authorities'][role] = {'authority': receipt['authority'], 'sha256': boundary.digest(receipts[role])}
    context.expected_identities['provenance'] = expected
    context.receipts = receipts
    return expected


def _build():
    store, evidence = {}, {}
    def put(role, value, locator=None):
        loc = locator or 'synth://' + role
        store[loc] = value if isinstance(value, bytes) else dumps(value)
        evidence[role] = loc
        return boundary.digest(store[loc])
    identities = {name: put(name, {'synthetic_fixture': name}) for name in ('product', 'content', 'native_oracle', 'signed_B')}
    identities['signed_B_authority'] = 'landscape-arm2-random-build-competent-play'
    identities['profile'] = {str(v): put(f'profile_{v}', {'synthetic_profile': v}) for v in (0, 5)}
    put('extractor_source', SOURCE)
    identities['policies'] = {}
    evidence['policies'] = {}
    for panel in ('A', 'B'):
        identities['policies'][panel], evidence['policies'][panel] = {}, {}
        for arm in ARMS:
            raw = store['synth://signed_B'] if arm == 'B' else dumps({'synthetic_policy': arm, 'decision_variant': panel if arm.startswith('K') else 'fixed'})
            loc = f'synth://policies/{panel}/{arm}'
            store[loc] = raw
            evidence['policies'][panel][arm] = loc
            identities['policies'][panel][arm] = boundary.digest(raw)
    rng = random.Random(54720260915)
    chosen = set(range(3000, 5400)) | {42, 43, 100, 101, 102, 103}
    def draw(n):
        result = []
        while len(result) < n:
            root = rng.getrandbits(32)
            if root not in chosen:
                chosen.add(root); result.append(root)
        return result
    dev_roots = {f'{p}/v{v}': draw(64) for p, v in STRATA}
    manifest = {f'{p}/v{v}': draw(kernel.N) for p, v in STRATA}
    features = {'timestamp': 20, 'policy_cost_caps': {arm: 128 for arm in ARMS}, 'full_features': ['energy', 'chain_signal'], 'blind_removed': ['chain_signal'],
        'peer_features': ['tempo', 'guarding'], 'feature_semantics': {'energy': 'public_state',
            'chain_signal': 'chain_history', 'tempo': 'public_behaviour', 'guarding': 'public_behaviour'},
        'packages': {f'K{k}': {'components': [f'component-{k}'], 'resources': {'charge': 1},
            'masks': MASKS, 'full_mask': '111', 'disabled_mask': '101', 'mec_reference': f'synthetic-MEC-{k}'} for k in PACKAGES},
        'rosters': {f'{p}/v{v}': {a: [identities['policies'][p][a]] for a in ('R', 'K1', 'K2', 'K3')} for p, v in STRATA}}
    put('features', features)
    exposure = {'timestamp': 10, 'status': 'COMPLETE_NAMESPACE_INDEX', 'namespaces': {'historical-fixture': [42, 43]},
                'exposed': [42, 43], 'protected': list(range(3000, 5400)), 'preflight_roots': [100, 101, 102, 103]}
    put('exposure_manifest', exposure, 'synth://exposure')
    dev = {'schema': 'D547-DEVELOPMENT-2', 'producer_sha256': PRODUCER, 'timestamp': 40, 'started_at': 30,
           'roots': dev_roots, 'evaluations': {}}
    for panel, vow in STRATA:
        key = f'{panel}/v{vow}'
        dev['evaluations'][key] = {arm: [{'policy_sha256': identities['policies'][panel][arm],
            'rows': [trajectory(root, arm, i, identities['native_oracle'], True) for i, root in enumerate(dev_roots[key])]}]
            for arm in ('R', 'K1', 'K2', 'K3')}
    put('development_manifest', dev, 'synth://development')
    fit_records = {'features': features, 'development': dev, 'identities': identities,
        'policies': {(p, a): identities['policies'][p][a] for p in ('A', 'B') for a in ARMS}}
    fitted = model_contract.development_models(fit_records, {'roles': {'extractor_source': {'sha256': PRODUCER}}}, False)
    put('model', {'timestamp': 45, 'fitted_on': 'development', 'strata': fitted})
    put('freeze', {'timestamp': 50, 'id': 'synthetic-freeze', 'epoch': kernel.EPOCH, 'candidate': CANDIDATE})
    forbidden = sorted(set(exposure['protected'] + exposure['exposed'] + exposure['preflight_roots'] +
                           [r for values in dev_roots.values() for r in values]))
    sampler = {'timestamp': 55, 'id': 'synthetic-sampler', 'frame_id': 'synthetic-frame',
        'frame': {'mapping': 'seed & 0xFFFFFFFF', 'domain': [0, 2**32-1]},
        'method': 'uniform-without-replacement', 'draw_scope': [f'{p}/v{v}' for p, v in STRATA],
        'manifest': manifest, 'forbidden': forbidden,
        'measurement_orders': {f'{key}/K{k}': values[:] for key, values in manifest.items() for k in PACKAGES}}
    put('sampler_manifest', sampler, 'synth://sampler')
    preflight, trace = [], {'schema': 'D547-PREFLIGHT-EXPORT-2', 'producer_sha256': PRODUCER,
                           'native_oracle': identities['native_oracle'], 'states': [], 'transitions': []}
    actions = [{'command': 'choose', 'arguments': {'index': i}} for i in (0, 1)]
    for i, arm in enumerate(('R', 'K1', 'K2', 'K3')):
        state = {'ref': f'state-{i}', 'root': 100+i, 'public': {'energy': 2}, 'legal_actions': actions}
        trace['states'].append(state)
        row = {'schema': 'D547-PREFLIGHT-2', 'producer_sha256': PRODUCER, 'timestamp': 25,
               'arm': arm, 'root': 100+i, 'state_ref': ref('preflight_trace', 'states', i), 'state': state}
        for panel in ('A', 'B'):
            action = actions[int(panel == 'B' and arm != 'R')]
            transition = {'state_ref': state['ref'], 'action': action, 'policy': identities['policies'][panel][arm],
                          'next_state_ref': f'next-{i}-{panel}'}
            index = len(trace['transitions']); trace['transitions'].append(transition)
            row.update({f'action_{panel}': action, f'policy_{panel}': transition['policy'],
                        f'transition_{panel}': transition, f'transition_ref_{panel}': ref('preflight_trace', 'transitions', index)})
        preflight.append(row)
    put('preflight', preflight); put('preflight_trace', trace)
    native_work = {arm: [] for arm in ARMS}
    for roles in dev['evaluations'].values():
        for arm, entries in roles.items():
            for entry in entries: native_work[arm].extend(row['work'] for row in entry['rows'])
    evidence.update(factual={}, measurement={}, peer={}, native_export={})
    for panel, vow in STRATA:
        key = f'{panel}/v{vow}'
        roots = manifest[key]
        source_role = 'native_export/' + key
        native = {'schema': 'D547-NATIVE-EXPORT-2', 'producer_sha256': PRODUCER, 'panel': panel, 'vow': vow,
            'product': identities['product'], 'profile': identities['profile'][str(vow)],
            'native_oracle': identities['native_oracle'], 'policies': identities['policies'][panel],
            'arms': {arm: [trajectory(root, arm, i, identities['native_oracle']) for i, root in enumerate(roots)] for arm in ARMS}}
        for arm in ARMS: native_work[arm].extend(row['work'] for row in native['arms'][arm])
        loc = 'synth://' + source_role; store[loc] = dumps(native); evidence['native_export'][key] = loc
        factual = {'schema': 'D547-FACTUAL-2', 'producer_sha256': PRODUCER, 'panel': panel, 'vow': vow,
            'roots': roots, 'crn_roots': {arm: roots for arm in ARMS}, 'freeze_id': 'synthetic-freeze',
            'sampler_id': 'synthetic-sampler', 'frame_id': 'synthetic-frame', 'product': identities['product'],
            'profile': identities['profile'][str(vow)], 'control': identities['signed_B'], 'started_at': 70, 'timestamp': 80,
            'trajectories': {arm: ref(source_role, 'arms', arm) for arm in ARMS}}
        loc = f'synth://factual/{key}'; store[loc] = dumps(factual); evidence['factual'][key] = loc
        for k in PACKAGES:
            arm = f'K{k}'
            doc = {'schema': 'D547-MEASUREMENT-2', 'producer_sha256': PRODUCER, 'panel': panel, 'vow': vow,
                'k': k, 'timestamp': 90, 'roots': roots[:256], 'natural_roots': roots[:256],
                'cases': [{'root': root, 'views': {mask: ref(source_role, 'arms', arm, i, 'decisions', arm, 1, 'views', mask)
                          for mask in MASKS}} for i, root in enumerate(roots[:256])],
                'natural_cases': [{'root': root, 'view': ref(source_role, 'arms', arm, i, 'decisions', arm, 0, 'views', '111')}
                                  for i, root in enumerate(roots[:256])]}
            loc = f'synth://meas/{key}/{arm}'; store[loc] = dumps(doc); evidence['measurement'][f'{key}/{arm}'] = loc
        peer = {'schema': 'D547-PEER-2', 'producer_sha256': PRODUCER, 'panel': panel, 'vow': vow,
                'timestamp': 90, 'roots': roots, 'sources': {f'K{k}': ref(source_role, 'arms', f'K{k}') for k in PACKAGES}}
        loc = f'synth://peer/{key}'; store[loc] = dumps(peer); evidence['peer'][key] = loc
    import math
    cost = {}
    for arm, work in native_work.items():
        evaluations = [value for record in work for value in record['forward_evaluations']]
        ordered = sorted(evaluations)
        cost[arm] = {'hidden_rng': False, 'privileged': False, 'forward_evals_per_decision': 128,
            'statistics': {'total': sum(evaluations), 'p50': ordered[math.ceil(len(ordered)*.50)-1],
                           'p95': ordered[math.ceil(len(ordered)*.95)-1], 'invocations': len(work)},
            'cpu_seconds': math.fsum(record['cpu_seconds'] for record in work)}
    put('cost', cost)
    allocation = load_allocation(); put('allocation', allocation)
    packet = {'mode': 'synthetic', 'authority': 'D547-PC1', 'epoch': kernel.EPOCH,
              'identities': identities, 'evidence': evidence, 'allocation': allocation}
    context = TrustedContext('synthetic', copy.deepcopy(identities), load_allocation(), store)
    repin(packet, context)
    return packet, context


@lru_cache(maxsize=1)
def _cached():
    return _build()


def good_bundle():
    packet, context = _cached()
    return copy.deepcopy(packet), context.copy()
