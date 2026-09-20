#!/usr/bin/env python3
"""Real DD1-PREP-1 controls: pinned harmless C, synthetic accounts, no engine.

The producer goes through _run_inert_unit -> snapshot/Prepared -> the actual
reserve_and_run/backend. No syscall/runner/clock mocks or native authority.
"""
import argparse
from copy import deepcopy
import ctypes
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE)); sys.path.insert(0, str(ROOT / 'tools'))
import compat2_controls as c
import dd1_reservations as r
import dd1_linux_snapshot as snap
import dd1_prep_view as view
import dd1_import_semantics as sem

SAVE = b'PREP1\n'
ASSET = b'ASSET-INERT\n'
RESOURCE = b'DD1-INERT-RESOURCE:quality=7:ASSET-INERT\n'
SEED = (b'[remap]\nimporter="dd1_inert"\ntype="Resource"\nuid="uid://dd1seed"\n'
        b'path="res://.godot/imported/probe.resource"\n\n[deps]\n'
        b'source_file="res://assets/probe.bin"\n'
        b'dest_files=["res://.godot/imported/probe.resource"]\n\n[params]\nquality=7\n')
SIDECAR = 'res://assets/probe.bin.import'
PRODUCER_SOURCE = 'res://tools/dd1_linux/prep_inert.c'
HEAD = ''


def check(value, reason):
    if not value:
        raise AssertionError(reason)


def stage(where):
    repo = where / 'source'; repo.mkdir()
    for name in snap.HELPER_SOURCES | {PRODUCER_SOURCE}:
        dest = repo / name[6:]; dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / name[6:], dest)
    shutil.copyfile(ROOT / 'project.godot', repo / 'project.godot')
    (repo / 'inputs').mkdir(); (repo / 'inputs/frozen.txt').write_bytes(b'FROZEN-INERT\n')
    (repo / 'assets').mkdir(); (repo / 'assets/probe.bin').write_bytes(ASSET)
    (repo / 'assets/probe.bin.import').write_bytes(SEED)
    build = repo / 'tools/dd1_linux/build'; build.mkdir()
    for name in ('supervisor', 'prep-inert', 'libc.so.6', 'ld-linux-x86-64.so.2'):
        shutil.copyfile(HERE / 'build' / name, build / name)
    return repo


def bind(unit, repo):
    recipe = unit.get('preparation')
    if recipe:
        source = {n: (repo/n[6:]).read_bytes() for n in unit['source_files']}
        recipe['view'] = view.describe(source)
        recipe['producer'] = view.producer_contract(unit, recipe)
        unit['execution_files'] = dict(recipe['view']['execution_files'])
    elif unit.get('sealed_input'):
        receipt = r.read(Path(unit['sealed_input']['receipt_path']))
        unit['execution_files'] = {n: x['sha256'] for n,x in receipt['files'].items()}
    profile(unit)


def profile(unit):
    unit['compatibility'] = c.profile(unit)
    if 'execution_files' in unit:
        unit['compatibility']['execution_files_sha256'] = r.digest(r.encode(unit['execution_files']))


def make(where, mode='positive', repo=None, account=None):
    repo = repo or stage(where)
    ap = where / 'account.json'; ap.write_bytes(r.encode(account or c.account()))
    names = snap.HELPER_SOURCES | {PRODUCER_SOURCE, 'res://project.godot',
        'res://inputs/frozen.txt', 'res://assets/probe.bin', SIDECAR}
    source = {n: (repo/n[6:]).read_bytes() for n in sorted(names)}
    runtime = {}
    for dest, name, executable in (('/workload', 'prep-inert', True),
            ('/lib/x86_64-linux-gnu/libc.so.6', 'libc.so.6', False),
            ('/lib64/ld-linux-x86-64.so.2', 'ld-linux-x86-64.so.2', True)):
        p = 'tools/dd1_linux/build/' + name
        runtime[dest] = dict(path=p, sha256=r.digest((repo/p).read_bytes()), executable=executable)
    unit = dict(schema='DD1-COMPLETE-UNIT-DEMAND-2', operation=r.OPERATION, scientific_m=r.M,
        overlay_head=HEAD, account_sha256=r.digest(ap.read_bytes()), unit_id=where.name,
        mode='inert_control', stage='preparation', argv=['/workload', mode], contained_starts=0,
        cpu_seconds=16, wall_seconds=15, raw_bytes=12*2**20,
        source_files={n: r.digest(b) for n,b in source.items()},
        task=dict(kind='exact-files', stage='preparation', files={'save.bin':dict(bytes=len(SAVE),sha256=r.digest(SAVE))}),
        linux=dict(abi=snap.ABI, entry='/workload', runtime=runtime,
            helper=dict(path='tools/dd1_linux/build/supervisor',sha256=snap.PINNED_HELPER_SHA256),
            environment=dict(c.compat.ENVIRONMENT),threads=4,workload_raw_bytes=262144,
            output_root=str(where/'output')))
    unit['preparation'] = dict(schema=view.SCHEMA,source_head=HEAD,
        source_manifest_sha256=r.digest(r.encode(unit['source_files'])),engine_sha256=view.INERT_PRODUCER,
        slots=[dict(path='.godot',kind='directory',files={'imported/probe.resource':dict(min_bytes=len(RESOURCE),max_bytes=len(RESOURCE))}),
               dict(path='assets/probe.bin.import',kind='file',files={'':dict(min_bytes=1,max_bytes=4096)},
                    seed=dict(git_blob=sem.blob(SEED),sha256=r.digest(SEED),asset='res://assets/probe.bin',asset_sha256=r.digest(ASSET)))])
    bind(unit, repo)
    return unit, repo, ap


def save_inputs(where, unit):
    c.save_inputs(where, unit)


def command(where, repo, ap):
    return [sys.executable, '-I', '-B', '-S', str(Path(__file__).resolve()), '--head', HEAD,
            '--controller', str(where), '--repo', str(repo), '--account', str(ap)]


def controller(where, repo, ap):
    import dd1_meter_entry as entry
    unit = r.read(where/'unit.json')
    try:
        check(r.read(ap).get('synthetic') is True, 'test account must be synthetic')
        result = entry._run_inert_unit(unit['argv'], unit=unit, account_path=ap,
            receipt_path=where/'receipt.json', output=where/'output', head=HEAD, repo=repo)
        print(json.dumps(result)); return 0
    except Exception as exc:
        print(json.dumps(dict(pre_release_error=type(exc).__name__+':'+str(exc)))); return 2


class Matrix:
    def __init__(self, dest):
        dest.mkdir(parents=True, exist_ok=False)
        self.dest, self.results = dest, []
        self.root = Path(tempfile.mkdtemp(prefix='dd1-prep1-'))
        check(ctypes.CDLL(None).prctl(36,1,0,0,0)==0, 'parent subreaper')

    def case(self, name, mode='positive', **kw):
        where = self.root/name; where.mkdir()
        return (where, *make(where, mode, **kw))

    def retain(self, name, record):
        (self.dest/(name+'.json')).write_bytes(r.encode(record))

    def passed(self, name):
        self.results.append(name)
        (self.dest/'INDEX.json').write_bytes(r.encode(dict(passed=self.results)))
        print('PASS '+name, flush=True)

    def run(self, name, where, unit, repo, ap, success, reason=None):
        save_inputs(where, unit); before = ap.read_bytes()
        p = subprocess.run(command(where,repo,ap),capture_output=True,text=True,timeout=25)
        record = dict(argv=p.args,exit=p.returncode,stdout=p.stdout,stderr=p.stderr,
            account_before_hex=before.hex(),account=r.read(ap),unit=unit,receipt=r.read(where/'receipt.json'))
        if p.stdout:
            try: record['result']=json.loads(p.stdout)
            except ValueError: pass
        record['files']={}
        for base in ('capture','derived','sealed'):
            for f in (where/'output'/base).rglob('*'):
                if f.is_file() and not f.is_symlink():
                    record['files'][str(f.relative_to(where/'output'))] = f.read_bytes().hex()
        for n in ('UNIT-GRANT.json','UNIT-RESULT.json','PREPARATION-MUTATIONS.bin'):
            f=where/'output'/n
            if f.is_file():record['files'][n]=f.read_bytes().hex()
        self.retain(name,record)
        if reason is not None:
            check(p.returncode==2 and reason in record.get('result',{}).get('pre_release_error',''), name+': wrong pre-release guard')
            check(ap.read_bytes()==before and not (where/'output').exists(),name+': pre-release effect')
        else:
            z=record.get('result',{})
            check(p.returncode==0 and z.get('success') is success,name+': unexpected backend outcome')
            check(z.get('cleanup_confirmed') is True,name+': cleanup')
            row=record['account']['recovery']['unit_reservations_v2'][-1]
            check(row['starts']==1 and row['cpu_ns']==unit['cpu_seconds']*10**9 and row['raw_bytes']==unit['raw_bytes'],name+': charged envelope')
            check(row['state']==('COMPLETE' if success else 'FAILED'),name+': state')
            check(all(not Path('/proc',str(x['pid'])).exists() for x in row['processes'].values()),name+': surviving process')
            check(bool(z.get('sealed_preparation'))==(success and unit['stage']=='preparation'),name+': invalid promotion')
        check((repo/'project.godot').read_bytes()==(ROOT/'project.godot').read_bytes(),name+': original config mutated')
        check((repo/'assets/probe.bin.import').read_bytes()==SEED,name+': archived seed mutated')
        check((repo/'assets/probe.bin').read_bytes()==ASSET,name+': original asset mutated')
        self.passed(name); return record

    def positive(self):
        where,u,repo,ap=self.case('positive')
        rec=self.run('positive',where,u,repo,ap,True)
        z=rec['result'];check(z['preparation_audit']['seed_history']['ok'],'seed history')
        seal=z['sealed_preparation'];raw=Path(seal['receipt_path']).read_bytes();sr=json.loads(raw)
        check(sr['execution_view']['original_project_sha256']==sr['execution_view']['runtime_project_sha256'] and
              sr['execution_view']['preparation_project_sha256']!=sr['execution_view']['runtime_project_sha256'],'projection identities')
        check(bytes.fromhex(rec['files']['sealed/payload/project.godot'])==(ROOT/'project.godot').read_bytes(),'runtime restoration')
        (where/'output/derived/0/imported/probe.resource').write_bytes(b'UNAPPROVED MUTABLE WORKSPACE')
        (where/'output/derived/1').write_bytes(b'WRONG UID/OPTIONS')
        w,v,_,a=self.case('sealed-runtime','runtime',repo=repo,account=r.read(ap))
        v.pop('preparation');v.update(stage='fixture',sealed_input={k:seal[k] for k in ('unit_id','receipt_path','sha256')})
        v['task']['stage']='fixture';bind(v,repo)
        self.run('sealed-runtime',w,v,repo,a,True)
        return where,u,repo,ap,seal

    def negatives(self):
        for mode in ('wrong-uid','wrong-param','wrong-source','invalid','malformed','incomplete',
                     'missing-resource','undeclared','alias','hardlink','source-mutation','config-mutation',
                     'never-read','double-write','mutate-restore','failed'):
            w,u,repo,ap=self.case(mode,mode)
            rec=self.run(mode,w,u,repo,ap,False);z=rec['result']
            if mode in ('never-read','double-write','mutate-restore'):
                check(not z['preparation_audit']['seed_history']['ok'],mode+': did not reach history guard')
            if mode in ('wrong-uid','wrong-param','wrong-source'):
                check(any('drift' in s for s in z['task_outcome']['errors']),mode+': did not reach semantics')
            if mode in ('alias','hardlink'):
                nr=88 if mode=='alias' else 86
                check(any(e['nr']==nr and e['errno']==95 for e in z['refused_requests']),mode+': alias effect not refused')

    def bindings(self):
        cases=[('seed-sha',lambda u:u['preparation']['slots'][1]['seed'].update(sha256='0'*64),'wrong tracked sidecar seed'),
            ('seed-blob',lambda u:u['preparation']['slots'][1]['seed'].update(git_blob='0'*40),'wrong tracked sidecar seed'),
            ('asset-sha',lambda u:u['preparation']['slots'][1]['seed'].update(asset_sha256='0'*64),'seed asset identity'),
            ('seed-path',lambda u:u['preparation']['slots'][1].update(path='inputs/frozen.txt'),'not a generated import/UID/cache slot'),
            ('traversal',lambda u:u['preparation']['slots'][1].update(path='../probe.import'),'invalid generated path'),
            ('engine',lambda u:u['preparation'].update(engine_sha256='0'*64),'preparation engine lineage'),
            ('recipe-head',lambda u:u['preparation'].update(source_head='0'*40),'preparation source lineage'),
            ('undeclared-dependency',lambda u:u['preparation']['slots'][0].update(files={'other.resource':dict(min_bytes=1,max_bytes=99)}),'outside declared generated inventory')]
        for name,change,error in cases:
            w,u,repo,ap=self.case('binding-'+name);change(u);bind(u,repo)
            self.run('binding-'+name,w,u,repo,ap,False,error)
        for name,change,error in (
            ('execution-view',lambda u:u['preparation']['view']['execution_files'].update({'res://project.godot':'0'*64}),'view binding'),
            ('producer',lambda u:u['preparation']['producer'].update(argv_sha256='0'*64),'producer/recipe binding'),
            ('execution-map',lambda u:u['execution_files'].update({'res://project.godot':'0'*64}),'bound preparation execution view'),
            ('unpriced-copies',lambda u:u.update(raw_bytes=4*2**20),'raw')):
            w,u,repo,ap=self.case('binding-'+name);change(u);profile(u)
            self.run('binding-'+name,w,u,repo,ap,False,error)

    def sealed_negatives(self,where,unit,repo,ap,seal):
        target=Path(seal['receipt_path']).parent/'payload/assets/probe.bin.import'
        original=target.read_bytes()
        for name,mutate,error in (
            ('sidecar-corrupt',lambda:target.write_bytes(b'X'*len(original)),'sealed snapshot corruption'),
            ('sidecar-symlink',lambda:(target.unlink(),target.symlink_to('/etc/passwd')),'derived symlink'),
            ('sidecar-missing',lambda:target.unlink(),'sealed snapshot inventory changed')):
            target.parent.chmod(0o700);target.chmod(0o600);mutate()
            w,u,_,a=self.case('sealed-'+name,'runtime',repo=repo,account=r.read(ap))
            u.pop('preparation');u.update(stage='fixture',sealed_input={k:seal[k] for k in ('unit_id','receipt_path','sha256')});u['task']['stage']='fixture';bind(u,repo)
            self.run('sealed-'+name,w,u,repo,a,False,error)
            if target.exists() or target.is_symlink():target.unlink()
            target.write_bytes(original);target.chmod(0o400);target.parent.chmod(0o500)

    def projection_negatives(self, where, unit, repo, ap, seal):
        # Corrupt only disposable HOST copies, after producer cleanup. No native
        # authority is created and the next public inert entry must not reserve.
        payload = Path(seal['receipt_path']).parent
        for name, rel, reason in (
            ('original-seed', 'originals/assets/probe.bin.import', 'sealed original archive corruption'),
            ('runtime-config', 'payload/project.godot', 'sealed snapshot corruption'),
            ('seal-bytes', 'SEAL.json', 'sealed receipt changed')):
            target = payload / rel; original = target.read_bytes()
            target.chmod(0o600); target.write_bytes(b'X' * len(original))
            w,u,_,a = self.case('sealed-'+name, 'runtime', repo=repo, account=r.read(ap))
            u.pop('preparation'); u.update(stage='fixture', sealed_input={k:seal[k] for k in ('unit_id','receipt_path','sha256')})
            u['task']['stage']='fixture'
            # Bind the *actual intended* execution inventory, not tampered seal
            # metadata. No JSON parse of the corrupt file occurs in the driver.
            good = json.loads(original) if name=='seal-bytes' else r.read(Path(seal['receipt_path']))
            u['execution_files']={n:x['sha256'] for n,x in good['files'].items()}; profile(u)
            self.run('sealed-'+name,w,u,repo,a,False,reason)
            target.write_bytes(original); target.chmod(0o400)
        for name, change, reason in (
            ('failed-parent', lambda u,a:a['recovery']['unit_reservations_v2'][0].update(state='FAILED'), 'missing/failed preparation reservation'),
            ('spliced-receipt', lambda u,a:u['sealed_input'].update(sha256='0'*64), 'unbound preparation receipt'),
            ('wrong-engine', lambda u,a:u['linux']['runtime']['/workload'].update(sha256='0'*64), 'sealed engine/source/demand lineage'),
            ('wrong-runtime-view', lambda u,a:u['execution_files'].update({'res://project.godot':'0'*64}), 'wrong bound sealed execution view')):
            w,u,_,a=self.case('sealed-'+name,'runtime',repo=repo,account=r.read(ap))
            u.pop('preparation');u.update(stage='fixture',sealed_input={k:seal[k] for k in ('unit_id','receipt_path','sha256')})
            u['task']['stage']='fixture';bind(u,repo)
            account=r.read(a);change(u,account);a.write_bytes(r.encode(account))
            u['account_sha256']=r.digest(a.read_bytes());profile(u)
            self.run('sealed-'+name,w,u,repo,a,False,reason)
        # Same prepared unit cannot spend or run twice even when all other
        # mutable demand fields are correctly re-bound to the current account.
        unit['account_sha256']=r.digest(ap.read_bytes());bind(unit,repo)
        # The output already exists; capture it in the record, but assertion is
        # specifically the duplicate reservation guard (not output reuse).
        save_inputs(where,unit);before=ap.read_bytes()
        p=subprocess.run(command(where,repo,ap),capture_output=True,text=True,timeout=25)
        self.retain('replay',dict(argv=p.args,exit=p.returncode,stdout=p.stdout,stderr=p.stderr,
            account_before_hex=before.hex(),account=r.read(ap)))
        check(p.returncode==2 and 'unit already reserved' in p.stdout and ap.read_bytes()==before,'replay charged/released')
        self.passed('replay')

    def killed(self,who):
        w,u,repo,ap=self.case('kill-'+who,'block');save_inputs(w,u)
        p=subprocess.Popen(command(w,repo,ap),stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
        try:
            end=time.monotonic()+8
            while time.monotonic()<end:
                ledger=r.read(ap);rows=ledger['recovery'].get('unit_reservations_v2',[])
                stream=w/'output/capture/stdout.bin'
                if rows and 'processes' in rows[0] and stream.exists() and b'SAVE_READBACK_OK' in stream.read_bytes():break
                check(p.poll() is None,'kill point not reached');time.sleep(.01)
            else:raise AssertionError('kill timeout')
            ids=rows[0]['processes']
            other,v,_,a=self.case('concurrent-'+who,repo=repo,account=ledger)
            self.run('concurrent-'+who,other,v,repo,ap,False,'one executor already holds account')
            os.kill(ids[who]['pid'],signal.SIGKILL);stdout,stderr=p.communicate(timeout=8)
            end=time.monotonic()+3;adopted=[]
            while time.monotonic()<end:
                try:pid,status,usage=os.wait4(-1,os.WNOHANG)
                except ChildProcessError:break
                if pid:adopted.append(dict(pid=pid,status=status))
                else:time.sleep(.01)
            final=r.read(ap);check(all(not Path('/proc',str(i['pid'])).exists() for i in ids.values()),'kill cleanup')
            check(not (w/'output/sealed').exists() and final['recovery']['unit_reservations_v2'][0]['starts']==1,'kill promotion/refund')
            self.retain('kill-'+who,dict(before_kill=ledger,after=final,killed=ids[who],exit=p.returncode,
                stdout=stdout,stderr=stderr,adopted=adopted,remaining_pids=[]))
            self.passed('kill-'+who)
        finally:
            if p.poll() is None:p.kill();p.communicate(timeout=5)


def main():
    global HEAD
    p=argparse.ArgumentParser();p.add_argument('--head',required=True);p.add_argument('--output',type=Path)
    p.add_argument('--controller',type=Path);p.add_argument('--repo',type=Path);p.add_argument('--account',type=Path)
    p.add_argument('--section',choices=('all','positive','negative','binding','kill'),default='all')
    args=p.parse_args();HEAD=args.head;c.HEAD=HEAD
    if args.controller:return controller(args.controller,args.repo,args.account)
    m=Matrix(args.output)
    try:
        if args.section in ('all','positive'):
            positive=m.positive()
            if args.section=='all':
                m.sealed_negatives(*positive);m.projection_negatives(*positive)
        if args.section in ('all','negative'):m.negatives()
        if args.section in ('all','binding'):m.bindings()
        if args.section in ('all','kill'):m.killed('controller');m.killed('supervisor')
    except BaseException as exc:
        m.retain('FAILURE',dict(error=type(exc).__name__+':'+str(exc),root=str(m.root)))
        raise
    m.retain('SUMMARY',dict(assertion_groups=len(m.results),head=HEAD,complete=True,
        engine_runs=0,live_account_writes=0,synthetic_only=True,root=str(m.root)))
    return 0

if __name__=='__main__':sys.exit(main())
