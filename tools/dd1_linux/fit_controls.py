#!/usr/bin/env python3
"""Real connected FIT controls. No native issuer, mock backend or engine."""
import argparse
from copy import deepcopy
import ctypes
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import dd1_reservations as r
import dd1_linux_snapshot as snap
import dd1_compatibility as compat
import dd1_prep_view as view
import dd1_import_semantics as sem
import dd1_runtime_fit as fit

SEED = (b'[remap]\nimporter="dd1_inert"\ntype="Resource"\nuid="uid://dd1seed"\n'
        b'path="res://.godot/imported/probe.resource"\n\n[deps]\n'
        b'source_file="res://assets/probe.bin"\n'
        b'dest_files=["res://.godot/imported/probe.resource"]\n\n[params]\nquality=7\n')
RESOURCE = b'DD1-INERT-RESOURCE:quality=7:ASSET-INERT\n'
ASSET = b'ASSET-INERT\n'
HEAD = ''


def check(value, reason):
    if not value:
        raise AssertionError(reason)


def account():
    return dict(schema='DD1-N0-RECOVERY-1-ACCOUNT-1', synthetic=True,
        historical=dict(starts_used=1277, starts_cap=8192, starts_remaining_arithmetic=6915,
            spendable=False, attempt='1/1 consumed', cpu_seconds='UNKNOWN', elapsed_seconds='UNKNOWN', raw_bytes='UNKNOWN'),
        recovery=dict(id=r.OPERATION, starts_used=2040, starts_cap=r.STARTS_CAP,
            cpu_ns_used=398617197992, cpu_ns_cap=r.CPU_CAP, raw_bytes_used=893139, raw_bytes_cap=r.RAW_CAP,
            executors=1, per_invocation_cpu_seconds=300, first_engine_launch_utc=r.FIRST, deadline_utc=r.DEADLINE))


def profile(u):
    b=u['linux']
    p=dict(id=compat.PROFILE, operation='DD1-LINUX-ENTRY-1', stage=u['stage'],
        source_head=u['overlay_head'], executable_sha256=fit.INERT_BINARY, libc_sha256=compat.LIBC,
        helper_sha256=b['helper']['sha256'],source_manifest_sha256=r.digest(r.encode(u['source_files'])),
        runtime_sha256=r.digest(r.encode(b['runtime'])),argv_sha256=r.digest(r.encode(u['argv'])),
        environment_sha256=r.digest(r.encode(compat.ENVIRONMENT)),process_signature=compat.PROCESS,
        naming_option=15,naming_per_thread=1,naming_total=b['threads'],clone3_maximum=b['threads']+1,
        attribution='CAPABILITY_CLASS_ONLY',task_sha256=r.digest(r.encode(u['task'])),
        preparation_sha256=r.digest(r.encode(u.get('preparation'))),sealed_input_sha256=r.digest(r.encode(u.get('sealed_input'))),
        execution_files_sha256=r.digest(r.encode(u['execution_files'])))
    if fit.selected(u):
        p.update(runtime_fit_sha256=r.digest(r.encode(u['runtime_fit'])),
                 execution_modes_sha256=r.digest(r.encode(u['execution_modes'])))
    u['compatibility']=p


def bind(u, repo):
    if u.get('preparation'):
        raw={n:(repo/n[6:]).read_bytes() for n in u['source_files']}
        u['preparation']['view']=view.describe(raw)
        u['preparation']['producer']=view.producer_contract(u,u['preparation'])
        u['execution_files']=dict(u['preparation']['view']['execution_files'])
    elif u.get('sealed_input'):
        seal=r.read(Path(u['sealed_input']['receipt_path']))
        u['execution_files']={n:d['sha256'] for n,d in seal['files'].items()}
    else:
        u['execution_files']=dict(u['source_files'])
    p=dict(id='DD1-FIT-MODE-1',role='INERT_ONLY',path=fit.INERT_PATH,mode=0o555,
           git_blob=fit.blob(fit.INERT_BYTES),sha256=r.digest(fit.INERT_BYTES),feature='INERT_ONLY',
           dependencies={},engine_source=fit.ENGINE_SOURCE,sentry_source=None)
    u['mode_projection']=p
    u['execution_modes']=fit.mode_map(u['execution_files'],p,u.get('preparation'))
    u['runtime_fit']=fit.describe(u,p,fit.host_facts())
    profile(u)


def make(where, mode='sequential', threads=6, births=None, stage='identity', repo=None, ap=None):
    where.mkdir(parents=True,exist_ok=False)
    if repo is None:
        repo=where/'source';repo.mkdir()
        for name in snap.HELPER_SOURCES|{'res://tools/dd1_linux/fit_inert.c','res://project.godot'}:
            dest=repo/name[6:];dest.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(ROOT/name[6:],dest)
        for n,raw in [('inputs/fit-handler.txt',fit.INERT_BYTES),('assets/probe.bin',ASSET),('assets/probe.bin.import',SEED)]:
            p=repo/n;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(raw)
        for n in ('supervisor','fit-inert','libc.so.6','ld-linux-x86-64.so.2'):
            p=repo/'tools/dd1_linux/build'/n;p.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(HERE/'build'/n,p)
    if ap is None:
        ap=where/'account.json';ap.write_bytes(r.encode(account()))
    sources={n:r.digest((repo/n[6:]).read_bytes()) for n in sorted(snap.HELPER_SOURCES|{
        'res://tools/dd1_linux/fit_inert.c','res://project.godot',fit.INERT_PATH,'res://assets/probe.bin','res://assets/probe.bin.import'})}
    runtime={dest:dict(path='tools/dd1_linux/build/'+n,sha256=r.digest((HERE/'build'/n).read_bytes()),executable=ex)
        for dest,n,ex in [('/workload','fit-inert',True),('/lib/x86_64-linux-gnu/libc.so.6','libc.so.6',False),('/lib64/ld-linux-x86-64.so.2','ld-linux-x86-64.so.2',True)]}
    u=dict(schema='DD1-COMPLETE-UNIT-DEMAND-2',operation=r.OPERATION,scientific_m=r.M,overlay_head=HEAD,
        account_sha256=r.digest(ap.read_bytes()),unit_id=where.name,mode='inert_control',stage=stage,
        argv=['/workload',mode,str(threads-1 if births is None else births),stage],contained_starts=0,
        cpu_seconds=16,wall_seconds=12,raw_bytes=12*2**20,source_files=sources,
        task=dict(kind='exact-files',stage=stage,files={'save.bin':dict(bytes=5,sha256=r.digest(b'FIT1\n'))}),
        linux=dict(abi=snap.ABI,entry='/workload',runtime=runtime,
            helper=dict(path='tools/dd1_linux/build/supervisor',sha256=snap.PINNED_HELPER_SHA256),
            environment=dict(compat.ENVIRONMENT),threads=threads,workload_raw_bytes=262144,output_root=str(where/'output')))
    if stage=='preparation':
        u['preparation']=dict(schema=view.SCHEMA,source_head=HEAD,source_manifest_sha256=r.digest(r.encode(sources)),
            engine_sha256=fit.INERT_BINARY,slots=[
                dict(path='.godot',kind='directory',files={'imported/probe.resource':dict(min_bytes=len(RESOURCE),max_bytes=len(RESOURCE))}),
                dict(path='assets/probe.bin.import',kind='file',files={'':dict(min_bytes=1,max_bytes=4096)},
                     seed=dict(git_blob=sem.blob(SEED),sha256=r.digest(SEED),asset='res://assets/probe.bin',asset_sha256=r.digest(ASSET)))])
    bind(u,repo);return u,repo,ap


def save(where,u):
    unsigned=dict(u);unsigned.pop('receipt_sha256',None)
    receipt=dict(schema='DD1-INERT-ONLY',demand_sha256=r.digest(r.encode(unsigned)))
    u['receipt_sha256']=r.digest(r.encode(receipt))
    (where/'unit.json').write_bytes(r.encode(u));(where/'receipt.json').write_bytes(r.encode(receipt))


def command(where,repo,ap):
    return [sys.executable,'-I','-B','-S',str(Path(__file__).resolve()),'--head',HEAD,'--controller',str(where),'--repo',str(repo),'--account',str(ap)]


def controller(where,repo,ap):
    import dd1_meter_entry as entry
    try:
        u=r.read(where/'unit.json')
        z=entry._run_inert_unit(u['argv'],unit=u,account_path=ap,receipt_path=where/'receipt.json',
            output=where/'output',head=HEAD,repo=repo)
        print(json.dumps(z));return 0
    except Exception as e:
        print(json.dumps({'pre_release_error':type(e).__name__+':'+str(e)}));return 2


class Matrix:
    def __init__(self, dest):
        self.dest=dest;dest.mkdir(parents=True,exist_ok=False)
        self.root=dest/'cases';self.root.mkdir();self.results=[]
        check(ctypes.CDLL(None).prctl(36,1,0,0,0)==0,'subreaper')

    def collect(self,where,u,repo,ap,before,p):
        files={};modes={}
        for prefix in ('capture','derived','sealed'):
            for f in (where/'output'/prefix).rglob('*'):
                if f.is_file() and not f.is_symlink():
                    n=str(f.relative_to(where/'output'));files[n]=f.read_bytes().hex();modes[n]=f.stat().st_mode&0o7777
        for n in ('UNIT-GRANT.json','UNIT-RESULT.json','PREPARATION-MUTATIONS.bin'):
            f=where/'output'/n
            if f.is_file():files[n]=f.read_bytes().hex()
        z=json.loads(p.stdout) if p.stdout else {}
        record=dict(argv=p.args,exit=p.returncode,stdout=p.stdout,stderr=p.stderr,unit=u,receipt=r.read(where/'receipt.json'),
                    account_before_hex=before.hex(),account=r.read(ap),files=files,file_modes=modes,result=z,
                    original_inputs={n:dict(sha256=r.digest((repo/n[6:]).read_bytes()),mode=(repo/n[6:]).stat().st_mode&0o7777) for n in u['source_files']})
        (self.dest/(where.name+'.json')).write_bytes(r.encode(record));return record

    def run(self,name,case,success=None,reason=None):
        u,repo,ap=case;where=self.root/name;save(where,u);before=ap.read_bytes()
        p=subprocess.run(command(where,repo,ap),capture_output=True,text=True,timeout=25)
        rec=self.collect(where,u,repo,ap,before,p);z=rec['result']
        check(p.stderr=='',name+': controller stderr')
        if reason:
            check(p.returncode==2 and reason in z.get('pre_release_error',''),name+': wrong guard '+str(z))
            check(before==ap.read_bytes() and not (where/'output').exists(),name+': pre-release effect')
        else:
            check(p.returncode==0 and z.get('success') is success,name+': outcome '+str(z.get('task_outcome',z)))
            check(z['cleanup_confirmed'] is True,name+': cleanup')
            row=rec['account']['recovery']['unit_reservations_v2'][-1]
            check(row['starts']==1 and row['cpu_ns']==16*10**9 and row['raw_bytes']==u['raw_bytes'],name+': charge')
            check(row['state']==('COMPLETE' if success else 'FAILED'),name+': ledger state')
            identities=list(row['processes'].values())
            check(all(not Path('/proc',str(d['pid'])).exists() for d in identities),name+': surviving process')
            rec['postcheck']=dict(observed_utc=datetime.now(timezone.utc).isoformat(),identities=identities,all_absent=True)
            check(z['runtime_fit_sha256']==r.digest(r.encode(u['runtime_fit'])),name+': result profile')
            if success:
                report=z['supervisor_report'];check(report['thread_limit']==u['linux']['threads'] and report['profile_mode']==2,name+': helper limit')
                check(bytes.fromhex(rec['files']['capture/save.bin'])==b'FIT1\n',name+': atomic save')
                check(b'MODE:0555 owner=1 group=1 other=1' in bytes.fromhex(rec['files']['capture/stdout.bin']),name+': modes')
            (self.dest/(name+'.json')).write_bytes(r.encode(rec))
        check(all(d['sha256']==u['source_files'][n] for n,d in rec['original_inputs'].items()),name+': original mutation')
        self.results.append(name);(self.dest/'INDEX.json').write_bytes(r.encode(dict(passed=self.results)))
        print('PASS '+name,flush=True);return rec

    def case(self,name,**kw):return make(self.root/name,**kw)

    def positive(self):
        case=self.case('preparation',stage='preparation');rec=self.run('preparation',case,True)
        u,repo,ap=case;seal=rec['result']['sealed_preparation'];check(seal,'missing seal')
        (self.root/'preparation/output/derived/0/imported/probe.resource').write_bytes(b'MUTABLE-CHANGED')
        h=self.root/'preparation/output/private-root/source/inputs/fit-handler.txt';h.chmod(0o400)
        # Change only the OLD disposable copy, never the sealed or original input.
        c=self.case('sealed-runtime',stage='identity',repo=repo,ap=ap);v,_,_=c
        v.update(stage='fixture',sealed_input={k:seal[k] for k in ('unit_id','receipt_path','sha256')})
        v['argv'][-1]='fixture';v['task']['stage']='fixture';bind(v,repo)
        self.run('sealed-runtime',c,True)
        for name,kw in [('concurrent',dict(mode='concurrent')),('boundary',dict(threads=14)),('memory',dict(mode='memory'))]:
            self.run(name,self.case(name,**kw),True)

    def kernel(self):
        for name,kw in [('next-birth',dict(threads=14,births=14)),('race',dict(mode='race',threads=4)),
            ('chmod',dict(mode='chmod')),('exec',dict(mode='exec')),('process',dict(mode='process')),
            ('socket',dict(mode='socket')),('raw',dict(mode='raw')),('cpu',dict(mode='cpu'))]:
            self.run(name,self.case(name,**kw),False)

    def guards(self):
        cases=[('missing-profile',lambda u:u.pop('runtime_fit'),'thread ceiling'),
            ('wrong-profile',lambda u:u['runtime_fit'].update(id='wrong'),'selected runtime-fit'),
            ('fractional',lambda u:u['linux'].update(threads=5.5),'nonnegative integer'),
            ('negative',lambda u:u['linux'].update(threads=-1),'nonnegative integer'),
            ('boolean',lambda u:u['linux'].update(threads=True),'nonnegative integer'),
            ('overflow',lambda u:u['linux'].update(threads=2**64),'thread ceiling'),
            ('too-large',lambda u:u['linux'].update(threads=15),'thread ceiling'),
            ('stage',lambda u:u['runtime_fit'].update(stage='fixture'),'stage/source/helper/host'),
            ('source',lambda u:u['runtime_fit'].update(source_head='0'*40),'stage/source/helper/host'),
            ('helper',lambda u:u['runtime_fit'].update(helper_sha256='0'*64),'stage/source/helper/host'),
            ('storage',lambda u:u['runtime_fit'].update(refusal_records=33),'stage/source/helper/host'),
            ('mode500',lambda u:u['mode_projection'].update(mode=0o500),'mode/path/role'),
            ('mode-writable',lambda u:u['mode_projection'].update(mode=0o777),'mode/path/role'),
            ('mode-path',lambda u:u['mode_projection'].update(path='res://project.godot'),'mode/path/role'),
            ('mode-digest',lambda u:u['mode_projection'].update(sha256='0'*64),'mode/path/role'),
            ('mode-feature',lambda u:u['mode_projection'].update(feature='linux.debug.x86_64'),'mode/path/role'),
            ('mode-missing',lambda u:u.pop('mode_projection'),'missing mode projection'),
            ('mode-extra',lambda u:u['execution_modes'].update({'res://project.godot':0o555}),'execution mode map'),
            ('mode-setid',lambda u:u['execution_modes'].update({fit.INERT_PATH:0o4555}),'execution mode map'),
            ('naming',lambda u:u['compatibility'].update(naming_total=15),'finite refusal bounds'),
            ('clone3',lambda u:u['compatibility'].update(clone3_maximum=16),'finite refusal bounds')]
        for name,mutate,reason in cases:
            c=self.case(name);mutate(c[0]);self.run(name,c,reason=reason)

    def sealed(self):
        # Separate fresh connected parent needed for independently recoverable group.
        c=self.case('seal-parent',stage='preparation');rec=self.run('seal-parent',c,True)
        _,repo,ap=c;binding={k:rec['result']['sealed_preparation'][k] for k in ('unit_id','receipt_path','sha256')}
        sealpath=Path(binding['receipt_path']);sealraw=sealpath.read_bytes();seal=json.loads(sealraw)
        path=sealpath.parent/'payload/inputs/fit-handler.txt'
        for name,mode in [('same-byte500',0o500),('missing-owner-bit',0o455),('missing-group-bit',0o545),('missing-other-bit',0o554)]:
            v,rr,aa=self.case(name,repo=repo,ap=ap);v.update(stage='fixture',sealed_input=binding);v['argv'][-1]='fixture';v['task']['stage']='fixture';bind(v,rr)
            path.chmod(mode)
            try:self.run(name,(v,rr,aa),reason='same-byte sealed mode substitution')
            finally:path.chmod(0o555)
        for name,change in [('dropped-profile',lambda u:u.pop('runtime_fit')),
            ('spliced-projection',lambda u:u['mode_projection'].update(mode=0o500)),
            ('seal-replay',lambda u:u['sealed_input'].update(sha256='0'*64))]:
            v,rr,aa=self.case(name,repo=repo,ap=ap);v.update(stage='fixture',sealed_input=dict(binding));v['argv'][-1]='fixture';v['task']['stage']='fixture';bind(v,rr);change(v)
            reason={'dropped-profile':'mode lineage','spliced-projection':'mode/path/role','seal-replay':'unbound preparation receipt'}[name]
            self.run(name,(v,rr,aa),reason=reason)

    def crash(self):
        for target in ('controller','supervisor'):
            name='kill-'+target;c=self.case(name,mode='hold');u,repo,ap=c;where=self.root/name;save(where,u);before=ap.read_bytes()
            p=subprocess.Popen(command(where,repo,ap),stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
            end=time.monotonic()+6
            while time.monotonic()<end:
                marker=where/'output/capture/stdout.bin'
                if marker.exists() and b'HOLD_REACHED' in marker.read_bytes():break
                if p.poll() is not None:break
                time.sleep(.02)
            mid=r.read(ap);row=mid['recovery'].get('unit_reservations_v2',[])
            check(row and row[-1].get('processes') and p.poll() is None,'hold not reached')
            midraw=ap.read_bytes();identities=row[-1]['processes']
            n='concurrent-'+target;v,rr,aa=self.case(n,repo=repo,ap=ap)
            self.run(n,(v,rr,aa),reason='one executor already holds account')
            os.kill(identities[target]['pid'],signal.SIGKILL);out,err=p.communicate(timeout=5)
            p.args=command(where,repo,ap);p.stdout=out;p.stderr=err
            adopted=[]
            end=time.monotonic()+3
            while time.monotonic()<end:
                try:pid,status=os.waitpid(-1,os.WNOHANG)
                except ChildProcessError:break
                if pid:adopted.append(dict(pid=pid,status=status))
                else:time.sleep(.02)
            rec=self.collect(where,u,repo,ap,before,p)
            absent=all(not Path('/proc',str(d['pid'])).exists() for d in identities.values())
            rec.update(account_before_kill_hex=midraw.hex(),adopted=adopted,postcheck=dict(identities=identities,all_absent=absent,observed_utc=datetime.now(timezone.utc).isoformat()))
            (self.dest/(name+'.json')).write_bytes(r.encode(rec));check(absent,'kill cleanup')
            after=r.read(ap)['recovery']['unit_reservations_v2'][-1]
            check(after['starts']==1 and after['cpu_ns']==16*10**9 and after['raw_bytes']==u['raw_bytes'],'kill charge')
            check(after['state']==('RESERVED' if target=='controller' else 'FAILED'),'kill state')
            if target=='controller':check(ap.read_bytes()==midraw,'killed controller retained reservation')
            else:check(rec['result']['cleanup_confirmed'] and not rec['result']['success'],'supervisor kill outcome')
            self.results.append(name);print('PASS '+name,flush=True)


def main():
    global HEAD
    p=argparse.ArgumentParser();p.add_argument('--head',required=True);p.add_argument('--output',type=Path)
    p.add_argument('--section',choices=['positive','kernel','guards','sealed','crash']);p.add_argument('--controller',type=Path)
    p.add_argument('--repo',type=Path);p.add_argument('--account',type=Path);a=p.parse_args();HEAD=a.head
    if a.controller:return controller(a.controller,a.repo,a.account)
    check(a.output and a.section,'section/output required')
    m=Matrix(a.output);getattr(m,a.section)()
    (a.output/'SUMMARY.json').write_bytes(r.encode(dict(head=HEAD,section=a.section,passed=m.results,engine_runs=0,live_account_writes=0)))
    return 0
if __name__=='__main__':sys.exit(main())
