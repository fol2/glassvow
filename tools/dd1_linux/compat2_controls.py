#!/usr/bin/env python3
"""COMPAT-2 connected harmless controls. No engine or real account is accepted.

Each workload goes through _run_inert_unit -> Prepared -> reserve_and_run and
its fixed supervisor, in a fresh single-thread controller. No OS mocks, supplied
runner or test clock. The parent only constructs explicit SYNTHETIC fixtures.
"""
from pathlib import Path
import argparse
import ctypes
import hashlib
import json
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
import dd1_reservations as r
import dd1_linux_snapshot as snap
import dd1_compatibility as compat

HEAD = '8efbea0a4bf0a2e9fcf9dfcc9606816011925fa8'
SAVE = b'COMPAT2\n'


def account():
    return dict(schema='DD1-N0-RECOVERY-1-ACCOUNT-1', synthetic=True,
        historical=dict(starts_used=1277, starts_cap=8192, starts_remaining_arithmetic=6915,
            spendable=False, attempt='1/1 consumed', cpu_seconds='UNKNOWN', elapsed_seconds='UNKNOWN', raw_bytes='UNKNOWN'),
        recovery=dict(id=r.OPERATION, starts_used=2040, starts_cap=r.STARTS_CAP,
            cpu_ns_used=398617197992, cpu_ns_cap=r.CPU_CAP, raw_bytes_used=893139, raw_bytes_cap=r.RAW_CAP,
            executors=1, per_invocation_cpu_seconds=300, first_engine_launch_utc=r.FIRST,
            deadline_utc=r.DEADLINE, events=[]))


def profile(unit):
    b=unit['linux']
    return dict(id=compat.PROFILE, operation='DD1-LINUX-ENTRY-1', stage=unit['stage'],
        source_head=unit['overlay_head'], executable_sha256=b['runtime']['/workload']['sha256'], libc_sha256=compat.LIBC,
        helper_sha256=b['helper']['sha256'], source_manifest_sha256=r.digest(r.encode(unit['source_files'])),
        runtime_sha256=r.digest(r.encode(b['runtime'])), argv_sha256=r.digest(r.encode(unit['argv'])),
        environment_sha256=r.digest(r.encode(compat.ENVIRONMENT)), process_signature=compat.PROCESS,
        naming_option=15, naming_per_thread=1, naming_total=b['threads'], clone3_maximum=b['threads']+1,
        attribution='CAPABILITY_CLASS_ONLY', task_sha256=r.digest(r.encode(unit['task'])),
        preparation_sha256=r.digest(r.encode(unit.get('preparation'))), sealed_input_sha256=r.digest(r.encode(unit.get('sealed_input'))))


def stage_sources(where):
    repo=where/'source';repo.mkdir()
    names=snap.HELPER_SOURCES|{'res://tools/dd1_linux/compat2_inert.c'}
    for name in names:
        p=repo/name[6:];p.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/name[6:],p)
    (repo/'inputs').mkdir();(repo/'inputs/frozen.txt').write_bytes(b'FROZEN-INERT\n')
    build=repo/'tools/dd1_linux/build';build.mkdir()
    for name in ('supervisor','compat2-inert','libc.so.6','ld-linux-x86-64.so.2'):
        shutil.copyfile(ROOT/'tools/dd1_linux/build'/name,build/name)
    return repo


def make_unit(where, mode='combined', *, cpu=16, prof=True, stage='identity', repo=None, existing_account=None):
    repo=repo or stage_sources(where)
    ap=where/'synthetic-account.json'
    ap.write_bytes(r.encode(existing_account or account()))
    unit=dict(schema='DD1-COMPLETE-UNIT-DEMAND-2',operation=r.OPERATION,scientific_m=r.M,
        overlay_head=HEAD,account_sha256=r.digest(ap.read_bytes()),unit_id=where.name,
        mode='inert_control',stage=stage,argv=['/workload',mode],contained_starts=0,cpu_seconds=cpu,wall_seconds=15,
        raw_bytes=8*2**20,source_files={name:r.digest((repo/name[6:]).read_bytes()) for name in
            sorted(snap.HELPER_SOURCES|{'res://tools/dd1_linux/compat2_inert.c','res://inputs/frozen.txt'})},
        task=dict(kind='exact-files',stage=stage,files={'save.bin':{'bytes':len(SAVE),'sha256':r.digest(SAVE)}}))
    runtime={}
    for dest,name,executable in [('/workload','compat2-inert',True),('/lib/x86_64-linux-gnu/libc.so.6','libc.so.6',False),
        ('/lib64/ld-linux-x86-64.so.2','ld-linux-x86-64.so.2',True)]:
        p='tools/dd1_linux/build/'+name
        runtime[dest]=dict(path=p,sha256=r.digest((repo/p).read_bytes()),executable=executable)
    unit['linux']=dict(abi=snap.ABI,entry='/workload',runtime=runtime,
        helper=dict(path='tools/dd1_linux/build/supervisor',sha256=snap.PINNED_HELPER_SHA256),
        environment=compat.ENVIRONMENT,threads=4,workload_raw_bytes=131072,output_root=str(where/'output'))
    if prof: unit['compatibility']=profile(unit)
    save_inputs(where,unit)
    return unit,repo


def save_inputs(where,unit):
    unit.pop('receipt_sha256',None)
    receipt=dict(schema='DD1-INERT-ONLY',demand_sha256=r.digest(r.encode(unit)))
    raw=r.encode(receipt);(where/'receipt.json').write_bytes(raw)
    unit['receipt_sha256']=r.digest(raw);(where/'unit.json').write_bytes(r.encode(unit))


def controller(where,repo,ap=None):
    import dd1_meter_entry as entry
    unit=r.read(where/'unit.json')
    ap=ap or where/'synthetic-account.json'
    # A synthetic marker is mandatory even before entering the test-only API.
    r.need(r.read(ap).get('synthetic') is True, 'not a synthetic control')
    try:
        result=entry._run_inert_unit(unit['argv'],unit=unit,account_path=ap,
            receipt_path=where/'receipt.json',output=Path(unit['linux']['output_root']),head=HEAD,repo=repo)
        print(json.dumps(result,sort_keys=True))
        return 0
    except Exception as e:
        print(json.dumps({'pre_release_error':type(e).__name__+':'+str(e)}))
        return 2


def controller_command(where,repo,ap=None):
    return [sys.executable,'-I','-B','-S',str(Path(__file__).resolve()),'--head',HEAD,'--controller',str(where),'--repo',str(repo), *(['--account',str(ap)] if ap else [])]

def run_one(where,repo,ap=None):
    ap=ap or where/'synthetic-account.json'
    cmd=controller_command(where, repo,ap)
    before=ap.read_bytes()
    p=subprocess.run(cmd,capture_output=True,text=True,timeout=25)
    record=dict(account_before_hex=before.hex(),argv=cmd,exit=p.returncode,stdout=p.stdout,stderr=p.stderr,
        account=r.read(ap),unit=r.read(where/'unit.json'),receipt=r.read(where/'receipt.json'))
    if p.stdout:
        try:record['result']=json.loads(p.stdout)
        except ValueError:pass
    record['files']={}
    out=where/'output'
    if out.exists():
        for name in ('UNIT-GRANT.json','UNIT-RESULT.json','capture/stdout.bin','capture/stderr.bin','capture/save.bin'):
            q=out/name
            if q.is_file():record['files'][name]=q.read_bytes().hex()
    record['frozen_after_hex']=(repo/'inputs/frozen.txt').read_bytes().hex()
    return record


def main():
    global HEAD
    a=argparse.ArgumentParser();a.add_argument('--head',default=HEAD);a.add_argument('--controller',type=Path);a.add_argument('--repo',type=Path)
    a.add_argument('--account',type=Path)
    a.add_argument('--first',action='store_true');a.add_argument('--output',type=Path)
    args=a.parse_args();HEAD=args.head
    if args.controller:return controller(args.controller,args.repo,args.account)
    where=Path(tempfile.mkdtemp(prefix='dd1-compat2-'))
    unit,repo=make_unit(where)
    record=run_one(where,repo)
    args.output.write_text(json.dumps(record,indent=2)+'\n')
    print(json.dumps({'directory':str(where),'exit':record['exit'],'success':record.get('result',{}).get('success'),'classification':record.get('result',{}).get('classification'),'error':record.get('result',{}).get('pre_release_error')},indent=2))
    assert record['exit']==0 and record['result']['success'], 'connected positive did not reach endpoint'
    assert record['result']['compatibility_verdict'] and not record['result']['strict_verdict']
    assert bytes.fromhex(record['files']['capture/save.bin'])==SAVE
    return 0

if __name__=='__main__':sys.exit(main())
