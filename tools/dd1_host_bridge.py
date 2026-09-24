#!/usr/bin/env python3
"""DD1-HOST-BRIDGE-1: external host integration, not another runner or issuer API.

Default inspection is nonexecuting. commission() always retrieves LIVE owner
records itself; a saved report, user context, callback or empirical string is
never its authority. Native deployment of this source-only change is NOT granted
by its selection. The exact bridge/qualification review and custody are gates.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import resource
import re
import sys
from types import MappingProxyType

sys.path.insert(0, str(Path(__file__).resolve().parent))
import dd1_host_channel as channel
import dd1_host_custody as custody
from dd1_host_channel import BridgeError, canonical, decode, need, sha, stamp

ROOT = Path(__file__).resolve().parents[1]
OPERATION = 'DD1-LINUX-ENTRY-1'
BRIDGE_FILES = ('tools/dd1_host_bridge.py', 'tools/dd1_host_channel.py', 'tools/dd1_host_custody.py')
BASE_ROLES = {'cumulative_cost', 'execution_demand', 'compatibility_profile', 'compatibility_disposition',
              'runtime_fit_profile', 'runtime_fit_modes', 'runtime_fit_projection',
              'runtime_fit_disposition', 'runtime_fit_thread_bound'}
PREP_ROLES = {'preparation_recipe', 'preparation_projection', 'preparation_producer',
              'preparation_writer_closure', 'preparation_disposition'}
ISSUER = 'github:fol2/glassvow:owner-105634418:DD1-HOST-BRIDGE-1'


class _HostContext:
    """Internal, host-only transport AFTER channel/issuer validation."""
    def __init__(self, expected, store, receipts):
        self.kind = 'empirical'
        self.expected_identities = {'provenance': decode(canonical(expected))}
        self._store = MappingProxyType(dict(store))
        self.receipts = MappingProxyType(dict(receipts))

    def resolve(self, locator):
        return self._store.get(locator) if isinstance(locator, str) else None


def required_roles(unit):
    roles = set(BASE_ROLES)
    if unit.get('preparation') is not None:
        roles |= PREP_ROLES
    if unit.get('sealed_input') is not None:
        roles |= {'preparation_seal', 'preparation_projection'}
    return roles


def scope(doc, schema, head, stage=None):
    need(isinstance(doc, dict) and doc.get('schema') == schema, 'record schema')
    need(doc.get('repository') == channel.REPOSITORY and doc.get('operation') == OPERATION,
         'record repository/operation')
    need(doc.get('artifact_head') == head, 'record exact artifact')
    if stage is not None:
        need(doc.get('stage') == stage, 'record stage')


def window_reasons(unit, now=None):
    now = now or datetime.now(timezone.utc)
    end = stamp(custody.DEADLINE)
    reasons = []
    if now >= end:
        reasons.append('original recovery window expired')
    wall = unit.get('wall_seconds')
    if type(wall) not in (int, float) or not 3 <= wall <= 3600:
        reasons.append('invalid complete wall envelope')
    elif (end - now).total_seconds() < wall:
        reasons.append('complete unit and cleanup cannot fit original deadline')
    return reasons


def deployment_reasons(deployment, review, confirmation, registry, unit, host, head):
    """Pure decision checks; no authentication is conferred by calling this."""
    reasons = []
    for doc, schema in ((deployment, 'DD1-HOST-BRIDGE-DEPLOYMENT-1'),
                        (review, 'DD1-HOST-BRIDGE-REVIEW-1'),
                        (confirmation, 'DD1-HOST-CUSTODIAN-CONFIRMATION-1')):
        try:
            scope(doc, schema, head)
        except BridgeError as exc:
            reasons.append(str(exc) + ':' + schema)
    def check(ok, reason):
        if not ok:
            reasons.append(reason)
    check(deployment.get('scope') == 'ENGINEERING_ONLY' and deployment.get('launch_selected') is True,
          'source/inert selection is not native deployment')
    check(deployment.get('selection_comment') == channel.SELECTION and
          deployment.get('deadline_utc') == custody.DEADLINE, 'deployment selection/deadline')
    check(deployment.get('stage') == unit.get('stage') and deployment.get('host') == host,
          'deployment stage/host')
    check(review.get('verdict') == 'APPROVE' and review.get('scope') == 'HOST_BRIDGE_AND_QUALIFICATION' and
          isinstance(review.get('author_session'), str) and isinstance(review.get('reviewer_session'), str) and
          bool(review['author_session']) and bool(review['reviewer_session']) and
          review['author_session'] != review['reviewer_session'], 'missing distinct scoped review')
    check(review.get('qualification_sha256') == deployment.get('qualification_sha256') and
          isinstance(review.get('qualification_sha256'), str), 'review does not bind qualification')
    check(confirmation.get('executor_identity') == registry.get('executor_identity') and
          confirmation.get('generation') == registry.get('current_generation') and
          confirmation.get('reservation_history_sha256') == registry.get('reservation_history_sha256') and
          confirmation.get('same_existing_custodian') is True and
          confirmation.get('other_executors_retired') is True and
          confirmation.get('unresolved_history') == [], 'original custody not confirmed/reconciled')
    return reasons


def verify_code(api, root, head, manifest):
    """All host bridge and imported DD1/H sources checked before trusted import."""
    need(isinstance(manifest, dict) and set(BRIDGE_FILES) <= manifest.keys(), 'host implementation pin map missing')
    # Import closure is mechanically checked below; a manifest cannot omit a
    # transitive dd1_ module merely because the top-level file is correct.
    import ast
    pending = list(BRIDGE_FILES); seen = set()
    while pending:
        name = pending.pop()
        if name in seen:
            continue
        seen.add(name)
        need(name in manifest, 'missing host source pin:' + name)
        pin = manifest[name]
        remote = api.file(head, name, pin)
        local, _ = custody.read_existing(root / name, 1024 * 1024)
        need(local == remote, 'loaded host source differs:' + name)
        for node in ast.walk(ast.parse(local)):
            modules = []
            if isinstance(node, ast.Import):
                modules = [x.name for x in node.names]
            elif isinstance(node, ast.ImportFrom) and node.module:
                modules = [node.module]
            pending.extend('tools/' + m + '.py' for m in modules if m.startswith('dd1_') and '.' not in m)
    for name, pin in channel.H_PINS.items():
        remote = api.file(channel.H, channel.H_ROOT + name, pin)
        local, _ = custody.read_existing(root / channel.H_ROOT / name, 65536)
        need(local == remote, 'accepted H source differs:' + name)
    # Entry dependencies are required even if imported dynamically below.
    need({'tools/dd1_meter_entry.py', 'tools/dd1_reservations.py', 'tools/dd1_provenance.py',
          'tools/dd1_linux_backend.py', 'tools/dd1_linux_snapshot.py', 'tools/dd1_recovery_meter.py'} <= seen,
         'host entry dependency closure incomplete')
    return seen


def price_plan(cost, unit, now=None):
    """Arithmetic over authenticated qualification; never estimates missing costs."""
    now = now or datetime.now(timezone.utc)
    need(cost.get('current_unit_sha256') == sha(canonical(unit)), 'price/demand identity')
    need(cost.get('unpriced_terms') == [] and cost.get('source_witnesses'), 'unpriced cumulative terms')
    rows = cost.get('remaining_units')
    need(isinstance(rows, list) and 1 <= len(rows) <= 6, 'missing finite useful-endpoint plan')
    total = dict(starts=0, cpu_ns=channel.natural(cost.get('prior_unledgered_cpu_ns'), 'prior CPU'),
                 raw_bytes=channel.natural(cost.get('prior_unledgered_raw_bytes'), 'prior raw'), wall_seconds=0)
    order = {'identity': 0, 'preparation': 1, 'parse': 2, 'fixture': 3}
    previous = -1; seen = set(); parsers = []
    for index, row in enumerate(rows):
        need(isinstance(row, dict) and row.get('stage') in order, 'invalid planned stage')
        stage = row['stage']
        need(order[stage] >= previous and (stage == 'parse' or stage not in seen), 'planned stage ordering')
        previous = order[stage]; seen.add(stage)
        if stage == 'parse':
            script = row.get('script')
            need(isinstance(script, str) and script.startswith('res://') and script.endswith('.gd')
                 and '..' not in script.split('/') and script not in parsers, 'planned parser identity')
            parsers.append(script)
        need(channel.natural(row.get('contained_starts'), 'planned contained starts') == (2 if stage == 'fixture' else 0),
             'planned contained-start scope')
        cpu = channel.natural(row.get('cpu_seconds'), 'planned CPU')
        raw = channel.natural(row.get('raw_bytes'), 'planned raw')
        wall = channel.natural(row.get('wall_seconds'), 'planned wall')
        need(11 <= cpu <= 300 and 0 < raw <= 1073741824 and 3 <= wall <= 3600, 'planned resource bound')
        need(isinstance(row.get('input_contract_sha256'), str) and re.fullmatch(r'[0-9a-f]{64}', row['input_contract_sha256']),
             'missing prospective input/output contract')
        if index == 0:
            need(all(row.get(k) == unit.get(k) for k in ('stage','cpu_seconds','raw_bytes','wall_seconds','contained_starts')),
                 'current unit differs from complete plan')
        total['starts'] += 1 + row['contained_starts']
        total['cpu_ns'] += cpu * 10**9; total['raw_bytes'] += raw; total['wall_seconds'] += wall
    need(cost.get('remaining_required_parsers') == parsers, 'required parser set not priced')
    need(rows[-1]['stage'] == 'fixture' and cost.get('endpoint') == 'res://tests/test_dd1_source_repair.gd',
         'missing authorized useful endpoint')
    need(total['starts'] <= 8, 'plan exceeds original eight-start ceiling')
    need((stamp(custody.DEADLINE)-now).total_seconds() >= total['wall_seconds'], 'whole useful path cannot fit deadline')
    return total


def read_roles(api, qualification, unit, head):
    scope(qualification, 'DD1-HOST-QUALIFICATION-1', head, unit.get('stage'))
    need(qualification.get('host') == unit.get('runtime_fit', {}).get('host'), 'qualification host')
    need(qualification.get('account_sha256') == unit.get('account_sha256'), 'qualification ledger generation')
    files = qualification.get('roles')
    need(isinstance(files, dict) and required_roles(unit) <= files.keys() and len(files) <= 32,
         'missing prospective engineering roles')
    store = {}
    ref = channel.commit(qualification.get('records_ref'))
    for role, item in files.items():
        need(isinstance(role, str) and isinstance(item, dict), 'invalid role descriptor')
        raw = api.file(ref, item['path'], item['git_blob'])
        need(sha(raw) == item.get('sha256'), 'changed qualification bytes:' + role)
        store[role] = raw
    need(store['execution_demand'] == canonical(unit), 'qualification does not bind exact demand')
    for role, value in (('compatibility_profile', unit.get('compatibility')),
                        ('runtime_fit_profile', unit.get('runtime_fit')),
                        ('runtime_fit_modes', unit.get('execution_modes')),
                        ('runtime_fit_projection', unit.get('mode_projection'))):
        need(store[role] == canonical(value), 'changed bound unit role:' + role)
    return store


def _compose_verified(store, unit, boundary):
    """Use only inside live bootstrap after authenticated qualification read.

    Does not generate launch_admitted, thread closure, writer or cost assertions.
    Existing dispositions are consumed only with the designated issuing role.
    """
    need(required_roles(unit) <= store.keys(), 'missing required role store')
    authorities, receipts = {}, {}
    for role in ('compatibility_disposition', 'runtime_fit_disposition', 'preparation_disposition'):
        if role in store:
            doc = decode(store[role])
            need(doc.get('authority') == ISSUER, 'disposition from undesignated producer')
            authorities[role] = dict(authority=ISSUER, sha256=sha(store[role]))
            receipts[role] = store[role]
    roles = {name: dict(locator=name, sha256=sha(raw)) for name, raw in store.items()}
    inputs, evidence = boundary.manifest_digests(roles)
    expected = dict(environment='empirical', epoch=boundary.kernel.EPOCH,
                    artifact_head=unit['overlay_head'], candidate=unit['unit_id'], roles=roles,
                    inputs_sha256=inputs, evidence_sha256=evidence, receipt_authorities=authorities)
    return _HostContext(expected, store, receipts), dict(evidence={name: name for name in roles})


def inspect(unit, head, root=ROOT):
    """Public nonexecuting preflight. Never accepts a provider/context callback."""
    report, _ = _inspect(unit, head, Path(root))
    return report


def _inspect(unit, head, root):
    channel.commit(head)
    need(isinstance(unit, dict), 'unit object required')
    unit = decode(canonical(unit))
    report = dict(schema='DD1-HOST-BRIDGE-INSPECTION-1', head=head, operation=OPERATION,
                  inspected_utc=datetime.now(timezone.utc).isoformat(), rows={},
                  native_admitted=False, executed=False, live_account_writes=0)
    def row(name, reasons, **evidence):
        report['rows'][name] = dict(status='BLOCKED' if reasons else 'VERIFIED', reasons=reasons, **evidence)
    row('window', window_reasons(unit))
    try:
        host = custody.host_facts()
        row('host', [] if (host['system'], host['release'], host['machine'], host['pointer_bytes'], host['long_bytes']) ==
            ('Linux', '6.18.44', 'x86_64', 8, 8) else ['unsupported fixed ABI'], observation=host)
    except OSError as exc:
        host = {}; row('host', ['host observation unavailable:' + type(exc).__name__])
    observation = custody.observe(root)
    row('custody', ['authenticated registration not yet available'], observation=observation)
    row('deployment', ['missing authenticated bridge deployment and distinct bridge/qualification review'])
    row('qualification', ['missing authenticated role:' + name for name in sorted(required_roles(unit))])
    row('local_inputs', ['actual source/runtime/helper byte closure not verified'])
    row('price', ['missing complete cumulative_cost and useful-endpoint reservation plan'])
    row('existing_validators', ['not entered: live authentication, custody and technical records must qualify first'])
    try:
        identities = {}
        for name, pin in channel.H_PINS.items():
            raw, _ = custody.read_existing(root / channel.H_ROOT / name, 65536)
            need(channel.git_blob(raw) == pin, 'changed accepted H bytes:' + name)
            identities[name] = dict(git_blob=pin, sha256=sha(raw), bytes=len(raw))
        row('accepted_H_source', [], identities=identities, scope='local pinned bytes; not issuer authentication')
    except (OSError, BridgeError) as exc:
        row('accepted_H_source', [str(exc)])
    state = None
    api = channel.GitHubReadOnly()
    try:
        selection = api.selection()
        registration = api.comment(custody.REGISTRATION_COMMENT, 421)
        registry = registration.document('DD1-HOST-CUSTODY-REGISTRATION-1')
        row('authenticated_retrieval', [], selection_body_sha256=selection.body_sha256,
            registration_body_sha256=registration.body_sha256)
        row('custody', custody.reasons(registry, observation, host, root, head, unit), observation=observation)
        # These are concrete owner-controlled GitHub comment locators, not a
        # caller-made TrustedContext or an unnamed external service.
        missing = [k for k in ('deployment_comment', 'qualification_comment', 'original_custodian_confirmation')
                   if type(registry.get(k)) is not int or registry[k] <= 0]
        need(not missing, 'missing registered owner records:' + ','.join(missing))
        deployment_record = api.comment(registry['deployment_comment'], 421)
        deployment = deployment_record.document('DD1-HOST-BRIDGE-DEPLOYMENT-1')
        review_record = api.comment(deployment['review_comment'], 542)
        review = review_record.document('DD1-HOST-BRIDGE-REVIEW-1')
        confirmation = api.comment(registry['original_custodian_confirmation'], 421).document('DD1-HOST-CUSTODIAN-CONFIRMATION-1')
        row('deployment', deployment_reasons(deployment, review, confirmation, registry, unit, host, head))
        need(review_record.body_sha256 == deployment.get('review_body_sha256'), 'changed review record')
        qualified_record = api.comment(registry['qualification_comment'], 421)
        need(qualified_record.body_sha256 == deployment.get('qualification_sha256'), 'changed technical qualification')
        qualification = qualified_record.document('DD1-HOST-QUALIFICATION-1')
        store = read_roles(api, qualification, unit, head)
        row('qualification', [], roles=sorted(store), issuer=ISSUER)
        # No empirical context is assembled while any already-known gate fails.
        need(all(r['status'] == 'VERIFIED' for n, r in report['rows'].items()
                 if n in ('window', 'host', 'custody', 'deployment', 'authenticated_retrieval', 'qualification')),
             'pre-admission gate failed')
        verify_code(api, root, head, deployment['host_source_blobs'])
        import dd1_meter_entry as entry
        import dd1_provenance as provenance
        import dd1_compatibility as compatibility
        import dd1_reservations as reservations
        import dd1_recovery_meter as meter
        entry.check_h_closure(root / channel.H_ROOT)
        boundary = provenance._load_boundary()
        context, packet = _compose_verified(store, unit, boundary)
        expected = boundary.verify_bindings(packet, context)
        compatibility.native_bindings(unit, expected, context)
        # snapshot.prepare reads immutable bytes and validates output limits; it
        # does not execute a loader, create a private root, seal or reserve.
        raw_account, _ = custody.read_existing(root / custody.ACCOUNT_REL)
        account = decode(raw_account)
        need(sha(raw_account) == unit.get('account_sha256'), 'ledger changed after custody observation')
        receipt_raw, _ = custody.read_existing(root / custody.RECEIPT_REL, 65536)
        need(sha(receipt_raw) == unit.get('receipt_sha256'), 'launch receipt identity')
        meter.validate_launch_receipt(decode(receipt_raw), bindings=meter.load_bindings(),
            account=account, overlay_head=head, require_descendant=False)
        generated = entry.preparation.load_sealed(unit, account)
        pins = entry.backend.snapshot.prepare(unit, unit['argv'], root, generated)
        need(not any('/' + p in name for p in BRIDGE_FILES for name in pins['files']),
             'host policy must not be copied into workload')
        reservations.validate_unit(unit, unit['argv'], head=head, receipt_sha=sha(receipt_raw),
            account_sha=sha(raw_account), source_reader=lambda n: pins['source'][n])
        reservations.available(account, 1 + unit['contained_starts'], unit['cpu_seconds'] * 10**9, unit['raw_bytes'])
        row('local_inputs', [], source_files=len(pins['source']), private_files=len(pins['files']))
        setup = pins['setup_raw'] + len(receipt_raw) + 5*len(raw_account) + 4*len(canonical(unit)) + 561152
        need(setup + unit['linux']['workload_raw_bytes'] <= unit['raw_bytes'], 'complete unit raw envelope')
        cost = decode(store.get('cumulative_cost', b'{}'))
        need(cost.get('schema') == 'DD1-HOST-CUMULATIVE-COST-1' and
             cost.get('account_sha256') == sha(raw_account) and cost.get('unpriced_terms') == [] and
             cost.get('source_witnesses'), 'incomplete cumulative price or unknown prior costs')
        planned = price_plan(cost, unit)
        reservations.available(account, planned['starts'], planned['cpu_ns'], planned['raw_bytes'])
        row('price', [], complete_unit_setup_raw=setup, total_unit_raw=unit['raw_bytes'], useful_endpoint_plan=planned)
        row('existing_validators', [], H=channel.H, native_positive=False)
        need(api.comment(custody.REGISTRATION_COMMENT, 421).body_sha256 == registration.body_sha256,
             'custody registration changed during bootstrap')
        need(not window_reasons(unit), 'deadline elapsed during bootstrap')
        state = (context, packet, registration.body_sha256)
    except (ValueError, OSError, KeyError, TypeError, AttributeError, ImportError, RuntimeError) as exc:
        report['blocking_exception'] = type(exc).__name__ + ':' + str(exc)
        if 'authenticated_retrieval' not in report['rows']:
            row('authenticated_retrieval', [report['blocking_exception']])
    finally:
        report['channel_observations'] = api.observations
        api.close()
    report['native_admitted'] = state is not None and all(r['status'] == 'VERIFIED' for r in report['rows'].values())
    report['status'] = 'ADMISSION_VERIFIED_NOT_EXECUTED' if report['native_admitted'] else 'BLOCKED_BEFORE_RESERVATION'
    return report, state


def commission(unit, head, root=ROOT):
    """Concrete native caller. No caller-supplied context, clock or runner."""
    root = Path(root)
    need(root.resolve() == ROOT, 'entry must use its installed source root')
    need(unit.get('mode') == 'engineering', 'native bridge rejects synthetic/ordinary mode')
    report, state = _inspect(unit, head, root)
    need(report['native_admitted'] and state is not None, report.get('blocking_exception', report['status']))
    # Same process: authentication/preflight CPU is NOT reset by forking a new
    # controller. Existing entry rejects a nonfresh or multithreaded process.
    used = resource.getrusage(resource.RUSAGE_SELF)
    need(len(list(Path('/proc/self/task').iterdir())) == 1 and used.ru_utime + used.ru_stime < 1,
         'existing controller freshness requirement not met')
    need(not window_reasons(unit), 'window changed before entry')
    context, packet, _ = state
    import dd1_meter_entry as entry
    return entry.run_complete_unit(unit['argv'], unit=unit,
        account_path=root / custody.ACCOUNT_REL, receipt_path=root / custody.RECEIPT_REL,
        output=Path(unit['linux']['output_root']), head=head, repo=root,
        trusted_context=context, evidence_packet=packet)


def inert(unit, *, account_path, receipt_path, output, head, repo):
    """Explicit test-only integration. SAME existing inert entry and allowlist."""
    need(unit.get('mode') == 'inert_control', 'inert bridge rejects native mode')
    need(Path(account_path).resolve().is_relative_to(Path(repo).resolve()) is False,
         'inert account must be outside repository')
    raw, _ = custody.read_existing(Path(account_path).absolute())
    need(decode(raw).get('synthetic') is True, 'inert bridge requires synthetic account')
    import dd1_meter_entry as entry
    return entry._run_inert_unit(unit['argv'], unit=unit, account_path=Path(account_path),
        receipt_path=Path(receipt_path), output=Path(output), head=head, repo=Path(repo))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('inspect', 'commission'))
    parser.add_argument('--head', required=True)
    parser.add_argument('--unit', type=Path, required=True)
    args = parser.parse_args()
    try:
        raw, _ = custody.read_existing(args.unit.absolute(), 1024*1024)
        unit = decode(raw)
        result = inspect(unit, args.head) if args.action == 'inspect' else commission(unit, args.head)
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0 if result.get('native_admitted') or result.get('success') else 2
    except (ValueError, OSError, RuntimeError, KeyError, TypeError) as exc:
        print(json.dumps(dict(status='ERROR_NO_OUTCOME_ASSERTED', error=type(exc).__name__+':'+str(exc),
                              account_readback_required=args.action == 'commission')))
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
