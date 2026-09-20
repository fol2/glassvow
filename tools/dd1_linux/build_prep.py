#!/usr/bin/env python3
"""Build/reuse exact harmless PREP-1 tooling; never launches it or an engine."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import dd1_linux_snapshot as snapshot
import dd1_prep_view as view


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    out = HERE/'build'; out.mkdir(exist_ok=True)
    flags = ['cc','-std=c11','-O2','-Wall','-Wextra','-Werror']
    builds = [
        ('supervisor', snapshot.PINNED_HELPER_SHA256, flags+['-static']+
         [str(HERE/n) for n in ('supervisor.c','policy.c','isolate.c','capabilities.c')]),
        ('prep-inert', view.INERT_PRODUCER, flags+['-pthread',str(HERE/'prep_inert.c')])]
    records=[]
    for name,expected,command in builds:
        target=out/name
        if target.is_file() and sha(target)==expected:
            records.append(dict(name=name,reused=True,sha256=expected))
            continue
        command=command+['-o',str(target)]
        p=subprocess.run(command,capture_output=True,text=True,timeout=30)
        records.append(dict(argv=command,exit=p.returncode,stdout=p.stdout,stderr=p.stderr))
        if p.returncode:
            print(json.dumps(records,indent=2));return p.returncode
        if sha(target)!=expected:
            records[-1]['pin_mismatch']=sha(target)
            print(json.dumps(records,indent=2));return 2
    for name in ('/lib/x86_64-linux-gnu/libc.so.6','/lib64/ld-linux-x86-64.so.2'):
        src=Path(name).resolve();target=out/src.name
        same=target.is_file() and sha(src)==sha(target)
        if not same:shutil.copyfile(src,target)
        records.append(dict(source=str(src),destination=str(target),reused=same,
                            bytes=target.stat().st_size,sha256=sha(target)))
    print(json.dumps(dict(builds=records,engine_runs=0,helper_runs=0),indent=2))
    return 0

if __name__=='__main__':sys.exit(main())
