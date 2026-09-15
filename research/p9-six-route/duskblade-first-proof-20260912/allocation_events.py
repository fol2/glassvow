"""Canonical D547-PC1 allocation: typed, idempotent event-to-state fold.

This validator performs no execution and never edits the real zero-spend file.
An event describes a previously recorded invocation, not permission to launch it.
"""
from __future__ import annotations

import copy
import math
import re
import reference_kernel as kernel
from evidence_boundary import BoundaryError, obj, integer, text, canonical, digest

INITIAL = 'OWNER_AUTHORISED_DESIGN_NOT_BOUND'
STATES = (INITIAL, 'SPEC_BOUND', 'CANDIDATE_PREFLIGHT', 'DEVELOPMENT',
          'REFERENCE_CONFIRMATION', 'ROUTE_CONFIRMATION')
TERMINAL = {'PASS_SUPPLEMENT', 'FAIL_FIXED_CANDIDATE', 'INCONCLUSIVE', 'INVALID_CAPTURE'}
EXECUTION_STATES = {'preflight': {'CANDIDATE_PREFLIGHT'}, 'development': {'DEVELOPMENT'},
                    'confirmation': {'REFERENCE_CONFIRMATION', 'ROUTE_CONFIRMATION'},
                    'counterfactual': {'ROUTE_CONFIRMATION'}}


def finite(value, name):
    if type(value) not in (int, float) or not math.isfinite(value) or value < 0:
        raise BoundaryError('schema:' + name)
    return value


def immutable(alloc):
    out = copy.deepcopy(obj(alloc, 'allocation'))
    for field in ('status', 'binding_receipt', 'independent_review', 'candidate',
                  'usage', 'exposure_frame_manifest', 'event_log'):
        out.pop(field, None)
    obj(out.get('candidate_attempts'), 'candidate attempts').pop('used', None)
    alpha = obj(obj(out.get('alpha'), 'alpha').get('542'), '542 alpha')
    alpha.pop('committed', None); alpha.pop('status', None)
    for stage in kernel.CAPS:
        obj(obj(out.get('native_starts'), 'native starts').get(stage), 'native stage').pop('used', None)
    return out


def fold(alloc, expected, receipts):
    events = alloc.get('event_log')
    if not isinstance(events, list):
        raise BoundaryError('allocation_event_schema')
    ledger = kernel.Ledger(bound=True)
    state, alpha, seen, invocations, assignments = INITIAL, False, {}, set(), {}
    previous_time, intervals, last_elapsed = -1, [], 0
    for event in events:
        event = obj(event, 'allocation event')
        identifier = text(event.get('event_id'), 'event id')
        encoded = canonical(event)
        if identifier in seen:
            if encoded != seen[identifier]:
                raise BoundaryError('conflicting_event_readback')
            continue
        seen[identifier] = encoded
        timestamp = finite(event.get('timestamp'), 'event timestamp')
        if timestamp < previous_time:
            raise BoundaryError('allocation_event_order')
        previous_time = timestamp
        if event.get('epoch') != kernel.EPOCH:
            raise BoundaryError('event_epoch')
        kind = event.get('kind')
        if kind == 'transition':
            target = event.get('to')
            if event.get('from') != state or state in TERMINAL:
                raise BoundaryError('allocation_transition')
            legal_next = STATES[STATES.index(state)+1] if state in STATES[:-1] else None
            if target != legal_next and target not in TERMINAL:
                raise BoundaryError('allocation_transition')
            if target == 'PASS_SUPPLEMENT' and state != 'ROUTE_CONFIRMATION':
                raise BoundaryError('premature_supplement_state')
            if target == 'SPEC_BOUND' and timestamp < receipts['binding']['timestamp']:
                raise BoundaryError('spending_before_binding')
            if target == 'REFERENCE_CONFIRMATION':
                if timestamp < receipts['freeze']['timestamp']:
                    raise BoundaryError('confirmation_before_freeze')
                alpha = True
            state = target
            continue
        if kind != 'execution' or event.get('stage') not in EXECUTION_STATES:
            raise BoundaryError('allocation_event_kind')
        stage = event['stage']
        if state not in EXECUTION_STATES[stage]:
            raise BoundaryError('execution_stage_state')
        if event.get('candidate') != expected['candidate']:
            raise BoundaryError('second_candidate')
        if type(event.get('count')) is not int or event['count'] != 1:
            raise BoundaryError('one_event_per_native_start')
        invocation = text(event.get('invocation_id'), 'invocation id')
        if invocation in invocations:
            raise BoundaryError('renamed_invocation')
        invocations.add(invocation)
        assignment = text(event.get('assignment_id'), 'assignment id')
        result = text(event.get('result_sha256'), 'result digest')
        if not re.fullmatch('[0-9a-f]{64}', result):
            raise BoundaryError('result_digest')
        if assignment in assignments and assignments[assignment] != result:
            raise BoundaryError('conflicting_assignment_result')
        assignments[assignment] = result
        registered = finite(event.get('registered_at'), 'start registration')
        started, finished = finite(event.get('started_at'), 'native start'), finite(event.get('finished_at'), 'native finish')
        if not receipts['binding']['timestamp'] <= registered <= started < finished <= timestamp:
            raise BoundaryError('native_event_chronology')
        if stage in ('confirmation', 'counterfactual') and started < receipts['freeze']['timestamp']:
            raise BoundaryError('confirmation_before_freeze')
        cpu = finite(event.get('cpu'), 'native cpu')
        elapsed = finite(event.get('elapsed'), 'cumulative active elapsed')
        raw = integer(event.get('raw'), 'raw emitted bytes')
        if cpu > 300 or elapsed < last_elapsed or elapsed < finished-started:
            raise BoundaryError('native_invocation_cap')
        last_elapsed = elapsed
        try:
            ledger.debit(identifier, event['candidate'], stage, 1, cpu=cpu, elapsed=elapsed, raw=raw)
        except ValueError as exc:
            raise BoundaryError('allocation_cap:' + str(exc)) from exc
        intervals.extend(((started, 1), (finished, -1)))
    live = 0
    for _, change in sorted(intervals, key=lambda pair: (pair[0], pair[1])):
        live += change
        if live > 2:
            raise BoundaryError('concurrency_cap')
    return {'state': state, 'alpha': alpha, 'ledger': ledger, 'attempts': int(bool(invocations)),
            'invocations': len(invocations), 'assignments': assignments}


def validate(alloc, context, expected, receipts):
    canonical_alloc = context.expected_allocation
    if canonical(immutable(alloc)) != canonical(immutable(canonical_alloc)):
        raise BoundaryError('allocation_template')
    result = fold(alloc, expected, receipts)
    ledger, state = result['ledger'], result['state']
    if alloc.get('status') != state:
        raise BoundaryError('allocation_status_reconciliation')
    if integer(alloc['candidate_attempts'].get('used'), 'candidate attempts used') != result['attempts']:
        raise BoundaryError('candidate_attempt_reconciliation')
    expected_candidate = expected['candidate'] if result['attempts'] else None
    if alloc.get('candidate') != expected_candidate:
        raise BoundaryError('candidate_reconciliation')
    if state == INITIAL:
        binding, review = None, None
    else:
        binding = digest(context.receipts['binding'])
        review = digest(context.receipts['independent_review'])
    if alloc.get('binding_receipt') != binding or alloc.get('independent_review') != review:
        raise BoundaryError('allocation_receipt_reconciliation')
    amount, alpha_status = (kernel.ALPHA_542, 'COMMITTED') if result['alpha'] else (0, 'NOT_COMMITTED')
    alpha = alloc['alpha']['542']
    if type(alpha.get('committed')) not in (int, float) or alpha['committed'] != amount or alpha.get('status') != alpha_status:
        raise BoundaryError('allocation_alpha_reconciliation')
    frame = expected['roles']['sampler_manifest']['sha256'] if result['alpha'] else None
    if alloc.get('exposure_frame_manifest') != frame:
        raise BoundaryError('allocation_frame_reconciliation')
    for stage in kernel.CAPS:
        if integer(alloc['native_starts'][stage].get('used'), 'stage usage') != ledger.spent[stage]:
            raise BoundaryError('allocation_native_reconciliation')
    usage = obj(alloc.get('usage'), 'resource usage')
    if set(usage) != {'cpu_seconds', 'active_elapsed_seconds', 'raw_emitted_bytes_cumulative'}:
        raise BoundaryError('allocation_usage_schema')
    if (finite(usage['cpu_seconds'], 'cpu usage') != ledger.cpu or
            finite(usage['active_elapsed_seconds'], 'elapsed usage') != ledger.elapsed or
            integer(usage['raw_emitted_bytes_cumulative'], 'raw usage') != ledger.raw):
        raise BoundaryError('allocation_usage_reconciliation')
    if context.kind == 'empirical' and (not result['alpha'] or not result['invocations']):
        raise BoundaryError('empirical_records_without_execution_account')
    return {'state': state, 'candidate_attempts': result['attempts'], 'native_starts': ledger.spent,
            'cpu_seconds': ledger.cpu, 'elapsed_seconds': ledger.elapsed, 'raw_bytes': ledger.raw}
