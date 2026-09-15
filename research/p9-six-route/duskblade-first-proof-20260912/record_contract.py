"""Pinned sampling, stage order and legal extractor-record contracts."""
from __future__ import annotations

import reference_kernel as kernel
from evidence_boundary import BoundaryError, obj, integer, text, canonical
from record_io import ARMS, STRATA, PACKAGES, reference


def roots(values, size, reason):
    if not isinstance(values, list) or len(values) != size:
        raise BoundaryError(reason)
    effective = [kernel.effective_seed(x) for x in values]
    if len(set(effective)) != size:
        raise BoundaryError('root_duplicates')
    return effective


def producer(record, expected, schema):
    obj(record, schema)
    if (record.get('schema') != schema or
            record.get('producer_sha256') != expected['roles']['extractor_source']['sha256']):
        raise BoundaryError('extractor_record_source_schema')


def seed_set(value, reason):
    if not isinstance(value, list):
        raise BoundaryError(reason)
    return set(roots(value, len(value), reason))


def validate(records, packet, expected, receipts):
    freeze, sampler = records['freeze'], records['sampler']
    dev, exposure, features, model = (records[k] for k in ('development', 'exposure', 'features', 'model'))
    dates = [integer(x.get('timestamp'), 'stage timestamp') for x in
             (exposure, features, dev, model, freeze, sampler)]
    if dates != sorted(dates):
        raise BoundaryError('timestamp_order')
    if not dates[1] <= integer(dev.get('started_at'), 'development start') <= dates[2]:
        raise BoundaryError('development_chronology')
    if receipts['freeze']['timestamp'] < dates[-1]:
        raise BoundaryError('receipt_freeze_before_inputs')
    if freeze.get('epoch') != kernel.EPOCH or freeze.get('candidate') != expected['candidate']:
        raise BoundaryError('freeze_epoch_candidate')
    for identifier in (freeze.get('id'), sampler.get('id'), sampler.get('frame_id')):
        text(identifier, 'freeze/sampler identity')
    if sampler.get('method') != 'uniform-without-replacement':
        raise BoundaryError('sampler_method')
    frame = obj(sampler.get('frame'), 'sampling frame')
    if frame.get('mapping') != 'seed & 0xFFFFFFFF' or frame.get('domain') != [0, 2**32 - 1]:
        raise BoundaryError('sampler_frame')
    if sampler.get('draw_scope') != [f'{p}/v{v}' for p, v in STRATA]:
        raise BoundaryError('sampler_joint_draw')
    if exposure.get('status') != 'COMPLETE_NAMESPACE_INDEX':
        raise BoundaryError('missing_exposure_authority')
    namespaces = obj(exposure.get('namespaces'), 'exposure namespaces')
    if set(namespaces) != set(expected.get('required_namespaces', [])) or not namespaces:
        raise BoundaryError('missing_exposure_namespace')
    exposed = set().union(*(seed_set(values, 'exposure namespace') for values in namespaces.values()))
    if exposed != seed_set(exposure.get('exposed'), 'exposed roots'):
        raise BoundaryError('exposure_index_mismatch')
    protected = seed_set(exposure.get('protected'), 'protected roots')
    if not set(range(3000, 5400)) <= protected:
        raise BoundaryError('protected_seeds')
    for field, actual in (('exposed_seeds', exposed), ('protected_seeds', protected)):
        if field in packet and seed_set(packet[field], field) != actual:
            raise BoundaryError('exposure_claim_mismatch')
    dev_map = obj(dev.get('roots'), 'development roots')
    manifest = obj(sampler.get('manifest'), 'sampler manifest')
    keys = {f'{p}/v{v}' for p, v in STRATA}
    if set(dev_map) != keys or set(manifest) != keys:
        raise BoundaryError('stratum_manifest_keys')
    dev_roots = [r for key in sorted(keys) for r in roots(dev_map[key], 64, 'development_size')]
    preflight_roots = seed_set(exposure.get('preflight_roots'), 'preflight roots')
    if not preflight_roots:
        raise BoundaryError('preflight_roots')
    forbidden = exposed | protected | set(dev_roots) | preflight_roots
    if len(dev_roots) != len(set(dev_roots)) or set(dev_roots) & (exposed | protected | preflight_roots):
        raise BoundaryError('development_collision')
    if preflight_roots & (exposed | protected):
        raise BoundaryError('preflight_collision')
    if seed_set(sampler.get('forbidden'), 'sampler exclusions') != forbidden:
        raise BoundaryError('sampler_exclusions')
    orders = obj(sampler.get('measurement_orders'), 'frozen measurement permutations')
    if set(orders) != {f'{key}/K{k}' for key in keys for k in PACKAGES}:
        raise BoundaryError('measurement_order_set')
    all_confirm = []
    for panel, vow in STRATA:
        key = f'{panel}/v{vow}'
        assigned = roots(manifest[key], kernel.N, 'sampler_size')
        fac = records['factual'][(panel, vow)]
        producer(fac, expected, 'D547-FACTUAL-2')
        actual = roots(fac.get('roots'), kernel.N, 'factual_size')
        if actual != assigned:
            raise BoundaryError('sampler_root_order')
        crn = obj(fac.get('crn_roots'), 'mandatory CRN legs')
        kernel.validate_roots(crn, exposed | set(dev_roots) | preflight_roots, protected)
        if any(roots(crn[a], kernel.N, 'CRN size') != assigned for a in ARMS):
            raise BoundaryError('crn_mismatch')
        if set(actual) & forbidden:
            raise BoundaryError('exposed_protected_root')
        all_confirm.extend(actual)
        for k in PACKAGES:
            if set(roots(orders[f'{key}/K{k}'], kernel.N, 'measurement order size')) != set(assigned):
                raise BoundaryError('measurement_order_not_permutation')
        expected_fields = {'freeze_id': freeze['id'], 'sampler_id': sampler['id'], 'frame_id': sampler['frame_id'],
            'product': records['identities']['product'], 'profile': records['identities']['profile'][str(vow)],
            'control': records['identities']['signed_B']}
        if any(fac.get(field) != value for field, value in expected_fields.items()):
            raise BoundaryError('factual_input_identity')
        start = integer(fac.get('started_at'), 'factual start')
        finish = integer(fac.get('timestamp'), 'factual finish')
        if not receipts['freeze']['timestamp'] <= start <= finish <= receipts['extraction']['timestamp']:
            raise BoundaryError('factual_chronology')
        for k in PACKAGES:
            meas = records['measurement'][(panel, vow, k)]
            producer(meas, expected, 'D547-MEASUREMENT-2')
            if not finish <= integer(meas.get('timestamp'), 'measurement time') <= receipts['extraction']['timestamp']:
                raise BoundaryError('measurement_chronology')
        peer = records['peer'][(panel, vow)]
        producer(peer, expected, 'D547-PEER-2')
        if not finish <= integer(peer.get('timestamp'), 'peer time') <= receipts['extraction']['timestamp']:
            raise BoundaryError('peer_chronology')
    if len(all_confirm) != len(set(all_confirm)):
        raise BoundaryError('root_collision')
    validate_preflight(records, expected, dev['started_at'], preflight_roots)


def validate_preflight(records, expected, before, allowed_roots):
    preflight = records['preflight']
    if not isinstance(preflight, list):
        raise BoundaryError('preflight_schema')
    trace = obj(records['documents'].get('preflight_trace'), 'preflight native export')
    producer(trace, expected, 'D547-PREFLIGHT-EXPORT-2')
    if trace.get('native_oracle') != records['identities']['native_oracle']:
        raise BoundaryError('preflight_reader_identity')
    disagreements, seen = set(), set()
    for row in preflight:
        producer(row, expected, 'D547-PREFLIGHT-2')
        arm = row.get('arm')
        if arm not in ('R', 'K1', 'K2', 'K3') or arm in seen:
            raise BoundaryError('preflight_arm')
        seen.add(arm)
        if kernel.effective_seed(row.get('root')) not in allowed_roots:
            raise BoundaryError('preflight_root')
        if integer(row.get('timestamp'), 'preflight time') > before:
            raise BoundaryError('preflight_chronology')
        ref = row.get('state_ref')
        if not isinstance(ref, dict) or ref.get('role') != 'preflight_trace':
            raise BoundaryError('preflight_native_reference')
        state = obj(reference(records['documents'], ref), 'preflight state')
        if canonical(row.get('state')) != canonical(state):
            raise BoundaryError('preflight_state_binding')
        state_id = text(state.get('ref'), 'preflight state reference')
        if state.get('root') != row['root']:
            raise BoundaryError('preflight_state_root')
        obj(state.get('public'), 'public preflight observation')
        actions = state.get('legal_actions')
        if not isinstance(actions, list) or not actions:
            raise BoundaryError('preflight_legal_actions')
        for action in actions:
            if set(obj(action, 'legal action')) != {'command', 'arguments'}:
                raise BoundaryError('legal_action_schema')
            text(action['command'], 'command'); obj(action['arguments'], 'command arguments')
        for panel in ('A', 'B'):
            action = obj(row.get('action_' + panel), 'policy action')
            if action not in actions or row.get('policy_' + panel) != records['policies'][(panel, arm)]:
                raise BoundaryError('preflight_policy_action')
            transition_ref = obj(row.get('transition_ref_' + panel), 'transition reference')
            if transition_ref.get('role') != 'preflight_trace':
                raise BoundaryError('preflight_native_reference')
            transition = obj(reference(records['documents'], transition_ref), 'legal native transition')
            if canonical(row.get('transition_' + panel)) != canonical(transition):
                raise BoundaryError('preflight_transition_binding')
            if (transition.get('state_ref') != state_id or transition.get('action') != action or
                    transition.get('policy') != row['policy_' + panel]):
                raise BoundaryError('preflight_transition')
            text(transition.get('next_state_ref'), 'next state')
        if row['action_A'] != row['action_B']:
            disagreements.add(arm)
    if not {'K1', 'K2', 'K3'} <= disagreements:
        raise BoundaryError('panel_disagreement')
