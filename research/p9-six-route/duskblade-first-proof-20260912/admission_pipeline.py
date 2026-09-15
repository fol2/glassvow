"""D547-PC1 record-to-decision entry; no native execution or certificates.

Only a runner-created TrustedContext may provide authenticated external digests
and issuer identities. Store locators and submitted JSON never supply authority.
"""
from __future__ import annotations

import copy
import json
from pathlib import Path
import reference_kernel as kernel
import evidence_boundary as boundary
import record_io
import record_contract
import model_contract
import observation_records
import allocation_events

ARMS, STRATA, PACKAGES, PAIRS = record_io.ARMS, record_io.STRATA, record_io.PACKAGES, record_io.PAIRS
PANELS, VOWS, EPOCH = ('A', 'B'), (0, 5), kernel.EPOCH


class TrustedContext:
    """Out-of-band dependency injection, NOT an authenticator or packet field.

    The host authenticates receipt issuers and manifests before constructing this
    object. Synthetic issuers are test-only. This class never fetches a URL and
    never grants authority merely because JSON or a locator looks well formed.
    """
    def __init__(self, kind, expected_identities, expected_allocation, store,
                 receipts=None, expected_authority='D547-PC1', synthetic_ledger_bound=False):
        if kind not in ('synthetic', 'empirical'):
            raise ValueError('context kind')
        self.kind = kind
        self.expected_identities = expected_identities
        self.expected_allocation = expected_allocation
        self.store = store
        self.receipts = receipts or {}
        self.expected_authority = expected_authority
        self.synthetic_ledger_bound = synthetic_ledger_bound  # retained API; not authority

    def resolve(self, locator):
        if not isinstance(locator, str) or locator not in self.store:
            return None
        value = self.store[locator]
        if not isinstance(value, bytes):
            raise boundary.BoundaryError('resolver_must_return_bytes')
        return value

    def has_required_empirical_receipts(self):
        try:
            boundary.receipts(self, boundary.obj(self.expected_identities.get('provenance'), 'external provenance'))
            return True
        except (boundary.BoundaryError, KeyError, TypeError, ValueError):
            return False

    def copy(self):
        return TrustedContext(self.kind, copy.deepcopy(self.expected_identities),
            copy.deepcopy(self.expected_allocation), dict(self.store), copy.deepcopy(self.receipts),
            self.expected_authority, self.synthetic_ledger_bound)


def _reason_result(reason, integrity='REJECT', **extra):
    return {'integrity': integrity, 'reason': reason, 'predicates': {}, 'certificate': False,
            'empirical_certificate': False, 'game_outcome_rows': 0, 'native_invocations': 0, **extra}


def packet_guards(packet, context):
    for key in ('role', 'expected_reason', 'expected', 'known_bad'):
        if key in packet:
            raise boundary.BoundaryError('label_in_decision_input')
    for key in ('trusted_verifier', 'source_raw_complete', 'invalid_ground_truth', 'all_abstain',
                'identical_traces_renamed', 'full_equals_blind', 'everything_verified', 'trusted_context',
                'context_kind', 'trusted_resolver'):
        if key in packet:
            raise boundary.BoundaryError('packet_supplied_verdict_flag')
    if packet.get('bound') or packet.get('approved') or packet.get('binding_receipt'):
        raise boundary.BoundaryError('fabricated_binding')
    if packet.get('certificate'):
        raise boundary.BoundaryError('certificate_forbidden')
    if packet.get('game_outcome_rows'):
        raise boundary.BoundaryError('game_outcomes')
    for key, reason in (('credit_from_history', 'historical_credit'), ('borrow_548', 'alpha_548_borrow'),
                        ('second_candidate', 'second_candidate'), ('top_up', 'top_up')):
        if packet.get(key):
            raise boundary.BoundaryError(reason)
    if packet.get('authority') != context.expected_authority:
        raise boundary.BoundaryError('missing_authority')
    if packet.get('epoch') != EPOCH:
        raise boundary.BoundaryError('epoch_mismatch')


def identities(packet, records, context):
    expected = context.expected_identities
    claim = boundary.obj(packet.get('identities'), 'claim identities')
    actual = {}
    for role in ('product', 'content', 'native_oracle', 'signed_B'):
        actual[role] = boundary.digest(records['raw'][role])
        if claim.get(role) != actual[role] or expected.get(role) != actual[role]:
            raise boundary.BoundaryError(role + '_identity')
    actual['profile'] = {str(v): boundary.digest(records['raw'][f'profile_{v}']) for v in VOWS}
    actual['policies'] = {p: {a: boundary.digest(records['raw'][f'policies/{p}/{a}']) for a in ARMS} for p in PANELS}
    for role in ('profile', 'policies'):
        if claim.get(role) != actual[role] or expected.get(role) != actual[role]:
            raise boundary.BoundaryError(role + '_identity')
    if claim.get('signed_B_authority') != 'landscape-arm2-random-build-competent-play':
        raise boundary.BoundaryError('signed_B_authority')
    if any(actual['policies'][p]['B'] != actual['signed_B'] for p in PANELS):
        raise boundary.BoundaryError('signed_B_mismatch')
    if any(actual['policies']['A'][f'K{k}'] == actual['policies']['B'][f'K{k}'] for k in PACKAGES):
        raise boundary.BoundaryError('panel_route_policy_identity')
    records['identities'] = actual
    records['policies'] = {(p, a): actual['policies'][p][a] for p in PANELS for a in ARMS}


def _rows_from_counts(counts):
    return [{'key': key, 'successes': counts[key], 'n': n} for key, n in kernel.registry().items()]


def _predicates(rows):
    """The original 152 decisions; all arithmetic stays in reference_kernel."""
    kernel.validate_counts(rows)
    counts = {row['key']: row['successes'] for row in rows}
    out = {}
    for panel, vow in STRATA:
        p = f'{panel}/v{vow}'
        out[p + '/B_ceiling'] = kernel.decide(kernel.interval(counts[p+'/B.win'], kernel.N), .50, '<')
        out[p + '/R_minus_B'] = kernel.decide(kernel.paired(counts[p+'/R_B.gain'], counts[p+'/R_B.loss'], kernel.N), .35, '>=')
        for k in PACKAGES:
            q = p + f'/K{k}'
            out[q+'/quality'] = kernel.decide(kernel.paired(counts[q+'/K_R.gain'], counts[q+'/K_R.loss'], kernel.N), -.10, '>=')
            for field, metric, threshold, n, operator in (
                ('acquire', 'acquire', .30, kernel.N, '>='), ('enact', 'enact', .25, kernel.N, '>='),
                ('win_enact', 'win_enact', .10, kernel.N, '>='), ('on', 'on.correct', .80, kernel.N_MEAS, '>='),
                ('off', 'off.correct', .90, kernel.N_MEAS, '>='),
                ('natural_null', 'natural_negative.not_negative', .05, kernel.N_MEAS, '<=')):
                out[q+'/'+field] = kernel.decide(kernel.interval(counts[q+'/'+metric], n), threshold, operator)
            values = [counts[q+'/'+name] for name in ('blind_on.gain', 'blind_on.loss', 'blind_off.gain', 'blind_off.loss')]
            out[q+'/blind_gain'] = kernel.decide(kernel.balanced_gain(*values), .10, '>=')
        for k, ell in PAIRS:
            q = p + f'/pair{k}{ell}'
            for metric in ('correct_k', 'correct_l', 'exclusive_k', 'exclusive_l'):
                out[q+'/'+metric] = kernel.decide(kernel.interval(counts[q+'/'+metric], kernel.N),
                                                  .75 if metric.startswith('correct') else .10, '>=')
    return out


def evaluate_packet(packet, context=None):
    """Validate pinned evidence, derive primitives and return scoped decisions."""
    if not isinstance(packet, dict):
        return _reason_result('packet')
    if context is None:
        return _reason_result('missing_trusted_context', 'BLOCKED')
    if not isinstance(context, TrustedContext):
        return _reason_result('trusted_context')
    if packet.get('mode') == 'empirical' and context.kind != 'empirical':
        return _reason_result('empirical_cannot_select_synthetic_context', 'BLOCKED')
    if packet.get('mode') != context.kind:
        return _reason_result('mode_context_mismatch')
    try:
        boundary.obj(context.expected_identities, 'trusted identities')
        boundary.obj(context.expected_allocation, 'trusted allocation')
        boundary.obj(context.store, 'trusted store')
        boundary.obj(context.receipts, 'trusted receipts')
        packet_guards(packet, context)
        expected, receipts = boundary.verify(packet, context)
        records = record_io.ingest(packet, context)
        identities(packet, records, context)
        if boundary.canonical(records['allocation']) != boundary.canonical(packet.get('allocation')):
            raise boundary.BoundaryError('allocation_record_mismatch')
        allocation = allocation_events.validate(packet['allocation'], context, expected, receipts)
        record_contract.validate(records, packet, expected, receipts)
        cpu_by_arm = model_contract.cost_envelope(records)
        fitted = model_contract.development_models(records, expected)
        counts, predictions, root_checks = observation_records.derive(records, expected, fitted)
        rows = _rows_from_counts(counts)
        kernel.validate_counts(rows)
        if 'rows' in packet:
            kernel.validate_counts(packet['rows'])
            if {r['key']: r['successes'] for r in packet['rows']} != counts:
                raise boundary.BoundaryError('summary_mismatch')
        if context.kind == 'empirical':
            import math
            if allocation['cpu_seconds'] < math.fsum(cpu_by_arm.values()):
                raise boundary.BoundaryError('empirical_cpu_underreported')
            required = {'confirmation': len(STRATA)*len(ARMS)*kernel.N,
                'development': sum(len(entry['rows']) for roles in records['development']['evaluations'].values()
                                   for entries in roles.values() for entry in entries),
                'counterfactual': len(STRATA)*kernel.N_MEAS*sum(len(d['masks']) for d in records['features']['packages'].values())}
            if any(allocation['native_starts'][stage] < n for stage, n in required.items()):
                raise boundary.BoundaryError('empirical_execution_coverage')
        predicates = _predicates(rows)
        overall = 'FAIL' if 'FAIL' in predicates.values() else 'INCONCLUSIVE' if 'INCONCLUSIVE' in predicates.values() else 'PASS'
        if allocation['state'] == 'PASS_SUPPLEMENT' and overall != 'PASS':
            raise boundary.BoundaryError('allocation_terminal_decision_mismatch')
        if allocation['state'] == 'FAIL_FIXED_CANDIDATE' and overall != 'FAIL':
            raise boundary.BoundaryError('allocation_terminal_decision_mismatch')
        reason = 'SYNTHETIC_PACKET_WELL_FORMED' if context.kind == 'synthetic' else 'EMPIRICAL_RECORDS_VALIDATED'
        if overall != 'PASS':
            reason = 'PREDICATE_NOT_PASS'
        return _reason_result(reason, 'PASS', predicates=predicates, statistical=overall, rows=rows,
            predictions=predictions, root_checks=root_checks, allocation=allocation, cpu_by_arm=cpu_by_arm,
            manifest_sha256=expected['evidence_sha256'], inputs_sha256=expected['inputs_sha256'])
    except observation_records.InsufficientSupport as exc:
        return _reason_result(str(exc), 'INCONCLUSIVE', statistical='INCONCLUSIVE')
    except boundary.MissingAuthority as exc:
        return _reason_result(str(exc), 'BLOCKED')
    except boundary.BoundaryError as exc:
        return _reason_result(str(exc))
    except (KeyError, TypeError, ValueError, OverflowError) as exc:
        return _reason_result('schema_integrity', detail=f'{type(exc).__name__}: {exc}')


def load_allocation(path=None):
    return json.loads(Path(path or Path(__file__).with_name('ALLOCATION.json')).read_text())


def good_bundle():
    from synthetic_records import good_bundle as make
    return make()


def good_packet():
    return good_bundle()[0]
