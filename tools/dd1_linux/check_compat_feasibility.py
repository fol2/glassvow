#!/usr/bin/env python3
"""Narrow real-libc feasibility tests, not a compatibility profile or native entry.

Uses the unchanged reservation transaction and byte-pinned strict supervisor.
All accounts are CREATED synthetic outside the repository. No supplied command,
account, runner, engine, H context, policy override or test clock is accepted.
The internal runner seam observes kernel refusal and no-refund behavior only;
it is NOT evidence that public native entry or expected-refusal attribution works.
"""
from __future__ import annotations
import argparse
import ctypes
import fcntl
import hashlib
import json
import os
from pathlib import Path
import platform
import resource
import shutil
import signal
import subprocess
import sys
import tempfile
import time

TOOLS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))
import dd1_reservations as r

HERE = Path(__file__).resolve().parent
HELPER_SHA = "dae7a481fd0d6c25f093c38056673a6039f98d899e816a65953537a54d00c7ce"
FIXTURE_SHA = "599e9b799b6674a8d78f37a9539082655a6ca7e3c0a38167babbc6ae3283ff5b"
LIBS = {
    "/lib64/ld-linux-x86-64.so.2": ("/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2", "438c546d8e8cc48496bf3a95f753051afd9db66a629a74e31a9ded71586b56e0"),
    "/lib/x86_64-linux-gnu/libc.so.6": ("/lib/x86_64-linux-gnu/libc.so.6", "fa430b8f298f817a266046af84a77533185ad6fc4406c7d3787b5a0a0c207826"),
}
MODES = ("io", "thread", "popen", "popen_twice", "other_spawn", "named", "popen_named", "kill")


def account() -> dict:
    return dict(schema="DD1-N0-RECOVERY-1-ACCOUNT-1", synthetic=True,
        historical=dict(attempt="1/1 consumed", starts_used=1277, starts_cap=8192,
            starts_remaining_arithmetic=6915, spendable=False, cpu_seconds="UNKNOWN",
            elapsed_seconds="UNKNOWN", raw_bytes="UNKNOWN"),
        recovery=dict(id=r.OPERATION, starts_used=2040, starts_cap=r.STARTS_CAP,
            cpu_ns_used=398617197992, cpu_ns_cap=r.CPU_CAP, raw_bytes_used=893139,
            raw_bytes_cap=r.RAW_CAP, executors=1, per_invocation_cpu_seconds=300,
            first_engine_launch_utc=r.FIRST, deadline_utc=r.DEADLINE,
            events=[dict(note="SYNTHETIC only; not read from a live account")]))


def checked_bytes(path: Path, sha: str) -> bytes:
    raw = path.read_bytes()
    r.need(r.digest(raw) == sha, "binary/runtime mismatch:" + str(path))
    return raw


def worker(mode: str, directory: Path, head: str) -> dict:
    r.need(platform.release() == "6.18.44" and platform.machine() == "x86_64", "unsupported host")
    r.need(directory.resolve() == directory and not directory.is_relative_to(TOOLS.parent), "synthetic account location")
    r.need(mode in MODES, "unknown control")
    r.need(len(list(Path('/proc/self/task').iterdir())) == 1, "fresh single-thread controller")
    resource.setrlimit(resource.RLIMIT_CPU, (3, 3))
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    r.need(ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0, "subreaper")
    signal.signal(signal.SIGALRM, lambda *_: os._exit(124))
    signal.setitimer(signal.ITIMER_REAL, 10)
    helper = checked_bytes(HERE / "build/supervisor", HELPER_SHA)
    payloads = {"/fixture": checked_bytes(HERE / "build/compat-feasibility", FIXTURE_SHA)}
    for dest, (source, sha) in LIBS.items():
        payloads[dest] = checked_bytes(Path(source), sha)
    source_paths = [HERE / "compat_feasibility.c", Path(__file__), TOOLS / "dd1_reservations.py"]
    sources = {"res://" + str(p.relative_to(TOOLS.parent)): p.read_bytes() for p in source_paths}
    path = directory / "SYNTHETIC-ACCOUNT.json"
    r.need(not path.exists(), "new synthetic account required")
    r.atomic_write(path, account())
    before = path.read_bytes()
    cmd = ["/fixture", "block" if mode == "kill" else mode]
    unit = dict(schema="DD1-COMPLETE-UNIT-DEMAND-2", operation=r.OPERATION, scientific_m=r.M,
        overlay_head=head, receipt_sha256=r.digest(b"SYNTHETIC feasibility receipt\n"),
        account_sha256=r.digest(before), argv=cmd, unit_id="inert-" + mode, mode="inert_control",
        contained_starts=0, cpu_seconds=11, wall_seconds=10, raw_bytes=8 * 1024 * 1024,
        source_files={name: r.digest(raw) for name, raw in sources.items()},
        linux=dict(abi="linux-x86_64-lp64-v1"), environment="INERT_ONLY")
    output = directory / "unit"
    observations: dict = {}
    def authority(a: dict) -> None:
        r.need(a.get("synthetic") is True and path.parent == directory, "synthetic-only test")
    def runner(grant: dict, out: Path) -> dict:
        stored = r.read(path)["recovery"]["unit_reservations_v2"][-1]
        r.need(stored["state"] == "RESERVED" and stored["starts"] == 1, "before-child reservation")
        observations["before_child"] = r.read(path)
        root, capture = out / "private-root", out / "capture"
        (root / "out").mkdir(parents=True)
        capture.mkdir()
        for name, raw in payloads.items():
            dest = root / name[1:]; dest.parent.mkdir(parents=True, exist_ok=True)
            with dest.open("xb") as f:
                f.write(raw); f.flush(); os.fsync(f.fileno())
            dest.chmod(0o500 if name in ("/fixture", "/lib64/ld-linux-x86-64.so.2") else 0o400)
            r.need(dest.read_bytes() == raw, "copy mismatch")
        r.atomic_write(root / "grant.json", grant)
        (root / "grant.json").chmod(0o400)
        r.need(sum(len(v) for v in payloads.values()) + len(helper) + 131072 + 524288 < grant["raw_bytes"], "test envelope")
        fd = os.memfd_create("dd1-strict-baseline", os.MFD_ALLOW_SEALING)
        view = memoryview(helper)
        while view:
            view = view[os.write(fd, view):]
        fcntl.fcntl(fd, fcntl.F_ADD_SEALS, fcntl.F_SEAL_WRITE | fcntl.F_SEAL_GROW | fcntl.F_SEAL_SHRINK | fcntl.F_SEAL_SEAL)
        lease = r._lease.get()
        args = ["dd1-supervisor", str(root), str(capture), "131072", "1", "5000", "4", str(os.getpid()), str(lease), *cmd]
        observations["helper_argv"] = args
        proc = subprocess.Popen(args, executable="/proc/self/fd/" + str(fd), pass_fds=(fd,lease),
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env={})
        try:
            first = proc.stdout.readline(512)
            start = json.loads(first)
            identities = dict(controller=r.process_identity(os.getpid()), supervisor=r.process_identity(proc.pid),
                workload=r.process_identity(start["workload"]))
            r.attach_processes(identities)
            observations["before_ack"] = r.read(path)
            if mode == "kill":
                proc.stdin.write(b"G"); proc.stdin.flush()
                until = time.monotonic() + 3
                while not (capture / "save.txt").exists() and time.monotonic() < until:
                    time.sleep(.01)
                r.need((capture / "save.txt").exists(), "kill guard not reached")
                os.kill(proc.pid, signal.SIGKILL)
                raw, err = proc.communicate(timeout=3)
            else:
                raw, err = proc.communicate(input=b"G", timeout=7)
        finally:
            if proc.poll() is None:
                proc.kill(); proc.wait(timeout=2)
            os.close(fd)
        raw = first + raw
        adopted = []
        while True:
            try:
                pid, status, usage = os.wait4(-1, 0)
                adopted.append(dict(pid=pid,status=status,cpu=usage.ru_utime+usage.ru_stime))
            except ChildProcessError:
                break
        r.need(len(raw) <= 4096 and len(err) <= 4096, "bounded strict diagnostics")
        result = next((json.loads(line) for line in raw.splitlines() if json.loads(line).get("phase") == "result"), {})
        gone = all(not Path('/proc',str(identities[k]['pid'])).exists() for k in ('supervisor','workload'))
        files = {str(p.relative_to(capture)): p.read_bytes().decode('utf-8') for p in capture.rglob('*') if p.is_file()}
        observations.update(helper_stdout=raw.decode(),helper_stderr=err.decode(),helper_exit=proc.returncode,
            supervisor_report=result,files=files,identities=identities,adopted=adopted,cleanup_confirmed=gone,
            descendant_marker_present=(capture/'descendant-marker').exists())
        return dict(success=result.get('success') is True and proc.returncode == 0 and gone,
            cleanup_confirmed=gone, strict_report=result, supervisor_exit=proc.returncode)
    result = r.reserve_and_run(path,unit,command=cmd,head=head,receipt_sha=unit['receipt_sha256'],
        source_reader=lambda name:sources[name],authority_check=authority,output=output,runner=runner)
    after = path.read_bytes()
    replay_error = None
    repeated = dict(unit, account_sha256=r.digest(after))
    try:
        r.reserve_and_run(path,repeated,command=cmd,head=head,receipt_sha=unit['receipt_sha256'],
            source_reader=lambda name:sources[name],authority_check=authority,output=directory/'second',runner=runner)
    except r.ReservationError as exc:
        replay_error = str(exc)
    r.need(replay_error == 'unit already reserved; no second spawn', 'replay did not reach identity guard')
    r.need(path.read_bytes()==after and r.totals(r.read(path))['starts']==2041, 'no refund or extra charge')
    signal.setitimer(signal.ITIMER_REAL,0)
    return dict(mode=mode,unit=unit,result=result,observations=observations,
        before=json.loads(before),after=json.loads(after),replay_error=replay_error,
        helper_sha256=HELPER_SHA,fixture_sha256=FIXTURE_SHA,engine_launches=0,live_account_writes=0)


def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--worker',choices=MODES)
    parser.add_argument('--directory',type=Path)
    parser.add_argument('--head',required=True)
    parser.add_argument('--report',type=Path)
    args=parser.parse_args()
    if args.worker:
        print(json.dumps(worker(args.worker,args.directory,args.head),sort_keys=True))
        return 0
    r.need(args.report is not None and not args.report.exists(), 'new report path')
    report = dict(scope='INERT FEASIBILITY; NOT COMPATIBILITY ACCEPTANCE',head=args.head,controls=[])
    for mode in MODES:
        with tempfile.TemporaryDirectory(prefix='dd1-compat-inert-') as tmp:
            cmd=[sys.executable,'-I','-B','-S',str(Path(__file__).resolve()),'--worker',mode,'--directory',tmp,'--head',args.head]
            done=subprocess.run(cmd,capture_output=True,text=True,timeout=14)
            row=dict(argv=cmd,exit=done.returncode,stdout=done.stdout,stderr=done.stderr)
            if done.returncode==0:
                row['record']=json.loads(done.stdout)
            report['controls'].append(row)
            args.report.write_text(json.dumps(report,indent=2)+'\n')
            print(mode,done.returncode,(row.get('record',{}).get('observations',{}).get('supervisor_report',{})),flush=True)
            if done.returncode:
                print(done.stderr,flush=True)
                return 1
            observed = row['record']['observations']
            actual = observed.get('supervisor_report', {})
            if mode != 'kill' and actual.get('execs') != 1:
                print('BLOCKED: workload did not reach intended control', flush=True)
                return 2
            if mode in ('io','thread') and actual.get('success') is not True:
                print('FAIL: matched positive did not succeed', flush=True)
                return 3
            if mode == 'kill' and ('files' not in observed or observed.get('cleanup_confirmed') is not True):
                print('BLOCKED: real kill/cleanup control not reached', flush=True)
                return 4
            expected = {'io':(0,-1,1),'thread':(0,-1,2),'popen':(1,56,1),
                'popen_twice':(2,56,1),'other_spawn':(1,56,1),'named':(1,157,2),'popen_named':(2,157,2)}
            checks = dict(cleanup=observed.get('cleanup_confirmed') is True,
                no_descendant_marker=observed.get('descendant_marker_present') is False,
                exact_save=observed.get('files',{}).get('save.txt')=='INERT byte-identical atomic save\n',
                full_charge=row['record']['after']['recovery']['unit_reservations_v2'][0]['starts']==1,
                replay_rejected=row['record']['replay_error']=='unit already reserved; no second spawn')
            if mode != 'kill':
                checks['matched_denials'] = (actual.get('denied'),actual.get('last_denied_syscall'),actual.get('thread_births_including_main'))==expected[mode]
                checks['real_workload_exit'] = actual.get('exit')==0 and actual.get('signal')==0
                checks['strict_verdict'] = actual.get('success')==(mode in ('io','thread'))
            else:
                checks['real_kill'] = observed.get('helper_exit') == -signal.SIGKILL
                checks['reaped_workload'] = any(os.WIFSIGNALED(x['status']) and os.WTERMSIG(x['status'])==signal.SIGKILL for x in observed.get('adopted',[]))
            row['checks']=checks
            args.report.write_text(json.dumps(report,indent=2)+'\n')
            if not all(checks.values()):
                print('FAIL: '+str(checks),flush=True)
                return 5
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
