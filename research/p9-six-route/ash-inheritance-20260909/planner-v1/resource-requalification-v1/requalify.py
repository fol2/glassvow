"""Exact implementation requalification; preserve the old resource terminal.
V5 replay is same-policy delivery evidence, never new statistical replication.
Only a new complete exact-equivalence and resource proof opens gated analyses.
"""
from __future__ import annotations
from concurrent.futures import ThreadPoolExecutor
import copy,hashlib,importlib.util,json,os,shutil,sys,tarfile
from pathlib import Path
P=Path('research/p9-six-route/ash-inheritance-20260909/planner-v1')
HERE=Path(__file__).resolve().parent

def require(ok,why):
    if not ok:raise ValueError(why)
def sha(b):return hashlib.sha256(b).hexdigest()
def save(p,x):p.write_text(json.dumps(x,indent=2)+'\n')
def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m

def dependencies(repo):
    expected={
        'value-v1/repaired-source-1/experiment.py':'4a53245727489203100e71545af15b806046dc34',
        'value-v1/repaired-source-1/read_value.py':'48e97d785a945df2bb5bcf00574047edf8c8513f',
        'continuation-cache-v1/benchmark.py':'5d8a0dfc11a003c62cd5cd1305a659d3909a081a'}
    for name,want in expected.items():
        data=(repo/P/name).read_bytes()
        actual=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
        require(actual==want,'BOUND_DEPENDENCY:'+name)
    sys.path.insert(0,str(repo/P/'value-v1/repaired-source-1'))
    value=module('fixed_value',repo/P/'value-v1/repaired-source-1/experiment.py')
    base,reader,binder=value.dependencies(repo)
    bench=module('bound_cache',repo/P/'continuation-cache-v1/benchmark.py')
    return value,base,reader,bench

def cell_equivalence(original,current,stem,bench):
    import lzma
    a=lzma.decompress((original/(stem+'.outcomes.jsonl.xz')).read_bytes())
    b=lzma.decompress((current/(stem+'.outcomes.jsonl.xz')).read_bytes())
    require(bench.canonical(a)==bench.canonical(b),'FULL_ENDPOINT_OR_DECISION_CHANGE:'+stem)
    x=lzma.decompress((original/(stem+'.traces.jsonl.xz')).read_bytes())
    y=lzma.decompress((current/(stem+'.traces.jsonl.xz')).read_bytes())
    require(x==y,'NATIVE_TRACE_CHANGE:'+stem)
    return {'stem':stem,'native_trace_sha256':sha(y),'canonical_outcome_sha256':sha(bench.canonical(b))}


def resource_ok(costs,previous):
    for method in ('stock','planner'):
        total=costs[method]['process_cpu_seconds']
        for phase in ('value-screen','reserved-configuration-check'):
            if phase in previous:total+=previous[phase]['costs'][method]['process_cpu_seconds']
        if total<0 or not __import__('math').isfinite(total) or total>3600:return False
    return True


def run(repo,engine,out,work,publish=False):
    repo,engine,out,work=map(lambda x:Path(x).resolve(),(repo,engine,out,work))
    require(not out.exists() and not work.exists(),'OUTPUT_EXISTS_NO_RERUN');out.mkdir(parents=True);work.mkdir()
    value,base,reader,bench=dependencies(repo);head=base.git(repo,'rev-parse','HEAD')
    contract=json.loads((HERE/'PROTOCOL.json').read_bytes())
    for n,h in contract['source_sha256'].items():require(sha((HERE/n).read_bytes())==h,'OWN_SOURCE:'+n)
    require(sha(engine.read_bytes())==bench.ENGINE,'ENGINE')
    gate=repo/P/'continuation-integer-v1/execution-1'
    require(sha((gate/'RESULTS.json').read_bytes())==contract['cache_result_sha256'],'CACHE_RESULT')
    require(json.loads((gate/'RESULTS.json').read_bytes())['status']=='EXACT_CONTINUATION_CACHE_SPEEDUP_ESTABLISHED','CACHE_NOT_QUALIFIED')
    require(json.loads((gate/'REMOTE-READBACK.json').read_bytes())['readout_reproduced'] is True,'CACHE_READBACK')
    old=repo/P/'value-v1/execution-2'
    old_files=(old/'FILES.json').read_bytes();require(sha(old_files)==bench.WORKLOAD_FILES,'OLD_MANIFEST')
    entries={r['path']:r for r in json.loads(old_files)}
    old_terminal=(old/'TERMINAL.json').read_bytes()
    require(json.loads(old_terminal)['failure']=="ValueError('MATCHED_RESOURCE_CEILING')",'EXACT_OLD_TERMINAL')
    original_protocol=json.loads((repo/P/'value-v1/repaired-source-1/PROTOCOL.json').read_bytes())
    require(original_protocol['cpu_seconds_per_method_per_vow']==3600,'UNCHANGED_RESOURCE_BAR')
    for name in ('RESOLVED-PROTOCOLS.json','TERMINAL.json'):
        data=(old/name).read_bytes();require(sha(data)==entries[name]['sha256'] and len(data)==entries[name]['bytes'],'OLD_INPUT:'+name)
    protocols=json.loads((old/'RESOLVED-PROTOCOLS.json').read_bytes())
    require(all(q['policies']==128 and q['policies_per_cell']==2 and q['policy_root']==73409000 and q['seeds']==[73410100,73410101,73410102,73410103] for q in protocols.values()),'ORIGINAL_ASSIGNMENT')
    require(sha((repo/P/'continuation-integer-v1/bound-source/continuation_cache.gd').read_bytes())==contract['optimized_source_sha256'],'OPTIMIZED_SOURCE')
    terminal={'status':'INCONCLUSIVE','source_head':head,'stages':{},'old_terminal_sha256':sha(old_terminal),
              'old_terminal_unchanged':True,'same_policy_replay_independent_samples':0,'packages_admitted':0,'p9_certified':False}
    try:
        projects={}
        for method in ('stock','planner'):
            source=old/(method+'-source');manifest=json.loads((source/'FINAL-SOURCE-MANIFEST.json').read_bytes())
            require(sha((source/'FINAL-SOURCE-MANIFEST.json').read_bytes())==entries[method+'-source/FINAL-SOURCE-MANIFEST.json']['sha256'],'SOURCE_MANIFEST')
            records=[dict(path=n,**r) for n,r in manifest.items()]
            project=work/method
            bench.unpack(source/'bound-runtime.tar.xz',project,records,entries[method+'-source/bound-runtime.tar.xz']['sha256'])
            if method=='planner':bench.patch(project,repo/P/'continuation-integer-v1/bound-source/continuation_cache.gd')
            for path,r in manifest.items():
                if method=='planner' and path=='rollout_policy.gd':continue
                require(sha((project/path).read_bytes())==r['sha256'],'UNRELATED_RUNTIME_DELTA:'+path)
            projects[method]=project
        save(out/'RESOLVED-PROTOCOLS.json',protocols)
        save(out/'SOURCE-MANIFEST.json',{method:{str(p.relative_to(project)):{'bytes':p.stat().st_size,'sha256':sha(p.read_bytes())} for p in sorted(project.rglob('*')) if p.is_file()} for method,project in projects.items()})
        with tarfile.open(out/'runtime-source.tar.xz','w:xz') as tf:
            for method,project in projects.items():
                for p in sorted(project.rglob('*')):
                    if p.is_file():tf.add(p,arcname=method+'/'+str(p.relative_to(project)),recursive=False)
        if publish:head=base.publish(repo,out,head,'research(p9): bind exact optimized implementation for full-workload requalification')
        logs=out/'qualification';logs.mkdir()
        for method,project in projects.items():
            base.command([str(engine),'--headless','--path',str(project),'--import'],logs,method+'-import')
            base.command(['env','GODOT='+str(engine),'bash','tools/check_scripts.sh',*sorted(f.name for f in project.glob('*.gd'))],logs,method+'-parse',cwd=project)
        for vow in (5,0):
            stage=out/f'v{vow}';stage.mkdir();stage_result={};equivalence=[]
            for method in projects:(stage/method).mkdir()
            for phase,first,count in [('value-screen',0,32),('reserved-configuration-check',32,96)]:
                specs=[(m,{'root':protocols[m]['policy_root'],'first':i,'count':2,'seeds':protocols[m]['seeds'],'vow':vow,'integration':False}) for i in range(first,first+count,2) for m in projects]
                for offset in range(0,len(specs),8):
                    with ThreadPoolExecutor(max_workers=2) as pool:
                        receipts=list(pool.map(lambda x:value.cell(x[1],projects[x[0]],engine,stage/x[0],protocols[x[0]],base,reader),specs[offset:offset+8]))
                    if not all(r['status']=='COMPLETE' for r in receipts):
                        if publish:head=base.publish(repo,out,head,'research(p9): preserve incomplete assigned cells before stopping')
                        raise ValueError('INCOMPLETE_CELL')
                    if vow==5:
                        for m,cfg in specs[offset:offset+8]:
                            eq=cell_equivalence(old/'v5'/m,stage/m,f"v5-{cfg['first']:03d}",bench);equivalence.append(dict(method=m,**eq))
                    save(stage/'EQUIVALENCE.json',{'applicable':vow==5,'cells':equivalence,'no_old_v0_rows_claimed':True})
                    if publish:head=base.publish(repo,out,head,f'research(p9): preserve fixed cache implementation v{vow} {phase} group {offset//8+1}')
                rows={};costs={}
                for m in projects:rows[m],costs[m]=value.read_value.read_stage(stage/m,protocols[m],vow,first,count,reader)
                result=value.read_value.compare(rows['stock'],rows['planner'],first,count,protocols['stock']['seeds']);result['costs']=costs
                result['resource_ceiling_met']=resource_ok(costs,stage_result)
                # Retain actual performance before evaluating the unchanged cost gate.
                save(stage/(phase+'.json'),result);stage_result[phase]=result
                terminal['stages'][str(vow)]=stage_result
                if not result['resource_ceiling_met']:
                    terminal.update(status='IMPLEMENTATION_RESOURCE_REQUALIFICATION_FAIL',last_vow=vow,v0_skipped=vow==5)
                    break
                if not result['pass']:
                    terminal.update(status='FIXED_OPTIMIZED_PLANNER_VALUE_NOT_ESTABLISHED',last_vow=vow,v0_skipped=vow==5)
                    break
            else:
                # New implementation cost qualification, not a relabelled old terminal.
                support={m:reader.analyze(stage/m,protocols[m],vow) for m in projects}
                for m,result in support.items():save(stage/(m+'-support.json'),result)
                stage_result['support']={m:{k:v for k,v in r.items() if k not in ('row_results','policy_ids')} for m,r in support.items()}
                stage_result['support_pass']=support['planner']['pass']
                terminal['stages'][str(vow)]=stage_result
                if not support['planner']['pass']:
                    terminal.update(status='FIXED_OPTIMIZED_PLANNER_PAIR_SUPPORT_NOT_ESTABLISHED',last_vow=vow,v0_skipped=vow==5)
                    break
                if publish:head=base.publish(repo,out,head,f'research(p9): preserve complete qualified implementation v{vow} support decision')
                continue
            break
        else:terminal['status']='OPTIMIZED_PLANNER_VALUE_AND_PAIR_SUPPORT_PASS_NOT_CERTIFICATE'
    except Exception as exc:terminal['failure']=repr(exc)
    finally:
        require((old/'TERMINAL.json').read_bytes()==old_terminal,'OLD_TERMINAL_WAS_CHANGED')
        save(out/'TERMINAL.json',terminal)
        save(out/'FILES.json',[{'path':str(p.relative_to(out)),'bytes':p.stat().st_size,'sha256':sha(p.read_bytes())} for p in sorted(out.rglob('*')) if p.is_file() and p.name!='FILES.json'])
        if publish:head=base.publish(repo,out,head,'research(p9): preserve actual optimized implementation terminal without rewriting history')
        if os.environ.get('GITHUB_ENV'):
            with open(os.environ['GITHUB_ENV'],'a') as f:f.write('PUBLISHED_HEAD='+head+'\n')
        print(json.dumps(terminal,indent=2))
    return 3 if terminal['status']=='INCONCLUSIVE' else 0

def verify(repo,original,cold,receipt):
    repo,original,cold,receipt=map(Path,(repo,original,cold,receipt))
    require(not receipt.exists(),'READBACK_EXISTS')
    value,base,reader,bench=dependencies(repo)
    manifest=(original/'FILES.json').read_bytes()
    require((cold/'FILES.json').read_bytes()==manifest,'READBACK_MANIFEST')
    entries=json.loads(manifest)
    require(len({r['path'] for r in entries})==len(entries),'DUPLICATE_CAPTURE_PATH')
    for r in entries:
        path=Path(r['path']);require(not path.is_absolute() and '..' not in path.parts,'CAPTURE_PATH')
        a=(original/path).read_bytes();b=(cold/path).read_bytes()
        require(a==b and len(b)==r['bytes'] and sha(b)==r['sha256'],'COLD_BYTES:'+str(path))
    terminal=json.loads((cold/'TERMINAL.json').read_bytes())
    ps=json.loads((cold/'RESOLVED-PROTOCOLS.json').read_bytes())
    old=repo/P/'value-v1/execution-2'
    require(sha((old/'TERMINAL.json').read_bytes())==terminal['old_terminal_sha256'],'OLD_TERMINAL_RETENTION')
    compared=0
    for vow,stage in terminal['stages'].items():
        previous={}
        for phase,first,count in [('value-screen',0,32),('reserved-configuration-check',32,96)]:
            if phase not in stage:continue
            rows={};costs={}
            for m in ('stock','planner'):
                rows[m],costs[m]=value.read_value.read_stage(cold/f'v{vow}'/m,ps[m],int(vow),first,count,reader)
                if int(vow)==5:
                    for start in range(first,first+count,2):
                        cell_equivalence(old/'v5'/m,cold/'v5'/m,f'v5-{start:03d}',bench);compared+=1
            result=value.read_value.compare(rows['stock'],rows['planner'],first,count,ps['stock']['seeds'])
            result['costs']=costs;result['resource_ceiling_met']=resource_ok(costs,previous)
            require((json.dumps(result,indent=2)+'\n').encode()==(cold/f'v{vow}'/(phase+'.json')).read_bytes(),'FROZEN_VALUE_READOUT')
            require(result==stage[phase],'TERMINAL_VALUE_BINDING');previous[phase]=result
        if 'support' in stage:
            require(all(r['resource_ceiling_met'] and r['pass'] for r in previous.values()) and len(previous)==2,'SUPPORT_PRECONDITIONS')
            for m in ('stock','planner'):
                result=reader.analyze(cold/f'v{vow}'/m,ps[m],int(vow))
                require((json.dumps(result,indent=2)+'\n').encode()==(cold/f'v{vow}'/(m+'-support.json')).read_bytes(),'SUPPORT_REPLAY')
        if int(vow)==0:
            prior=terminal['stages']['5']
            require(prior.get('support_pass') is True,'V0_OPENED_WITHOUT_PASS')
    save(receipt,{'kind':'FULL_EXACT_IMPLEMENTATION_RESOURCE_COLD_READBACK','files':len(entries)+1,
        'all_bytes_equal':True,'original_v5_cells_reconciled':compared,'reproduced_stages':list(terminal['stages']),
        'scientific_status':terminal['status'],'old_terminal_unchanged':True,'readback_native_runs':0,
        'old_v5_replays_counted_as_independent':False,'packages_admitted':0,'p9_certified':False})

if __name__=='__main__':
    if sys.argv[1]=='run':raise SystemExit(run(*sys.argv[2:6],publish='--publish' in sys.argv))
    elif sys.argv[1]=='verify':verify(*sys.argv[2:])
    else:raise SystemExit('run REPO ENGINE OUTPUT WORK [--publish] | verify REPO ORIGINAL COLD RECEIPT')
