"""One exact continuation-query memoisation; no new policy or statistical sample.
Read complete saved endpoints, not selected successes. Old resource terminal stays.
"""
from __future__ import annotations
import hashlib, importlib.util, json, lzma, os, shutil, subprocess, sys, tarfile
from pathlib import Path

P=Path('research/p9-six-route/ash-inheritance-20260909/planner-v1')
HERE=Path(__file__).resolve().parent
ENGINE='8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e'
QUAL_ARCHIVE='7770b3e03e12408b2b71da19312e8cda0307334409ce61a4aa335e986ec46f1d'
WORKLOAD_FILES='e8e2e3314b3a6f062af2ef4d0719d7a71bb24762d65049e87a7ea28255e0bf5e'
STEM='v5-000'
MODES=('baseline','active','off','producer_off','consumer_off')


def require(ok,why):
    if not ok:raise ValueError(why)
def sha(b):return hashlib.sha256(b).hexdigest()
def save(p,obj):p.write_text(json.dumps(obj,indent=2)+'\n')
def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m

def unpack(archive_path,target,records,expected_sha):
    raw=archive_path.read_bytes();require(sha(raw)==expected_sha,'ARCHIVE_HASH')
    expected={r['path']:r for r in records};require(len(expected)==len(records),'DUPLICATE_MANIFEST')
    require(not target.exists(),'EXTRACTION_TARGET_EXISTS');target.mkdir(parents=True)
    with tarfile.open(archive_path,'r:xz') as tf:
        members=tf.getmembers()
        require(len(members)==len(expected) and {m.name for m in members}==set(expected),'ARCHIVE_COVERAGE')
        for m in members:
            p=Path(m.name);require(m.isfile() and not p.is_absolute() and '..' not in p.parts,'ARCHIVE_PATH')
            b=tf.extractfile(m).read();r=expected[m.name]
            require(len(b)==r['bytes'] and sha(b)==r['sha256'],'ARCHIVE_BYTE:'+m.name)
            dst=target/p;dst.parent.mkdir(parents=True,exist_ok=True);dst.write_bytes(b)
    return len(expected)

def patch(project,source):
    p=project/'rollout_policy.gd';old=p.read_bytes()
    anchor='const Greedy: GDScript=preload("res://greedy_policy.gd")'
    text=old.decode();require(text.count(anchor)==1,'CONTINUATION_FACTORY_ANCHOR')
    new=text.replace(anchor,'const Greedy: GDScript=preload("res://continuation_cache.gd")',1).encode()
    p.write_bytes(new);shutil.copyfile(source,project/'continuation_cache.gd')
    return {'rollout_policy.gd':{'old':sha(old),'new':sha(new)},'continuation_cache.gd':{'old':None,'new':sha(source.read_bytes())}}

def canonical(data):
    rows=[json.loads(x) for x in data.splitlines()]
    require(rows[0]['kind']=='header' and rows[-1]['kind']=='terminal','OUTCOME_ENVELOPE')
    for r in rows[1:-1]:
        require(r['kind']=='outcome' and 'run_usec' in r and 'query_usec' in r,'TIMING_FIELDS')
        del r['run_usec'];del r['query_usec']
    return (json.dumps(rows,sort_keys=True,separators=(',',':'))+'\n').encode()

def compare_cell(old,new):
    a=lzma.decompress((old/(STEM+'.outcomes.jsonl.xz')).read_bytes())
    b=lzma.decompress((new/(STEM+'.outcomes.jsonl.xz')).read_bytes())
    require(canonical(a)==canonical(b),'ENDPOINT_POLICY_SCORE_OR_DECISION_MISMATCH')
    x=lzma.decompress((old/(STEM+'.traces.jsonl.xz')).read_bytes())
    y=lzma.decompress((new/(STEM+'.traces.jsonl.xz')).read_bytes())
    require(x==y,'COMPLETE_NATIVE_TRACE_MISMATCH')
    r=json.loads((new/(STEM+'.RECEIPT.json')).read_bytes());require(r['status']=='COMPLETE' and r['rows']==8,'CELL_COMPLETENESS')
    return {'raw_trace_sha256':sha(y),'canonical_outcome_sha256':sha(canonical(b)),
            'cpu_seconds':r['cpu']['user']+r['cpu']['system'],'elapsed_seconds':r['cpu']['elapsed']}

def read(repo,out):
    old=repo/P/'value-v1/execution-2/v5/planner'
    qual=out/'original-qualification/raw'
    cases=0
    for mode in MODES:
        expected=(qual/(mode+'.jsonl')).read_bytes()
        actual=(out/'qualification'/(mode+'.jsonl')).read_bytes()
        require(actual==expected,'QUALIFICATION_OUTPUT:'+mode)
        rows=[json.loads(x) for x in actual.splitlines()]
        require(rows[-1]=={'kind':'terminal','cases':96,'failed_checks':0},'QUALIFICATION_COMPLETE')
        cases+=96
    good=[json.loads(x) for x in (out/'qualification/cache-lifecycle.jsonl').read_bytes().splitlines()]
    bad=[json.loads(x) for x in (out/'qualification/stale-mutant.jsonl').read_bytes().splitlines()]
    require(good[-1]=={'kind':'terminal','cases':24,'failures':0},'CACHE_SCOPE_LIFECYCLE')
    require(bad[-1]['cases']==24 and bad[-1]['failures']>0,'STALE_CACHE_MUTANT_NOT_KILLED')
    timings={};ratios=[]
    for repetition in (0,1):
        timings[str(repetition)]={}
        for method in ('reference','memo'):
            timings[str(repetition)][method]=compare_cell(old,out/f'r{repetition}-{method}')
        pair=timings[str(repetition)]
        require(pair['reference']['cpu_seconds']>0,'POSITIVE_REFERENCE_COST')
        ratios.append(pair['memo']['cpu_seconds']/pair['reference']['cpu_seconds'])
    faster=all(r<=0.85 for r in ratios)
    return {'kind':'EXACT_CONTINUATION_QUERY_MEMOISATION','status':'EXACT_CONTINUATION_CACHE_SPEEDUP_ESTABLISHED' if faster else 'EXACT_EQUIVALENCE_SPEEDUP_NOT_ESTABLISHED',
            'qualification_cases':cases,'cache_lifecycle_cases':24,'stale_mutant_failures':bad[-1]['failures'],
            'all_qualification_bytes_equal':True,'all_native_trace_bytes_equal':True,
            'all_endpoint_policy_and_score_values_equal':True,'excluded_fields':['top-level run_usec','top-level query_usec'],
            'timings':timings,'memo_reference_cpu_ratios':ratios,'maximum_ratio_required':0.85,
            'old_resource_terminal_unchanged':True,'old_3600_second_limit_changed':False,
            'resource_ceiling_requalified_for_full_workload':False,'new_native_outcome_samples':0,
            'scope':'Two alternating repetitions of one preassigned old eight-run cell. Same-decision delivery benchmark, not population confirmation, whole-workload timing or package admission.',
            'new_independent_samples':0,'packages_admitted':0,'p9_certified':False}

def run(repo,engine,out):
    repo,engine,out=map(lambda x:Path(x).resolve(),(repo,engine,out))
    require(not out.exists(),'OUTPUT_EXISTS_NO_RERUN');out.mkdir(parents=True)
    p=json.loads((HERE/'PROTOCOL.json').read_bytes())
    for name,digest in p['source_sha256'].items():require(sha((HERE/name).read_bytes())==digest,'OWN_SOURCE:'+name)
    require(sha(engine.read_bytes())==ENGINE,'PINNED_ENGINE')
    original=repo/P/'value-v1/execution-2'
    files=(original/'FILES.json').read_bytes();require(sha(files)==WORKLOAD_FILES,'ORIGINAL_WORKLOAD_MANIFEST')
    entries={r['path']:r for r in json.loads(files)}
    sys.path.insert(0,str(repo/P/'value-v1/repaired-source-1'))
    value=load('exact_value_experiment',repo/P/'value-v1/repaired-source-1/experiment.py')
    base,reader,binder=value.dependencies(repo)
    terminal={'status':'INCONCLUSIVE','packages_admitted':0,'p9_certified':False}
    try:
        oldq=repo/P/'execution-2';qmanifest=json.loads((oldq/'ARCHIVE.json').read_bytes())
        unpack(oldq/'capture.tar.xz',out/'original-qualification',qmanifest['files'],QUAL_ARCHIVE)
        manifest=json.loads((original/'planner-source/FINAL-SOURCE-MANIFEST.json').read_bytes())
        require(sha((original/'planner-source/FINAL-SOURCE-MANIFEST.json').read_bytes())==entries['planner-source/FINAL-SOURCE-MANIFEST.json']['sha256'],'RUNTIME_MANIFEST')
        records=[dict(path=name,**r) for name,r in manifest.items()]
        unpack(original/'planner-source/bound-runtime.tar.xz',out/'reference',records,entries['planner-source/bound-runtime.tar.xz']['sha256'])
        shutil.copytree(out/'reference',out/'memo')
        delta=patch(out/'memo',HERE/'continuation_cache.gd')
        qprojects={}
        for name in ('baseline','candidate'):
            target=out/('qual-'+name)
            shutil.copytree(out/'original-qualification/assembly'/name,target)
            patch(target,HERE/'continuation_cache.gd');qprojects[name]=target
        # The helper mutation test uses the bound actual runtime and complete snapshots.
        shutil.copyfile(HERE/'cache_gate.gd',out/'memo/cache_gate.gd')
        shutil.copytree(out/'memo',out/'stale-mutant')
        mutant=out/'stale-mutant/continuation_cache.gd'
        source=mutant.read_text();require(source.count(' _memo.clear()')==2,'CACHE_LIFETIME_ANCHORS')
        mutant.write_text(source.replace(' _memo.clear()',' pass # deliberate stale-cache negative',2))
        save(out/'SOURCE-DELTA.json',delta)
        save(out/'GENERATED-SOURCE-MANIFEST.json',{
            str(x.relative_to(out)):{'bytes':x.stat().st_size,'sha256':sha(x.read_bytes())}
            for name in ('reference','memo','qual-baseline','qual-candidate','stale-mutant')
            for x in sorted((out/name).rglob('*')) if x.is_file() and '.godot' not in x.parts})
        logs=out/'qualification';logs.mkdir()
        # New sources are parsed in the actual assembled project, before test execution.
        for name in ('reference','memo','qual-baseline','qual-candidate','stale-mutant'):
            project=out/name
            base.command([str(engine),'--headless','--path',str(project),'--import'],logs,name+'-import')
            base.command(['env','GODOT='+str(engine),'bash','tools/check_scripts.sh',*sorted(f.name for f in project.glob('*.gd'))],logs,name+'-parse',cwd=project)
        for mode in MODES:
            target=qprojects['baseline' if mode=='baseline' else 'candidate']
            base.command([str(engine),'--headless','--path',str(target),'-s','res://decision_gate.gd','--',mode,str(logs/(mode+'.jsonl'))],logs,mode)
            require((logs/(mode+'.jsonl')).read_bytes()==(out/'original-qualification/raw'/(mode+'.jsonl')).read_bytes(),'PREBENCHMARK_FULL_EQUIVALENCE:'+mode)
        base.command([str(engine),'--headless','--path',str(out/'memo'),'-s','res://cache_gate.gd','--',str(logs/'cache-lifecycle.jsonl')],logs,'cache-lifecycle')
        args=[str(engine),'--headless','--path',str(out/'stale-mutant'),'-s','res://cache_gate.gd','--',str(logs/'stale-mutant.jsonl')]
        with (logs/'stale-mutant.stdout').open('wb') as a,(logs/'stale-mutant.stderr').open('wb') as b:
            test=subprocess.run(args,stdout=a,stderr=b,timeout=120,env=dict(os.environ,GODOT_SILENCE_ROOT_WARNING='1'))
        require(test.returncode==3 and b'ERROR:' not in (logs/'stale-mutant.stderr').read_bytes(),'NEGATIVE_CONTROL_EXIT')
        save(logs/'MUTATION.json',{'returncode':test.returncode,'expected_returncode':3})
        q=json.loads((original/'RESOLVED-PROTOCOLS.json').read_bytes())['planner']
        cfg=json.loads((original/'v5/planner'/(STEM+'.config.json')).read_bytes())
        require(cfg['first']==0 and cfg['count']==2 and cfg['vow']==5 and len(cfg['seeds'])==4,'PREASSIGNED_CELL')
        # Fixed AB/BA order; no parallel timing comparisons or outcome-based selection.
        for repetition in (0,1):
            for method in (('reference','memo') if repetition==0 else ('memo','reference')):
                folder=out/f'r{repetition}-{method}';folder.mkdir()
                receipt=value.cell(cfg,out/method,engine,folder,q,base,reader)
                require(receipt['status']=='COMPLETE','BENCHMARK_CELL')
                compare_cell(original/'v5/planner',folder)
        result=read(repo,out);save(out/'RESULTS.json',result)
        terminal.update(status=result['status'],qualification_cases=480,delivery_benchmark_cell_runs=4)
    except Exception as exc:terminal['failure']=repr(exc)
    save(out/'TERMINAL.json',terminal);print(json.dumps(terminal,indent=2))
    return 3 if terminal['status']=='INCONCLUSIVE' else 0

if __name__=='__main__':
    if sys.argv[1]=='run':raise SystemExit(run(*sys.argv[2:]))
    elif sys.argv[1]=='read':print(json.dumps(read(Path(sys.argv[2]),Path(sys.argv[3])),indent=2))
    else:raise SystemExit('run REPO ENGINE OUTPUT | read REPO OUTPUT')
