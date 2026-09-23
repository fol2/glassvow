"""Selected finite thread/mode amendment. No launcher or native issuer.

The 14-slot maximum is a storage/diagnostic bound, not an engine upper bound.
Actual native stage bounds and build provenance require authenticated H roles.
"""
import hashlib
import json
import os
from pathlib import Path
import platform
import stat
import struct
import dd1_reservations as r

PROFILE = 'DD1-RUNTIME-FIT-1'
SELECTION = 5793093948
MAX_THREADS = 14
REFUSAL_RECORDS = 32
ENGINE_SOURCE = 'ed1daf0bf001b61586d9930840f2f1394092c079'
SENTRY_SOURCE = 'd288ad983c30bf7a7d924fbceb8ed7cf6e64de9c'
HANDLER = 'res://addons/sentry/bin/linux/x86_64/crashpad_handler'
HANDLER_BLOB = 'a1127a09bc08f18cb4c4add7afcd11ef4dc02ecd'
DESCRIPTOR = 'res://addons/sentry/sentry.gdextension'
DESCRIPTOR_BLOB = '47f4eb1723d5a61e706ce1fc078f9f68d6defa33'
LIBRARIES = {
    'linux.debug.x86_64': ('res://addons/sentry/bin/linux/x86_64/libsentry.linux.debug.x86_64.so',
                         '7fcf9f2401ef93ad4e0defec0c263718207cc81d'),
    'linux.release.x86_64': ('res://addons/sentry/bin/linux/x86_64/libsentry.linux.release.x86_64.so',
                           'fa6cf1af59a9fb4cbb8bf8a7b2e10179ab7bec82')}
INERT_PATH = 'res://inputs/fit-handler.txt'
INERT_BYTES = b'DD1-FIT-HARMLESS-MODE-STANDIN\n'
# Exact harmless fixture build, never a caller-chosen executable.
INERT_BINARY = 'cec3475556f7ac929a699b0ce28e52848c917cf1707d0b61c2fdf9129af75c7f'


def blob(raw):
    return hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest()


def selected(unit):
    return unit.get('runtime_fit') is not None


def limit(unit):
    value = r.natural(unit.get('linux', {}).get('threads'), 'lifetime thread limit')
    r.need(1 <= value <= (MAX_THREADS if selected(unit) else 4), 'runtime-fit thread ceiling')
    if selected(unit):
        p = unit['runtime_fit']
        r.need(isinstance(p, dict) and p.get('id') == PROFILE and
               unit.get('mode') in ('engineering', 'inert_control') and
               unit.get('stage') in ('identity', 'preparation', 'parse', 'fixture') and
               isinstance(unit.get('compatibility'), dict), 'missing/invalid selected runtime-fit profile')
    else:
        r.need('execution_modes' not in unit and 'mode_projection' not in unit,
               'unselected mode projection')
    return value


def host_facts():
    """Non-engine, point-of-use facts, bound by H for native use."""
    return dict(system=platform.system(), release=platform.release(), machine=platform.machine(),
                libc=list(platform.libc_ver()), pointer_bytes=struct.calcsize('P'),
                long_bytes=struct.calcsize('l'), cpu_count=os.cpu_count(),
                affinity=sorted(os.sched_getaffinity(0)),
                boot_id=Path('/proc/sys/kernel/random/boot_id').read_text().strip())


def projection(unit, source):
    if not selected(unit):
        return None
    claimed = unit.get('mode_projection')
    r.need(isinstance(claimed, dict), 'missing mode projection')
    inert = unit['mode'] == 'inert_control'
    path = INERT_PATH if inert else HANDLER
    wanted = blob(INERT_BYTES) if inert else HANDLER_BLOB
    raw = source.get(path)
    r.need(isinstance(raw, bytes) and blob(raw) == wanted, 'missing/changed exact mode dependency')
    dependencies = {}
    feature = 'INERT_ONLY' if inert else claimed.get('feature')
    if not inert:
        r.need(feature in LIBRARIES, 'unsupported Sentry library feature branch')
        library, library_blob = LIBRARIES[feature]
        for name, expected in ((DESCRIPTOR, DESCRIPTOR_BLOB), (library, library_blob)):
            b = source.get(name)
            r.need(isinstance(b, bytes) and blob(b) == expected, 'missing/changed Sentry branch dependency')
            dependencies[name] = dict(git_blob=expected, sha256=r.digest(b))
        # The fixed descriptor and fixed path must agree, not merely basenames.
        r.need((feature + ' = "' + library + '"').encode() in source[DESCRIPTOR] and
               HANDLER.encode() in source[DESCRIPTOR], 'Sentry descriptor branch')
    expected = dict(id='DD1-FIT-MODE-1', role='INERT_ONLY' if inert else 'SENTRY_HANDLER',
                    path=path, mode=0o555, git_blob=wanted, sha256=r.digest(raw),
                    feature=feature, dependencies=dependencies,
                    engine_source=ENGINE_SOURCE, sentry_source=None if inert else SENTRY_SOURCE)
    r.need(r.encode(claimed) == r.encode(expected), 'wrong exact mode/path/role binding')
    return expected


def mode_map(names, projected, recipe=None):
    """Actual visible source modes. Seed backing is writable but remains noexec."""
    result = {n: 0o400 for n in names}
    if projected:
        r.need(projected['path'] in result, 'projected mode dependency absent')
        result[projected['path']] = 0o555
    for slot in (recipe or {}).get('slots', []):
        name = 'res://' + slot['path']
        if 'seed' in slot:
            r.need(name in result and name != (projected or {}).get('path'), 'mode/seed collision')
            result[name] = 0o600
    return result


def describe(unit, projected, host):
    """Canonical shape only, never an authentication or a native disposition."""
    b = unit['linux']
    return dict(id=PROFILE, owner_selection=SELECTION, operation='DD1-LINUX-ENTRY-1',
                source_head=unit['overlay_head'], stage=unit['stage'],
                executable_sha256=b['runtime'][unit['argv'][0]]['sha256'],
                helper_sha256=b['helper']['sha256'],
                source_manifest_sha256=r.digest(r.encode(unit['source_files'])),
                runtime_sha256=r.digest(r.encode(b['runtime'])), argv_sha256=r.digest(r.encode(unit['argv'])),
                execution_files_sha256=r.digest(r.encode(unit.get('execution_files'))),
                execution_modes_sha256=r.digest(r.encode(unit.get('execution_modes'))),
                projection_sha256=r.digest(r.encode(projected)), host=host,
                lifetime_threads=b['threads'], implementation_maximum=MAX_THREADS,
                refusal_records=REFUSAL_RECORDS, attribution='CAPABILITY_CLASS_ONLY')


def validate(unit, source, files):
    n = limit(unit)
    if not selected(unit):
        return {}, None
    proj = projection(unit, source)
    names = {'res://' + p[len('/source/'):] for p in files if p.startswith('/source/')}
    modes = mode_map(names, proj, unit.get('preparation'))
    r.need(r.encode(unit.get('execution_modes')) == r.encode(modes), 'wrong complete execution mode map')
    r.need(r.encode(unit['runtime_fit']) == r.encode(describe(unit, proj, host_facts())),
           'runtime-fit exact stage/source/helper/host binding')
    r.need(2*n + 2 <= REFUSAL_RECORDS - 2, 'runtime-fit storage mismatch')
    if unit['mode'] == 'inert_control':
        r.need(unit['runtime_fit']['executable_sha256'] == INERT_BINARY, 'wrong pinned runtime-fit fixture')
    else:
        from dd1_compatibility import ENGINE
        r.need(unit['runtime_fit']['executable_sha256'] == ENGINE, 'runtime-fit fixed engine')
    # Private lower copies, before seed-slot mounts, have their immutable modes.
    private = {p: (0o500 if executable else 0o400) for p, (_, executable) in files.items()}
    private['/source/' + proj['path'][6:]] = 0o555
    return private, proj


def seal_fields(unit, combined):
    if not selected(unit):
        return {}
    proj = unit['mode_projection']
    return dict(runtime_fit_parent=unit['runtime_fit'], mode_projection=proj,
                execution_modes=mode_map(combined, proj),
                runtime_fit_parent_sha256=r.digest(r.encode(unit['runtime_fit'])))


def verify_seal(unit, receipt, payload, source):
    keys = {'runtime_fit_parent', 'runtime_fit_parent_sha256', 'mode_projection', 'execution_modes'}
    present = keys & receipt.keys()
    has = bool(present)
    r.need((not present or present == keys) and has == selected(unit), 'missing/spliced runtime-fit mode lineage')
    if not has:
        return
    p = receipt['runtime_fit_parent']
    r.need(isinstance(p, dict) and p.get('id') == PROFILE and p.get('stage') == 'preparation' and
           p.get('source_head') == unit['overlay_head'] and
           receipt.get('runtime_fit_parent_sha256') == r.digest(r.encode(p)), 'runtime-fit parent profile splice')
    proj = projection(unit, source)
    modes = mode_map(receipt['files'], proj)
    r.need(r.encode(receipt.get('mode_projection')) == r.encode(proj) and
           p.get('projection_sha256') == r.digest(r.encode(proj)) and
           r.encode(receipt.get('execution_modes')) == r.encode(modes) and
           r.encode(unit.get('execution_modes')) == r.encode(modes), 'sealed mode projection splice')
    for name, mode in modes.items():
        r.need(stat.S_IMODE((payload / name[6:]).stat().st_mode) == mode,
               'same-byte sealed mode substitution:' + name)


def native_bindings(unit, expected, context):
    """Called only after real H.verify_bindings, never constructs host authority."""
    if not selected(unit):
        return
    from dd1_compatibility import bound_role
    r.need(context.kind == 'empirical', 'runtime-fit rejects synthetic native authority')
    for name, value in (('runtime_fit_profile', unit['runtime_fit']),
                        ('runtime_fit_modes', unit['execution_modes']),
                        ('runtime_fit_projection', unit['mode_projection'])):
        bound_role(expected, context, name, r.encode(value))
    role = expected['roles'].get('runtime_fit_disposition', {})
    raw = context.resolve(role.get('locator'))
    r.need(isinstance(raw, bytes) and r.digest(raw) == role.get('sha256'), 'missing runtime-fit disposition')
    d = json.loads(raw)
    issuer = expected.get('receipt_authorities', {}).get('runtime_fit_disposition', {})
    authority = issuer.get('authority')
    r.need(isinstance(authority, str) and authority and not authority.startswith('synthetic:') and
           issuer.get('sha256') == r.digest(raw) and d.get('authority') == authority and
           context.receipts.get('runtime_fit_disposition') == raw, 'unauthenticated runtime-fit issuer')
    r.need(d.get('schema') == 'DD1-RUNTIME-FIT-DISPOSITION-1' and d.get('owner_selection') == SELECTION and
           d.get('operation') == 'DD1-LINUX-ENTRY-1' and d.get('source_head') == unit['overlay_head'] and
           d.get('stage') == unit['stage'] and d.get('profile_sha256') == r.digest(r.encode(unit['runtime_fit'])) and
           d.get('independent_review') == 'APPROVE' and d.get('planner_acceptance') == 'ACCEPTED' and
           d.get('launch_admitted') is True, 'unadmitted runtime-fit stage')
    role = expected['roles'].get('runtime_fit_thread_bound', {})
    bound = context.resolve(role.get('locator'))
    r.need(isinstance(bound, bytes) and r.digest(bound) == role.get('sha256') == d.get('thread_bound_sha256'),
           'missing authenticated stage thread bound')
    proof = json.loads(bound)
    r.need(proof.get('profile_sha256') == d['profile_sha256'] and proof.get('complete_creation_site_closure') is True and
           proof.get('engine_source') == ENGINE_SOURCE and proof.get('host') == unit['runtime_fit']['host'] and
           isinstance(proof.get('build_provenance'), dict) and bool(proof['build_provenance']) and
           isinstance(proof.get('sites'), list) and 0 < len(proof['sites']) <= 64,
           'unqualified stage/build/host thread closure')
    total, seen = 1, set()
    for site in proof['sites']:
        r.need(isinstance(site, dict) and isinstance(site.get('id'), str) and site['id'] and
               site['id'] not in seen and isinstance(site.get('source_witness'), str) and site['source_witness'],
               'invalid/duplicate thread creation site')
        seen.add(site['id']); total += r.natural(site.get('lifetime_births'), 'site lifetime births')
    r.need(total == r.natural(proof.get('total_including_main'), 'total lifetime births') and total <= limit(unit), 'stage thread upper exceeds bound')
    # This issuer attests byte/build/features and full writer sites. No output or
    # inotify label from a harmless fixture supplies such native provenance.
    r.need(proof.get('mode_projection_sha256') == unit['runtime_fit']['projection_sha256'] and
           proof.get('sentry_source') == SENTRY_SOURCE, 'missing mode/build provenance')
