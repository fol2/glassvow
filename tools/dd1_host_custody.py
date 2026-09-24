"""Read-only custody inspection; never creates, locks, adopts or repairs a ledger.

The designated live GitHub registration selects ONE existing custodian. Local
flock remains the existing reservation engine's job and is not cross-host proof.
"""
from __future__ import annotations

import os
from pathlib import Path
import platform
import stat
import struct
from dd1_host_channel import BridgeError, canonical, decode, need, sha

REGISTRATION_COMMENT = 5813829774
RECOVERY_REL = "research/p9-six-route/dusk-design-1-20260916/native-qualification/recovery"
ACCOUNT_REL = RECOVERY_REL + "/ACCOUNT.json"
RECEIPT_REL = RECOVERY_REL + "/LAUNCH-RECEIPT.json"
DEADLINE = "2026-09-24T17:54:40Z"


def host_facts():
    return dict(system=platform.system(), release=platform.release(), machine=platform.machine(),
                libc=list(platform.libc_ver()), pointer_bytes=struct.calcsize('P'),
                long_bytes=struct.calcsize('l'), cpu_count=os.cpu_count(),
                affinity=sorted(os.sched_getaffinity(0)),
                boot_id=Path('/proc/sys/kernel/random/boot_id').read_text().strip())


def read_existing(path, maximum=8 * 1024 * 1024):
    """Descriptor-relative, no symlinks/hardlinks; no O_CREAT and no writes."""
    path = Path(path)
    need(path.is_absolute() and str(path) == str(path.absolute()) and '..' not in path.parts,
         "absolute canonical existing path required")
    parent = os.open('/', os.O_PATH | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        for part in path.parts[1:-1]:
            fd = os.open(part, os.O_PATH | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=parent)
            os.close(parent); parent = fd
        fd = os.open(path.name, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC | os.O_NONBLOCK, dir_fd=parent)
        with os.fdopen(fd, 'rb') as stream:
            before = os.fstat(stream.fileno())
            need(stat.S_ISREG(before.st_mode) and before.st_nlink == 1 and before.st_size <= maximum,
                 'nonregular, linked or oversized custody input')
            raw = stream.read(maximum + 1)
            after = os.fstat(stream.fileno())
        current = os.stat(path.name, dir_fd=parent, follow_symlinks=False)
        signature = lambda s: (s.st_dev, s.st_ino, s.st_size, s.st_mtime_ns, s.st_ctime_ns)
        need(signature(before) == signature(after) == signature(current) and len(raw) == before.st_size,
             'custody input changed during read')
        identity = dict(device=before.st_dev, inode=before.st_ino, uid=before.st_uid,
                        mode=stat.S_IMODE(before.st_mode), bytes=len(raw), sha256=sha(raw))
        return raw, identity
    finally:
        os.close(parent)


def observe(root):
    """Describe the named existing ledger, NOT a claim of authoritative custody."""
    root = Path(root).absolute()
    report = dict(account_path=str(root / ACCOUNT_REL), lease_path=str(root / (ACCOUNT_REL + '.lock')),
                  authoritative=False, account=None, history_sha256=None, generation=None,
                  pending=[], errors=[], lease_status='NOT_INSPECTED', writes=0, locks_acquired=0)
    try:
        raw, identity = read_existing(root / ACCOUNT_REL)
        account = decode(raw)
        need(isinstance(account, dict), 'account object required')
        recovery = account.get('recovery', {})
        need(isinstance(recovery, dict), 'recovery object required')
        units = recovery.get('unit_reservations_v2', [])
        need(isinstance(units, list) and all(isinstance(x, dict) for x in units), 'invalid reservation history')
        report.update(account=identity, generation=sha(raw),
                      history_sha256=sha(canonical({'events': recovery.get('events'), 'units': units})),
                      synthetic=account.get('synthetic') is True)
        for row in units:
            if row.get('state') == 'RESERVED' or (row.get('backend') == 'linux-x86_64-lp64-v1' and
                    (row.get('observations') or {}).get('cleanup_confirmed') is not True):
                report['pending'].append(row.get('unit_id'))
        lease = root / (ACCOUNT_REL + '.lock')
        try:
            s = lease.lstat()
            report['lease_status'] = 'EXISTS_NOT_LOCK_TESTED'
            need(stat.S_ISREG(s.st_mode) and s.st_nlink == 1, 'linked/nonregular lease')
        except FileNotFoundError:
            report['lease_status'] = 'ABSENT_NOT_CREATED'
    except (OSError, BridgeError) as exc:
        report['errors'].append(type(exc).__name__ + ':' + str(exc))
    return report


def reasons(registry, observation, host, root, head, unit):
    """Pure checks of supplied observations; authentication belongs to channel."""
    out = []
    def check(ok, reason):
        if not ok:
            out.append(reason)
    check(registry.get('schema') == 'DD1-HOST-CUSTODY-REGISTRATION-1', 'custody schema')
    check(registry.get('repository') == 'fol2/glassvow' and
          registry.get('operation') == 'DD1-LINUX-ENTRY-1', 'custody repository/operation')
    check(registry.get('status') == 'REGISTERED' and registry.get('scope') == 'ENGINEERING_ONLY',
          'custodian not registered for engineering')
    check(registry.get('artifact_head') == head, 'custody exact head')
    check(registry.get('deadline_utc') == DEADLINE, 'custody cannot extend window')
    check(registry.get('account_relative_path') == ACCOUNT_REL and
          registry.get('lease_relative_path') == ACCOUNT_REL + '.lock', 'custody path policy')
    executor = registry.get('executor_identity') or {}
    expected = dict(host=host, uid=os.geteuid(), root=str(Path(root).absolute()))
    check(executor == expected, 'different or unknown owning executor')
    check(not observation['errors'] and observation.get('account') is not None, 'existing account unavailable')
    identity = observation.get('account') or {}
    check(identity.get('uid') == os.geteuid() and type(identity.get('mode')) is int and
          identity['mode'] & 0o022 == 0, 'ledger owner or writable-by-others mode')
    check(observation.get('synthetic') is False, 'synthetic ledger is not live custody')
    check(registry.get('live_account_identity') is not None and
          registry.get('live_account_identity') == observation.get('account'), 'custody inode/byte identity')
    check(registry.get('current_generation') is not None and
          registry.get('current_generation') == observation.get('generation') == unit.get('account_sha256'),
          'stale ledger generation or replay')
    check(registry.get('reservation_history_sha256') is not None and
          registry.get('reservation_history_sha256') == observation.get('history_sha256'), 'stale reservation history')
    check(not observation.get('pending'), 'unreconciled prior reservation')
    # A new executor cannot treat a local unlocked file as a custody transfer.
    check(registry.get('custody_mode') == 'EXISTING_SAME_EXECUTOR' and
          registry.get('previous_executor_identity') == expected, 'custody transfer/restart not established')
    check(registry.get('original_custodian_confirmation') is not None, 'original custodian confirmation missing')
    return out
