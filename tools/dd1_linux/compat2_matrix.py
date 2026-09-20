#!/usr/bin/env python3
"""Connected COMPAT-2 controls; only code-pinned harmless programs/synthetic accounts.

No supplied engine, account, runner, syscall mock or clock. Every case retains
its raw records before assertions, including failed development attempts.
"""
import argparse
from copy import deepcopy
import ctypes
import json
import os
from pathlib import Path
import signal
import stat
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, str(Path(__file__).resolve().parent))
import compat2_controls as c
r = c.r


def check(value, message):
    if not value:
        raise AssertionError(message)


class Matrix:
    def __init__(self, destination):
        destination.mkdir(parents=True, exist_ok=False)
        self.destination = destination
        self.root = Path(tempfile.mkdtemp(prefix='dd1-c2-matrix-'))
        self.results = []
        check(ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0, 'test-parent subreaper')

    def case(self, name, mode='combined', **kwargs):
        where = self.root / name
        where.mkdir()
        unit, repo = c.make_unit(where, mode, **kwargs)
        return where, unit, repo

    def retain(self, name, record):
        record['control_name'] = name
        (self.destination / (name + '.json')).write_bytes(r.encode(record))

    def passed(self, name, claim):
        self.results.append(dict(name=name, claim=claim, assertions='PASS'))
        (self.destination/'INDEX.json').write_bytes(r.encode(self.results))
        print('PASS ' + name + ': ' + claim, flush=True)

    def run(self, name, where, unit, repo, success, *, ap=None, pre=None):
        c.save_inputs(where, unit)
        before = (ap or where/'synthetic-account.json').read_bytes()
        record = c.run_one(where, repo, ap)
        audit = where/'output/PREPARATION-MUTATIONS.bin'
        if audit.exists(): record['mutation_journal_hex'] = audit.read_bytes().hex()
        self.retain(name, record)
        if pre is not None:
            check(record['exit'] == 2, name + ': expected pre-release refusal')
            check(pre in record.get('result', {}).get('pre_release_error', ''), name + ': wrong refusal')
            check(r.encode(record['account']) == before, name + ': pre-release account mutated')
            check(not (where/'output').exists(), name + ': pre-release output created')
        else:
            check(record['exit'] == 0, name + ': controller/setup failure')
            result = record['result']
            check(result.get('success') is success, name + ': wrong outcome')
            check(result.get('cleanup_confirmed') is True, name + ': missing cleanup')
            row = record['account']['recovery']['unit_reservations_v2'][-1]
            check(row['starts'] == 1 and row['cpu_ns'] == unit['cpu_seconds']*10**9 and
                  row['raw_bytes'] == unit['raw_bytes'], name + ': charge mismatch')
            check(row['state'] == ('COMPLETE' if success else 'FAILED'), name + ': state')
            check(set(row['processes']) == {'controller','supervisor','workload'}, name + ': missing ACK identities')
            check(not (where/'output/capture/descendant-marker').exists(), name + ': child effect')
            for item in row['processes'].values():
                check(not Path('/proc',str(item['pid'])).exists(), name + ': live process remains')
        check(bytes.fromhex(record['frozen_after_hex']) == b'FROZEN-INERT\n', name + ': original changed')
        return record

    def kernel_cases(self):
        for name,mode,ok,nr in [
            ('combined','combined',True,None), ('strict-plain','plain',True,None),
            ('strict-unnamed','unnamed',True,None), ('strict-refusals','combined',False,56),
            ('capability-only','same-signature',True,None), ('four-thread-bound','max-threads',True,None),
            ('repeat-process','repeat-process',False,56), ('wrong-process','wrong-process',False,56),
            ('worker-process','worker-process',False,56), ('late-process','late-process',False,56),
            ('repeat-name','repeat-name',False,157), ('wrong-prctl','wrong-prctl',False,157),
            ('unknown-call','unknown-syscall',False,140), ('clone3-bound','clone3-excess',False,435),
            ('extra-thread','extra-thread',False,56), ('later-exec','later-exec',False,59),
            ('refusal-flood','refusal-flood',False,157), ('raw-bound','raw-exhaust',False,1),
            ('task-exit','task-fail',False,None), ('missing-save','missing-save',False,None)]:
            where,unit,repo=self.case(name,mode,prof=not name.startswith('strict-'))
            rec=self.run(name,where,unit,repo,ok)
            z=rec['result']; events=z['refused_requests']; cls=z['classification']
            if nr is not None:
                check(any(e['nr']==nr for e in events), name+': intended syscall not reached')
            if name in ('combined','capability-only'):
                check(z['compatibility_verdict'] and not z['strict_verdict'] and
                      cls['process_refusals']==1 and cls['naming_refusals']==1, name+': classification')
                check(all(e['attribution']=='CAPABILITY_CLASS_ONLY' for e in events), name+': false origin claim')
                check(bytes.fromhex(rec['files']['capture/save.bin'])==c.SAVE,name+': save/readback')
            if name=='four-thread-bound':
                check(cls['naming_refusals']==4 and z['supervisor_report']['thread_births_including_main']==4,'four identities')
            if name=='refusal-flood':check(cls['fatal']==1 and len(events)==32,'finite journal stop')
            if name=='raw-bound':check(z['supervisor_report']['reserved_before_writes']<=unit['linux']['workload_raw_bytes'],'raw cap')
            if name=='task-exit':check(not cls['task_exit_ok'],'caught error cannot hide task exit')
            if name=='missing-save':check(cls['compatibility_success'] and not z['task_outcome']['ok'],'task separate')
            self.passed(name, 'connected enforcement/task/cleanup and full retained reservation')

    def bindings(self):
        changes=[
            ('profile-id',lambda u,p:u['compatibility'].update(id='other'),'profile exact-invocation'),
            ('profile-signature',lambda u,p:u['compatibility']['process_signature'].update(flags=17),'profile exact-invocation'),
            ('argv',lambda u,p:u['argv'].__setitem__(1,'plain'),'profile exact-invocation'),
            ('stage',lambda u,p:u.update(stage='parse'),'profile exact-invocation'),
            ('environment',lambda u,p:u['linux']['environment'].update(HOME='/elsewhere'),'unbound/changed workload'),
            ('task-binding',lambda u,p:u['task']['files']['save.bin'].update(bytes=7),'profile exact-invocation'),
            ('helper',lambda u,p:u['linux']['helper'].update(sha256='0'*64),'helper must be pinned'),
            ('runtime-digest',lambda u,p:u['linux']['runtime']['/workload'].update(sha256='0'*64),'runtime identity'),
            ('source-digest',lambda u,p:u['source_files'].update({'res://inputs/frozen.txt':'0'*64}),'actual source bytes differ'),
            ('source-fifo',lambda u,p:((p/'inputs/frozen.txt').unlink(),os.mkfifo(p/'inputs/frozen.txt')),'nonregular/linked'),
        ]
        # Do not mutate global process/environment dictionaries shared by fixtures.
        for name,mutate,expected in changes:
            where,unit,repo=self.case('binding-'+name)
            unit=deepcopy(unit)
            mutate(unit,repo)
            if name=='source-fifo':
                # run_one reads frozen_after; use a different tracked source FIFO.
                (repo/'inputs/frozen.txt').unlink();(repo/'inputs/frozen.txt').write_bytes(b'FROZEN-INERT\n')
                q=repo/'inputs/pipe';os.mkfifo(q)
                unit['source_files']['res://inputs/pipe']='0'*64
            self.run('binding-'+name,where,unit,repo,False,pre=expected)
            self.passed('binding-'+name,'specific guard rejects before output/reservation')
        where,unit,repo=self.case('binding-controller-source')
        q=repo/'tools/dd1_compatibility.py';q.write_bytes(q.read_bytes()+b'\\n# substituted staged source\\n')
        unit['source_files']['res://tools/dd1_compatibility.py']=r.digest(q.read_bytes())
        unit['compatibility']=c.profile(unit)
        self.run('binding-controller-source',where,unit,repo,False,pre='loaded controller source differs')
        self.passed('binding-controller-source','self-consistent staged hashes cannot substitute loaded controller source')
        where,unit,repo=self.case('binding-selfhashed-inert')
        q=repo/'tools/dd1_linux/build/compat2-inert';q.write_bytes(q.read_bytes()+b'changed')
        unit['linux']['runtime']['/workload']['sha256']=r.digest(q.read_bytes())
        unit['compatibility']=c.profile(unit)
        self.run('binding-selfhashed-inert',where,unit,repo,False,pre='inert entry permits only pinned')
        self.passed('binding-selfhashed-inert','self-hashed altered executable cannot gain inert authority')
        where,unit,repo=self.case('binding-receipt')
        c.save_inputs(where,unit)
        (where/'receipt.json').write_bytes(r.encode({'schema':'DD1-INERT-ONLY','demand_sha256':'0'*64}))
        rec=c.run_one(where,repo);self.retain('binding-receipt',rec)
        check(rec['exit']==2 and 'inert demand/receipt mismatch' in rec['result']['pre_release_error'],'receipt mismatch')
        check(not rec['account']['recovery'].get('unit_reservations_v2') and not (where/'output').exists(),'receipt effects')
        self.passed('binding-receipt','missing/altered binding cannot release')

    def cpu(self):
        import dd1_linux_backend as b
        partitions=[b.cpu_partition(n) for n in range(11,301)]
        check(all(x['aggregate_with_headroom']<x['total'] and x['workload']==x['total']-10 for x in partitions),'partition range')
        self.retain('cpu-range',dict(partitions=partitions,scope='pure arithmetic, not 300-second burn'))
        self.passed('cpu-range','all supported demands 11..300 have bounded conservative aggregate partition')
        for n,mode,ok in [(11,'plain',True),(16,'cpu-above-three',True),(300,'plain',True),(14,'cpu-exhaust',False)]:
            name='cpu-'+str(n)
            where,unit,repo=self.case(name,mode,cpu=n)
            rec=self.run(name,where,unit,repo,ok); z=rec['result']; cls=z['classification']
            check(cls['workload_cpu_soft']==cls['workload_cpu_hard']==n-10,'installed workload limit')
            check(z['controller_cpu_limits']==[3,3] and cls['supervisor_cpu_soft']==cls['supervisor_cpu_hard']==2,'installed partition')
            if n==16:check(z['supervisor_report']['workload_cpu_seconds']>4,'above inherited hard3 actually reached')
            if n==14:check(z['supervisor_report']['signal']==9,'workload hard CPU exhaustion')
            self.passed(name,'actual installed CPU partitions and bounded workload endpoint')

    def preparation_budget(self):
        import dd1_preparation as prep
        where,unit,repo=self.case('temporary-layout-budget','prep',stage='preparation')
        self.recipe(unit)
        source={k:(repo/k[6:]).read_bytes() for k in unit['source_files']}
        small=prep.reserve_copy_bytes(unit['preparation'],source)
        unit['preparation']['slots'][0]['temporary_files'] += ['temp%d/file.tmp'%i for i in range(256)]
        unit['compatibility']=c.profile(unit)
        large=prep.reserve_copy_bytes(unit['preparation'],source)
        check(large-small >= 512*16384,'temporary layout metadata not reserved')
        self.run('temporary-layout-budget',where,unit,repo,False,pre='complete preparation/copy raw envelope')
        self.retain('temporary-layout-cost',dict(small=small,large=large,raw_envelope=unit['raw_bytes']))
        self.passed('temporary-layout-budget','precreated temporary paths/directories cannot escape the complete raw reservation')

    def recipe(self,unit,nested=False):
        prefix='sub/' if nested else ''
        unit['preparation']=dict(schema='DD1-PREPARATION-2',source_head=unit['overlay_head'],
            source_manifest_sha256=r.digest(r.encode(unit['source_files'])),
            engine_sha256=unit['linux']['runtime']['/workload']['sha256'],slots=[
                dict(path='.godot',kind='directory',files={prefix+'cache.bin':dict(min_bytes=14,max_bytes=14)},
                     temporary_files=[prefix+'cache.tmp']),
                dict(path='inputs/demo.uid',kind='file',files={'':dict(min_bytes=10,max_bytes=10)})])
        unit['compatibility']=c.profile(unit)

    def preparations(self):
        positive=None
        for mode in ['prep','prep-nested','prep-missing','prep-extra','prep-transient',
                     'prep-nested-transient','prep-symlink','prep-hardlink','prep-alias-symlink',
                     'prep-alias-hardlink','prep-replace-slot','prep-fail']:
            where,unit,repo=self.case(mode,mode,stage='preparation')
            self.recipe(unit,'nested' in mode)
            ok=mode in ('prep','prep-nested','prep-replace-slot')
            rec=self.run(mode,where,unit,repo,ok);z=rec['result']
            text=bytes.fromhex(rec['files'].get('capture/stdout.bin','')).decode()
            check('FROZEN_WRITE fd=-1 errno=' in text,'readonly guard not reached')
            check('DERIVED_OUTPUT_READY' in text,'generation not reached')
            if ok:
                check(z['sealed_preparation'] and z['preparation_audit']['ok'],'real protected seal missing')
                if mode=='prep':positive=(where,unit,repo,rec)
            else:check(not z.get('sealed_preparation'),'failed preparation promoted')
            if 'transient' in mode or mode == 'prep-extra':
                check(not z['preparation_audit']['ok'],'transient/replaced path escaped audit')
            if mode in ('prep-symlink','prep-hardlink','prep-alias-symlink','prep-alias-hardlink'):
                nr = 88 if 'symlink' in mode else 86
                check(any(e['nr']==nr and e['errno']==95 and e['capability_class']=='UNEXPECTED'
                          for e in z['refused_requests']), 'alias before-effect refusal not reached')
                check(z['classification']['unexpected_denials'] >= 1, 'caught alias refusal hidden')
                check('rc=-1 errno=95' in text, 'alias effect was not refused')
            self.passed(mode,'kernel readonly originals, actual generated outputs, promotion decision')
        self.sealed(*positive)
        for name,mutate,expected in [
            ('slot-source',lambda u:u['preparation']['slots'][1].update(path='inputs/frozen.txt'),'slot shadows'),
            ('slot-traversal',lambda u:u['preparation']['slots'][1].update(path='../bad.uid'),'invalid generated path'),
            ('wrong-lineage',lambda u:u['preparation'].update(engine_sha256='0'*64),'preparation engine lineage')]:
            where,unit,repo=self.case(name,'prep',stage='preparation');self.recipe(unit)
            mutate(unit);unit['compatibility']=c.profile(unit)
            self.run(name,where,unit,repo,False,pre=expected)
            self.passed(name,'preparation binding refuses before release')

    def sealed(self,prepwhere,prepunit,repo,preprec):
        seal=preprec['result']['sealed_preparation']
        shared=prepwhere/'synthetic-account.json'
        binding={k:seal[k] for k in ('unit_id','receipt_path','sha256')}
        # Deliberately modify the old mutable generated backing AFTER sealing.
        # The next runtime must still read the byte-pinned sealed copy.
        (prepwhere/'output/derived/0/cache.bin').write_bytes(b'CHANGED-MUTABLE')
        where,unit,_=self.case('sealed-runtime','sealed-runtime',stage='fixture',repo=repo,existing_account=r.read(shared))
        unit['sealed_input']=binding;unit['compatibility']=c.profile(unit)
        rec=self.run('sealed-runtime',where,unit,repo,True,ap=shared)
        check('SEALED_WRITE fd=-1 errno=' in bytes.fromhex(rec['files']['capture/stdout.bin']).decode(),'runtime readonly')
        self.passed('sealed-runtime','fresh readonly runtime uses sealed lineage, never mutated preparation backing')
        payload=Path(seal['receipt_path']).parent/'payload'
        target=payload/'.godot/cache.bin'; original=target.read_bytes()
        actions=[('corrupt',lambda:target.write_bytes(b'X'*14),'sealed snapshot corruption'),
                 ('missing',lambda:target.unlink(),'unexpected empty generated directory'),
                 ('symlink',lambda:(target.unlink(),target.symlink_to('/etc/passwd')),'derived symlink'),
                 ('hardlink',lambda:os.link(target,target.parent/'extra.bin'),'sealed snapshot inventory changed')]
        for name,action,reason in actions:
            action()
            where,unit,_=self.case('sealed-'+name,'sealed-runtime',stage='fixture',repo=repo,existing_account=r.read(shared))
            unit['sealed_input']=binding;unit['compatibility']=c.profile(unit)
            self.run('sealed-'+name,where,unit,repo,False,ap=shared,pre=reason)
            if target.is_symlink() or target.exists():target.unlink()
            extra=target.parent/'extra.bin'
            if extra.exists():extra.unlink()
            target.write_bytes(original);target.chmod(0o400)
            self.passed('sealed-'+name,'altered sealed inputs cannot reserve or execute')
        where,unit,_=self.case('sealed-failed-parent','sealed-runtime',stage='fixture',repo=repo,existing_account=r.read(shared))
        unit['sealed_input']=binding;unit['compatibility']=c.profile(unit)
        altered=r.read(where/'synthetic-account.json');altered['recovery']['unit_reservations_v2'][0]['state']='FAILED'
        (where/'synthetic-account.json').write_bytes(r.encode(altered));unit['account_sha256']=r.digest(r.encode(altered))
        self.run('sealed-failed-parent',where,unit,repo,False,pre='missing/failed preparation reservation')
        self.passed('sealed-failed-parent','failed lineage never promoted')

    def killed(self,who,preparation=False):
        name='kill-'+who+('-prep' if preparation else '')
        mode='prep-block' if preparation else 'block-thread'
        where,unit,repo=self.case(name,mode,stage='preparation' if preparation else 'identity')
        if preparation:self.recipe(unit)
        c.save_inputs(where,unit);ap=where/'synthetic-account.json'
        cmd=c.controller_command(where,repo,ap)
        before=ap.read_bytes();p=subprocess.Popen(cmd,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
        try:
            end=time.monotonic()+8
            while time.monotonic()<end:
                ledger=r.read(ap);rows=ledger['recovery'].get('unit_reservations_v2',[])
                stream=where/'output/capture/stdout.bin'
                if rows and 'processes' in rows[0] and stream.exists() and b'SAVE_READBACK_OK' in stream.read_bytes():break
                check(p.poll() is None,'kill fixture exited before intended point')
                time.sleep(.01)
            else:raise AssertionError('kill fixture never reached save')
            row=rows[0];identities=row['processes'];active=r.read(ap)
            # A genuinely competing unit shares the SAME locked account.
            other,u2,_=self.case(name+'-concurrent','plain',repo=repo,existing_account=active)
            blocked=self.run(name+'-concurrent',other,u2,repo,False,ap=ap,pre='one executor already holds account')
            os.kill(identities[who]['pid'],signal.SIGKILL)
            stdout,stderr=p.communicate(timeout=8)
            adopted=[];end=time.monotonic()+4
            while time.monotonic()<end:
                try:pid,status,usage=os.wait4(-1,os.WNOHANG)
                except ChildProcessError:break
                if pid:adopted.append(dict(pid=pid,status=status,cpu_seconds=usage.ru_utime+usage.ru_stime))
                else:time.sleep(.01)
            final=r.read(ap)
            record=dict(argv=cmd,account_before_hex=before.hex(),before_kill=active,account=final,
                killed=who,exit=p.returncode,stdout=stdout,stderr=stderr,adopted=adopted,
                concurrent=blocked,save_hex=(where/'output/capture/save.bin').read_bytes().hex())
            self.retain(name,record)
            check(all(not Path('/proc',str(i['pid'])).exists() for i in identities.values()),'kill left live process')
            check(final['recovery']['unit_reservations_v2'][0]['starts']==1,'kill refunded start')
            check(not (where/'output/sealed/SEAL.json').exists(),'interrupted preparation sealed')
            if who=='controller':
                check(final['recovery']['unit_reservations_v2'][0]['state']=='RESERVED','controller death must retain durable charge')
                other,u3,_=self.case(name+'-stale','plain',repo=repo,existing_account=final)
                self.run(name+'-stale',other,u3,repo,False,ap=ap,pre='unresolved prior workload')
                before_totals=r.totals(r.read(ap));reconciled=r.reconcile_stale(ap)
                check(reconciled['totals']==before_totals and not reconciled['launch_permitted'],'reconciliation credit')
                record['reconciliation']=reconciled;record['reconciled_account']=r.read(ap);self.retain(name,record)
            else:
                result=json.loads(stdout)
                check(not result['success'] and result['cleanup_confirmed'],'supervisor cleanup verdict')
            self.passed(name,'actual signal after save; exclusivity, process death, no refund/promotion')
        finally:
            if p.poll() is None:p.kill();p.communicate(timeout=5)

    def replay(self):
        where,unit,repo=self.case('replay','plain')
        self.run('replay-first',where,unit,repo,True)
        unit['account_sha256']=r.digest((where/'synthetic-account.json').read_bytes())
        unit['compatibility']=c.profile(unit);c.save_inputs(where,unit)
        before=(where/'synthetic-account.json').read_bytes();record=c.run_one(where,repo)
        self.retain('replay',record)
        check(record['exit']==2 and 'unit already reserved' in record['result']['pre_release_error'],'replay guard')
        check(r.encode(record['account'])==before,'replay account changed')
        self.passed('replay','same unit cannot spawn twice or refund')


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--head',required=True);parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--section',choices=['all','kernel','binding','cpu','prep','kill'],default='all')
    args=parser.parse_args();c.HEAD=args.head
    m=Matrix(args.output)
    try:
        if args.section in ('all','kernel'):m.kernel_cases();m.replay()
        if args.section in ('all','binding'):m.bindings()
        if args.section in ('all','cpu'):m.cpu()
        if args.section in ('all','prep'):m.preparations();m.preparation_budget()
        if args.section in ('all','kill'):
            m.killed('supervisor');m.killed('controller');m.killed('supervisor',True);m.killed('controller',True)
    except BaseException as exc:
        (args.output/'FAILURE.json').write_bytes(r.encode(dict(error=type(exc).__name__+':'+str(exc),directory=str(m.root))))
        raise
    (args.output/'SUMMARY.json').write_bytes(r.encode(dict(passed=len(m.results),head=args.head,
        scope='SOURCE/INERT ONLY',engine_runs=0,live_account_writes=0,directory=str(m.root),complete=True)))
    return 0

if __name__=='__main__':sys.exit(main())
