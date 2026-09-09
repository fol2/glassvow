"""One fixed-cost controller capability/value experiment, not another content tune.
Reuses the qualified pair capture and decision readers without changing them.
"""
from concurrent.futures import ThreadPoolExecutor
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import bridge
import compare_value

HERE=Path(__file__).resolve().parent
PAIR=Path('research/p9-six-route/ash-inheritance-20260909/pair-v1')
require,sha=bridge.require,bridge.sha


def dump(path,x):Path(path).write_text(json.dumps(x,indent=2)+'\n')


def previous(repo,p):
    for rel,want in p['previous_sha256'].items():require(sha((repo/rel).read_bytes())==want,'PREVIOUS_SOURCE:'+rel)
    sys.path.insert(0,str(repo/PAIR))
    import read_pair,run_pair
    return read_pair,run_pair


def runtime(project):
    names=['balance_sim.gd','observed_sim.gd','balance_pilot.gd','balance_policy.gd','balance_metrics.gd','vow_incentives.gd']
    return {'sources':{n:sha((project/'tools'/n).read_bytes()) for n in names},
            'content_sha256':sha((project/'content/full-content.json').read_bytes()),
            'combat_sha256':sha((project/'domain/rules/combat.gd').read_bytes()),
            'observer_sha256':sha((project/'observed_game.gd').read_bytes()),
            'probe_sha256':sha((project/'probe.gd').read_bytes())}


def capability_coverage(records,card_ids):
    expected=set()
    for pi in range(5):
        for aspect in (0,1):
            for random_build in (False,True):
                for deck in ('empty','source','consumer','duplicate'):
                    expected.add(('choice',pi,aspect,random_build,deck))
                    for card in card_ids:
                        for up in (False,True):expected.add(('score',pi,aspect,random_build,deck,card,up))
        for card in ('bloodRite','leechBlade'):expected.add(('absent_public_law',pi,card))
    expected.add(('content_unchanged',))
    actual=[]
    for r in records:
        kind=r['kind']
        if kind=='score':key=(kind,r['policy'],r['aspect'],r['random_build'],r['deck'],r['card'],r['up'])
        elif kind=='choice':key=(kind,r['policy'],r['aspect'],r['random_build'],r['deck'])
        elif kind=='absent_public_law':key=(kind,r['policy'],r['card'])
        else:key=(kind,)
        actual.append(key)
    require(len(actual)==len(expected) and set(actual)==expected,'COMPLETE_CAPABILITY_IDENTITIES')


def execute(repo,engine,out,work,do_publish):
    repo,engine,out,work=map(lambda x:Path(x).resolve(),(repo,engine,out,work))
    require(not out.exists() and not work.exists(),'OUTPUT_EXISTS_NO_AUTOMATIC_REPLAY')
    out.mkdir(parents=True);work.mkdir()
    p=json.loads((HERE/'PROTOCOL.json').read_bytes())
    reader,runner=previous(repo,p)
    head=runner.git(repo,'rev-parse','HEAD')
    terminal={'status':'INCONCLUSIVE','source_head':head,'stages':{},'packages_admitted':0,'p9_certified':False}
    try:
        for name,want in p['own_sha256'].items():require(sha((HERE/name).read_bytes())==want,'SOURCE:'+name)
        require(sha(engine.read_bytes())==p['engine_sha256'],'ENGINE')
        source_out=out/'original-source';source_out.mkdir()
        stock=runner.prepare(repo,work,source_out,p)
        aware=work/'aware';shutil.copytree(stock,aware)
        (aware/'tools/stock_pilot.gd').write_text((aware/'tools/balance_pilot.gd').read_text().replace('class_name BalancePilot\n','',1))
        change=bridge.install(aware)
        dump(out/'SOURCE-DELTA.json',change)
        projects={'stock':stock,'aware':aware}
        for project in projects.values():shutil.copyfile(HERE/'null_probe.gd',project/'null_probe.gd')
        shutil.copyfile(HERE/'capability.gd',aware/'capability.gd')
        pp={name:dict(p,runtime=runtime(project)) for name,project in projects.items()}
        require(pp['stock']['runtime']['content_sha256']==pp['aware']['runtime']['content_sha256'],'CONTENT_CHANGED')
        require(pp['stock']['runtime']['combat_sha256']==pp['aware']['runtime']['combat_sha256'],'COMBAT_CHANGED')
        before=bridge.funcs((stock/'tools/balance_pilot.gd').read_text())
        after=bridge.funcs((aware/'tools/balance_pilot.gd').read_text())
        require(before['card_score']==after['card_score'] and before['_combat_score']==after['_combat_score'],'COMBAT_SCORING_CHANGED')
        manifests={name:{str(f.relative_to(proj)):{'bytes':f.stat().st_size,'sha256':sha(f.read_bytes())} for f in sorted(proj.rglob('*')) if f.is_file()} for name,proj in projects.items()}
        for rel,item in manifests['stock'].items():
            if rel.startswith('domain/') or rel.startswith('content/'):
                require(item==manifests['aware'][rel],'PRODUCT_DELTA:'+rel)
        dump(out/'SOURCE-MANIFEST.json',manifests)
        dump(out/'RESOLVED-PROTOCOLS.json',pp)
        with tarfile.open(out/'controller-runtime.tar.xz','w:xz') as tf:
            for name,project in projects.items():
                for rel in manifests[name]:tf.add(project/rel,arcname=name+'/'+rel,recursive=False)
        if do_publish:head=runner.publish(repo,out,head,'research(p9): freeze acquisition controller runtimes before qualification')
        q=out/'qualification';q.mkdir()
        runner.command([sys.executable,'-m','unittest','-v','test_bridge'],q,'tests',cwd=HERE)
        for name,project in projects.items():
            runner.command([str(engine),'--headless','--path',str(project),'--import'],q,name+'-import')
            paths=['tools/balance_pilot.gd','tools/balance_sim.gd','tools/observed_sim.gd','probe.gd','null_probe.gd']
            if name=='aware':paths+=['tools/stock_pilot.gd','capability.gd']
            runner.command(['env','GODOT='+str(engine),'bash','tools/check_scripts.sh',*paths],q,name+'-parse',cwd=project)
        checks=q/'capability.jsonl'
        runner.command([str(engine),'--headless','--path',str(aware),'-s','res://capability.gd','--',str(checks)],q,'capability')
        records=list(reader.stream(checks));last=records.pop()
        require(last['kind']=='terminal' and last['checks']==len(records) and last['failures']==0,'CAPABILITY_COVERAGE')
        require(all(r['okay'] is True for r in records),'CAPABILITY_NEGATIVE')
        capability_coverage(records,json.loads((aware/'content/full-content.json').read_bytes())['cards'])
        for name,project in projects.items():
            runner.command([str(engine),'--headless','--path',str(project),'-s','res://null_probe.gd','--',str(q/(name+'-null.jsonl'))],q,name+'-null')
        null_a=(q/'stock-null.jsonl').read_bytes();null_b=(q/'aware-null.jsonl').read_bytes()
        require(null_a==null_b,'SIGNED_RANDOMBUILD_ENDPOINT_CHANGED')
        require(len(list(reader.stream(q/'stock-null.jsonl')))==4,'SIGNED_NULL_COVERAGE')
        # New observer/factory binding under each controller: four pairs each.
        for name,project in projects.items():
            target=q/name;target.mkdir()
            for vow in (5,0):
                cfg={'root':p['policy_root'],'first':0,'count':2,'seeds':[p['qualification_seed']],'vow':vow,'integration':True}
                result=runner.cell(cfg,project,engine,target,pp[name])
                require(result['status']=='COMPLETE','OBSERVER_PARITY:'+name)
        dump(q/'RESULTS.json',{'status':'ACQUISITION_CAPABILITY_AND_NULL_PASS','query_checks':len(records),
                              'random_build_full_endpoint_pairs':4,'stock_observed_pairs':8,
                              'combat_scoring_unchanged':True,'fitted_parameters':0,'packages_admitted':0})
        if do_publish:head=runner.publish(repo,out,head,'research(p9): preserve passed acquisition capability and signed-null checks')
        for vow in (5,0):
            stage=out/f'v{vow}';stage.mkdir()
            for name in projects:(stage/name).mkdir()
            tasks=[(name,{'root':p['policy_root'],'first':i,'count':p['policies_per_cell'],'seeds':p['seeds'],'vow':vow,'integration':False}) for i in range(0,128,p['policies_per_cell']) for name in projects]
            for offset in range(0,len(tasks),2):
                def run(task):
                    name,cfg=task
                    return runner.cell(cfg,projects[name],engine,stage/name,pp[name])
                with ThreadPoolExecutor(max_workers=2) as pool:receipts=list(pool.map(run,tasks[offset:offset+2]))
                if do_publish:head=runner.publish(repo,out,head,f'research(p9): preserve acquisition comparison v{vow} paired chunk {offset//2+1}')
                require(all(r['status']=='COMPLETE' for r in receipts),'INCOMPLETE_MATCHED_STAGE')
                first=tasks[offset][1]['first'];stem=f'v{vow}-{first:03d}.outcomes.jsonl.xz'
                headers=[next(reader.stream(stage/name/stem)) for name in projects]
                require(headers[0]['policies']==headers[1]['policies'] and headers[0]['config']==headers[1]['config'],'PAIRED_POLICY_VECTORS')
            results={name:reader.analyze(stage/name,pp[name],vow) for name in projects}
            for name,result in results.items():dump(stage/name/'RESULTS.json',result)
            comparison=compare_value.compare(results['stock'],results['aware'],p)
            dump(stage/'COMPARISON.json',comparison)
            terminal['stages'][str(vow)]=comparison
            if not comparison['pass']:
                terminal.update(status='FIXED_ACQUISITION_ADAPTER_NOT_ADMITTED',last_vow=vow,v0_skipped=vow==5)
                break
            if do_publish:head=runner.publish(repo,out,head,f'research(p9): preserve closed acquisition comparison v{vow} decision')
        else:terminal['status']='ACQUISITION_ADAPTER_VALUE_SUPPORTED_NOT_PACKAGE'
    except Exception as exc:terminal['failure']=repr(exc)
    finally:
        dump(out/'TERMINAL.json',terminal)
        dump(out/'FILES.json',[{'path':str(f.relative_to(out)),'bytes':f.stat().st_size,'sha256':sha(f.read_bytes())} for f in sorted(out.rglob('*')) if f.is_file()])
        if do_publish:head=runner.publish(repo,out,head,'research(p9): preserve fixed acquisition controller terminal')
        if os.environ.get('GITHUB_ENV'):
            with open(os.environ['GITHUB_ENV'],'a') as f:f.write('PUBLISHED_HEAD='+head+'\n')
        print(json.dumps({'published_head':head,'terminal':terminal},sort_keys=True))
    return 3 if terminal['status']=='INCONCLUSIVE' else 0


def verify(repo,original,cold,output):
    repo,original,cold,output=map(Path,(repo,original,cold,output))
    require(not output.exists(),'OUTPUT_EXISTS')
    p=json.loads((HERE/'PROTOCOL.json').read_bytes());reader,_=previous(repo,p)
    entries=json.loads((original/'FILES.json').read_bytes())
    for r in entries:
        rel=Path(r['path']);require(not rel.is_absolute() and '..' not in rel.parts,'PATH')
        a=(original/rel).read_bytes();b=(cold/rel).read_bytes()
        require(a==b and len(b)==r['bytes'] and sha(b)==r['sha256'],'REMOTE_BYTES:'+str(rel))
    require((original/'FILES.json').read_bytes()==(cold/'FILES.json').read_bytes(),'MANIFEST_READBACK')
    terminal=json.loads((cold/'TERMINAL.json').read_bytes())
    pp=json.loads((cold/'RESOLVED-PROTOCOLS.json').read_bytes())
    for vow in terminal['stages']:
        results={name:reader.analyze(cold/f'v{vow}'/name,pp[name],int(vow)) for name in ('stock','aware')}
        result=compare_value.compare(results['stock'],results['aware'],p)
        require((json.dumps(result,indent=2)+'\n').encode()==(cold/f'v{vow}/COMPARISON.json').read_bytes(),'COMPARISON_READBACK')
    dump(output,{'kind':'COMPLETE_ACQUISITION_COMPARISON_COLD_READBACK','files':len(entries)+1,
                 'all_bytes_equal':True,'reproduced_stages':list(terminal['stages']),
                 'scientific_status':terminal['status'],'new_native_runs':0,'packages_admitted':0,'p9_certified':False})

if __name__=='__main__':
    if sys.argv[1]=='run':raise SystemExit(execute(*sys.argv[2:6],do_publish='--publish' in sys.argv))
    else:verify(*sys.argv[2:])
