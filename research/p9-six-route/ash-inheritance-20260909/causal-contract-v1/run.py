"""Execute one locally frozen observation qualification, preserving actual failures.
Usage: python run.py BASE_REPOSITORY PINNED_ENGINE NEW_OUTPUT NEW_WORK
No remote publication is performed or claimed by this runner.
"""
from __future__ import annotations
import hashlib
import json
import lzma
import os
from pathlib import Path
import resource
import subprocess
import sys
import tarfile
import time
import assemble
import read

HERE = Path(__file__).resolve().parent


def save(path, data):
    Path(path).write_text(json.dumps(data, indent=2)+'\n')


def tree_hash(root):
    """Git tree identity including names, bytes and executable mode; no Git repo needed."""
    records=[]
    for p in root.iterdir():
        if p.is_dir():
            records.append((p.name+'/',b'40000 '+p.name.encode()+b'\0'+bytes.fromhex(tree_hash(p))))
        else:
            b=p.read_bytes()
            blob=hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).digest()
            mode=b'100755' if p.stat().st_mode & 0o111 else b'100644'
            records.append((p.name,mode+b' '+p.name.encode()+b'\0'+blob))
    b=b''.join(v for _,v in sorted(records,key=lambda r:r[0].encode()))
    return hashlib.sha1(b'tree '+str(len(b)).encode()+b'\0'+b).hexdigest()


def command(args, out, stem, cwd=None, timeout=180):
    started=time.monotonic();before=resource.getrusage(resource.RUSAGE_CHILDREN)
    env=dict(os.environ,GODOT_SILENCE_ROOT_WARNING='1',PYTHONDONTWRITEBYTECODE='1')
    with (out/(stem+'.stdout')).open('wb') as a, (out/(stem+'.stderr')).open('wb') as b:
        result=subprocess.run(list(map(str,args)),stdout=a,stderr=b,cwd=cwd,env=env,timeout=timeout)
    after=resource.getrusage(resource.RUSAGE_CHILDREN)
    logs=(out/(stem+'.stderr')).read_bytes()
    rec={'command':list(map(str,args)),'cwd':str(cwd) if cwd else None,'returncode':result.returncode,
         'elapsed_seconds':time.monotonic()-started,
         'cpu_user_seconds':after.ru_utime-before.ru_utime,'cpu_system_seconds':after.ru_stime-before.ru_stime,
         'stdout_sha256':assemble.sha((out/(stem+'.stdout')).read_bytes()),'stderr_sha256':assemble.sha(logs)}
    save(out/(stem+'.receipt.json'),rec)
    assemble.require(result.returncode==0,'PROCESS_FAILED:'+stem)
    assemble.require(b'SCRIPT ERROR' not in logs and b'ERROR:' not in logs and b'Failed to load script' not in logs,'NATIVE_DIAGNOSTIC:'+stem)
    return rec


def execute(base,engine,out,work):
    base,engine,out,work=map(lambda p:Path(p).resolve(),(base,engine,out,work))
    assemble.require(not out.exists() and not work.exists(),'OUTPUT_EXISTS_NO_BLIND_RERUN')
    out.mkdir(parents=True)
    terminal={'status':'INCONCLUSIVE','packages_admitted':0,'p9_certified':False,'remote_preserved':False}
    try:
        p=json.loads((HERE/'PROTOCOL.json').read_bytes());f=json.loads((HERE/'FREEZE.json').read_bytes())
        for n,h in f['source_sha256'].items():assemble.require(assemble.sha((HERE/n).read_bytes())==h,'FROZEN_SOURCE:'+n)
        assemble.require(assemble.sha(engine.read_bytes())==p['engine_sha256'],'PINNED_ENGINE')
        source_binding={}
        for name,expected in [('domain','0e83b4a319b0ea5bbfbc11bbc1762de596e6a5ac'),('content','fd13719acbd2eb2994fc53de6680bb58c0bd5ce1')]:
            actual=tree_hash(base/name);assemble.require(actual==expected,'MAIN_TREE_IDENTITY:'+name)
            source_binding[name]={'expected_current_main_tree':expected,'actual_tree':actual}
        save(out/'BASE-SOURCE-BINDING.json',source_binding)
        version=command([engine,'--version'],out,'engine',timeout=20)
        assemble.require((out/'engine.stdout').read_text().strip()=='4.7.2.stable.official.ed1daf0bf','ENGINE_VERSION')
        manifest=assemble.assemble(base,work)
        save(out/'RUNTIME-MANIFEST.json',manifest)
        with tarfile.open(out/'runtime-source.tar.xz','w:xz') as tf:
            for name in manifest:tf.add(work/name,arcname=name,recursive=False)
        terminal['local_source_commit']=subprocess.check_output(['git','rev-parse','HEAD'],cwd=HERE).decode().strip()
        command([sys.executable,'-m','unittest','-v','test_contract'],out,'tests',cwd=HERE,timeout=20)
        command([engine,'--headless','--path',work,'--import'],out,'import',timeout=90)
        command(['env','GODOT='+str(engine),'bash','tools/check_scripts.sh','causal_rules.gd','causal_probe.gd'],out,'parse',cwd=work,timeout=90)
        for source in p['sources']:
            target=out/(source+'.jsonl')
            command([engine,'--headless','--path',work,'-s','res://causal_probe.gd','--',source,target],out,'native-'+source,timeout=p['per_invocation_timeout_seconds'])
            raw=target.read_bytes();assemble.require(len(raw)<=p['raw_bytes_per_source_limit'],'RAW_LIMIT')
            (out/(source+'.jsonl.xz')).write_bytes(lzma.compress(raw))
            # The raw is losslessly preserved in the committed compressed stream.
            assemble.require(lzma.decompress((out/(source+'.jsonl.xz')).read_bytes())==raw,'LOSSLESS_ARCHIVE')
            target.unlink()
        result=read.read(out,f['source_sha256'])
        save(out/'RESULTS.json',result)
        terminal.update(status=result['status'],fixtures=result['fixtures'],sequence_records=result['sequence_records'],native_reference_pairs=result['native_reference_pairs'],new_independent_samples=0)
    except Exception as exc:
        terminal['failure']=repr(exc)
    finally:
        save(out/'TERMINAL.json',terminal)
        save(out/'FILES.json',[{'path':str(p.relative_to(out)),'bytes':p.stat().st_size,'sha256':assemble.sha(p.read_bytes())}
                              for p in sorted(out.rglob('*')) if p.is_file() and p.name!='FILES.json'])
        print(json.dumps(terminal,indent=2))
    return 0 if terminal['status']!='INCONCLUSIVE' else 3


if __name__=='__main__':raise SystemExit(execute(*sys.argv[1:]))
