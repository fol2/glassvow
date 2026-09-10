"""Frozen four-cell implementation benchmark, using existing full captures only."""
from __future__ import annotations
import hashlib, importlib.util, json, lzma, math, os, shutil, subprocess, sys, tarfile
from pathlib import Path
import refine

HERE=Path(__file__).resolve().parent
P=refine.REL
CELLS=('v5-000','v5-032','v5-064','v5-096')
METHODS=('reference','refined')
ENGINE='8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e'
CONTENT='a0d608a5142d2e3aab799cdf33d3163922b402c2aaf2a895e46e096399b56cf1'
require,sha=refine.require,refine.sha

def save(path,value):
    path.write_text(json.dumps(value,indent=2)+'\n')

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod);return mod

def blob(data):
    return hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()

def dependencies(repo):
    paths={'continuation-cache-v1/benchmark.py':'5d8a0dfc11a003c62cd5cd1305a659d3909a081a',
           'value-v1/repaired-source-1/experiment.py':'4a53245727489203100e71545af15b806046dc34'}
    for path,want in paths.items():require(blob((repo/P/path).read_bytes())==want,'DEPENDENCY:'+path)
    sys.path.insert(0,str(repo/P/'value-v1/repaired-source-1'))
    value=load('float_fixed_value',repo/P/'value-v1/repaired-source-1/experiment.py')
    base,reader,binder=value.dependencies(repo)
    bench=load('float_fixed_benchmark',repo/P/'continuation-cache-v1/benchmark.py')
    return value,base,reader,bench

def numeric_read(path,reference_hash,refined_hash):
    raw=lzma.decompress(path.read_bytes()) if path.suffix=='.xz' else path.read_bytes()
    rows=[json.loads(line) for line in raw.splitlines()]
    require(rows[0]['kind']=='header' and rows[-1]['kind']=='terminal','NUMERIC_ENVELOPE')
    h,t=rows[0],rows[-1];records=rows[1:-1]
    require(h['engine']=='4.7.2-stable (official)' and h['content_sha256']==CONTENT,'NUMERIC_SOURCE')
    require(h['reference_sha256']==reference_hash and h['refined_sha256']==refined_hash,'ACTUAL_NUMERIC_METHODS')
    require(len(records)==t['checks'] and t['failed']==0,'NUMERIC_COMPLETE')
    require(all(r['kind']=='conversion' and r['expected']==r['actual'] for r in records),'NUMERIC_EQUALITY')
    exhaustive=[r for r in records if r['category']=='exhaustive_float']
    require(len(exhaustive)==2049 and [r['expected'] for r in exhaustive]==list(range(-1024,1025))
            and all(r['type']==3 and float(r['input'])==r['expected'] for r in exhaustive),'COMPLETE_FLOAT_DOMAIN')
    unsafe=sum(r['unsafe']!=r['expected'] for r in records)
    require(unsafe==t['unsafe_counterexamples'] and unsafe>0,'UNSAFE_CAST_NEGATIVE')
    content=[r for r in records if r['category']=='pinned_content']
    require(len(content)==sum(t['content_numeric_types'].values()) and t['content_guard_eligible']>0,'CONTENT_TYPE_OBSERVATION')
    return {'status':'BOUNDED_FLOAT_CONVERSION_PASS','checks':len(records),'integral_float_domain':2049,
            'unsafe_counterexamples':unsafe,'content_numeric_types':t['content_numeric_types'],
            'content_guard_eligible':t['content_guard_eligible'],'raw_sha256':sha(raw),
            'raw_bytes':len(raw),'shim_only':False,'packages_admitted':0}

def compare_cell(old,new,stem,bench):
    a=lzma.decompress((old/(stem+'.outcomes.jsonl.xz')).read_bytes())
    b=lzma.decompress((new/(stem+'.outcomes.jsonl.xz')).read_bytes())
    require(bench.canonical(a)==bench.canonical(b),'FULL_ENDPOINT_DECISION_SCORE:'+stem)
    x=lzma.decompress((old/(stem+'.traces.jsonl.xz')).read_bytes())
    y=lzma.decompress((new/(stem+'.traces.jsonl.xz')).read_bytes())
    require(x==y,'FULL_NATIVE_TRACE:'+stem)
    receipt=json.loads((new/(stem+'.RECEIPT.json')).read_bytes())
    require(receipt['status']=='COMPLETE' and receipt['rows']==8,'COMPLETE_TIMING_CELL')
    cpu=receipt['cpu']['user']+receipt['cpu']['system']
    require(cpu>0 and math.isfinite(cpu),'FINITE_POSITIVE_COST')
    return {'cpu_seconds':cpu,'trace_sha256':sha(y),'canonical_outcome_sha256':sha(bench.canonical(b))}

def timing_decision(timings):
    require(set(timings)=={'0','1'},'REPETITION_COVERAGE')
    ratios=[];cell_ratios=[]
    for repetition in ('0','1'):
        rows=timings[repetition];require(set(rows)==set(CELLS),'CELL_COVERAGE')
        sums=dict.fromkeys(METHODS,0.0)
        for stem in CELLS:
            pair=rows[stem];require(set(pair)==set(METHODS),'METHOD_COVERAGE')
            for method in METHODS:
                v=pair[method]['cpu_seconds'];require(v>0 and math.isfinite(v),'FINITE_POSITIVE_COST');sums[method]+=v
            cell_ratios.append(pair['refined']['cpu_seconds']/pair['reference']['cpu_seconds'])
        ratios.append(sums['refined']/sums['reference'])
    return {'aggregate_ratios':ratios,'cell_ratios':cell_ratios,
            'pass':all(x<=0.90 for x in ratios) and all(x<=1.05 for x in cell_ratios)}

def read(repo,out):
    _,_,_,bench=dependencies(repo)
    bound=json.loads((out/'BOUND-SOURCE.json').read_bytes())
    numerical=numeric_read(out/'numeric/numeric.jsonl.xz',bound['reference_sha256'],bound['refined_sha256'])
    oldq=out/'original-qualification/raw';count=0
    for mode in bench.MODES:
        raw=(out/'qualification'/(mode+'.jsonl')).read_bytes()
        require(raw==(oldq/(mode+'.jsonl')).read_bytes(),'FULL_COMPATIBILITY:'+mode)
        require(json.loads(raw.splitlines()[-1])=={'kind':'terminal','cases':96,'failed_checks':0},'COMPATIBILITY_COUNT');count+=96
    for name,negative in [('cache-lifecycle',False),('stale-mutant',True)]:
        last=json.loads((out/'qualification'/(name+'.jsonl')).read_bytes().splitlines()[-1])
        require(last['kind']=='terminal' and last['cases']==24,'LIFECYCLE_COVERAGE')
        require(last['failures']>0 if negative else last['failures']==0,'LIFECYCLE_OR_MUTANT')
    timings={}
    old=repo/P/'value-v1/execution-2/v5/planner'
    for rep in (0,1):
        timings[str(rep)]={stem:{method:compare_cell(old,out/f'r{rep}'/method,stem,bench) for method in METHODS} for stem in CELLS}
    decision=timing_decision(timings)
    return {'kind':'FOUR_FIXED_CELLS_EXACT_INTEGRAL_FLOAT_REFINEMENT',
            'status':'FLOAT_FASTPATH_BENCHMARK_PASS_NOT_RESOURCE_QUALIFICATION' if decision['pass'] else 'FLOAT_FASTPATH_SPEED_NOT_ESTABLISHED',
            'numeric':numerical,'compatibility_cases':count,'cache_lifecycle_cases':24,
            'all_native_and_canonical_outputs_equal':True,'timings':timings,**decision,
            'old_resource_terminals_unchanged':True,'full_workload_resource_requalified':False,
            'new_independent_samples':0,'packages_admitted':0,'p9_certified':False}

def archive_tree(work,out):
    records=[]
    with tarfile.open(out/'runtime-source.tar.xz','w:xz') as tf:
        for f in sorted(work.rglob('*')):
            if not f.is_file() or '.godot' in f.parts:continue
            b=f.read_bytes();relative=str(f.relative_to(work))
            records.append({'path':relative,'bytes':len(b),'sha256':sha(b)})
            tf.add(f,arcname=relative,recursive=False)
    save(out/'RUNTIME-SOURCE.json',records)

def run(repo,engine,out,work,publish=False):
    repo,engine,out,work=map(lambda p:Path(p).resolve(),(repo,engine,out,work))
    require(not out.exists() and not work.exists(),'OUTPUT_EXISTS');out.mkdir(parents=True);work.mkdir(parents=True)
    value,base,reader,bench=dependencies(repo);head=base.git(repo,'rev-parse','HEAD')
    terminal={'status':'INCONCLUSIVE','source_head':head,'packages_admitted':0,'p9_certified':False}
    try:
        require(sha(engine.read_bytes())==ENGINE,'ENGINE')
        require(sha((repo/'content/full-content.json').read_bytes())==CONTENT,'PINNED_CONTENT')
        frozen=json.loads((HERE/'SOURCE-FREEZE.json').read_bytes())
        for name,digest in frozen['sources'].items():require(sha((HERE/name).read_bytes())==digest,'OWN_SOURCE:'+name)
        bound=refine.build(repo,out/'bound-source');save(out/'BOUND-SOURCE.json',bound)
        old=repo/P/'value-v1/execution-2';fm=(old/'FILES.json').read_bytes();require(sha(fm)==bench.WORKLOAD_FILES,'ORIGINAL_MANIFEST')
        entries={r['path']:r for r in json.loads(fm)}
        manifest_path=old/'planner-source/FINAL-SOURCE-MANIFEST.json';require(sha(manifest_path.read_bytes())==entries['planner-source/FINAL-SOURCE-MANIFEST.json']['sha256'],'RUNTIME_MANIFEST')
        records=[dict(path=name,**r) for name,r in json.loads(manifest_path.read_bytes()).items()]
        bench.unpack(old/'planner-source/bound-runtime.tar.xz',work/'reference',records,entries['planner-source/bound-runtime.tar.xz']['sha256'])
        shutil.copytree(work/'reference',work/'refined')
        bench.patch(work/'reference',out/'bound-source/reference_cache.gd')
        bench.patch(work/'refined',out/'bound-source/continuation_cache.gd')
        qold=repo/P/'execution-2';qm=json.loads((qold/'ARCHIVE.json').read_bytes())
        bench.unpack(qold/'capture.tar.xz',out/'original-qualification',qm['files'],bench.QUAL_ARCHIVE)
        for label in ('baseline','candidate'):
            shutil.copytree(out/'original-qualification/assembly'/label,work/('qual-'+label))
            bench.patch(work/('qual-'+label),out/'bound-source/continuation_cache.gd')
        gate=(repo/P/'continuation-integer-v1/bound-source/cache_gate.gd').read_bytes()
        require(sha(gate)=='e045f48f80725a313afb168d98e077ea0d991de1598e9a47d60a85bdb6643d40','LIFECYCLE_GATE')
        (work/'refined/cache_gate.gd').write_bytes(gate)
        shutil.copytree(work/'refined',work/'stale-mutant')
        path=work/'stale-mutant/continuation_cache.gd';text=path.read_text();require(text.count(' _memo.clear()')==2,'MUTANT_ANCHOR')
        path.write_text(text.replace(' _memo.clear()',' pass # preserved stale-cache negative',2))
        # Numerical tests call the complete real reference/refined classes, not the local shims.
        shutil.copyfile(out/'bound-source/reference_cache.gd',work/'refined/reference_ji.gd')
        shutil.copyfile(out/'bound-source/continuation_cache.gd',work/'refined/refined_ji.gd')
        shutil.copyfile(HERE/'numeric_gate.gd',work/'refined/numeric_gate.gd')
        archive_tree(work,out)
        if publish:head=base.publish(repo,out,head,'research(p9): freeze actual float refinement runtimes before observations')
        logs=out/'qualification';logs.mkdir();numeric=out/'numeric';numeric.mkdir()
        for label in ('reference','refined','qual-baseline','qual-candidate','stale-mutant'):
            project=work/label
            base.command([str(engine),'--headless','--path',str(project),'--import'],logs,label+'-import')
            base.command(['env','GODOT='+str(engine),'bash','tools/check_scripts.sh',*sorted(p.name for p in project.glob('*.gd'))],logs,label+'-parse',cwd=project)
        base.command([str(engine),'--headless','--path',str(work/'refined'),'-s','res://numeric_gate.gd','--',str(repo/'content/full-content.json'),str(numeric/'numeric.jsonl')],numeric,'numeric')
        nr=numeric_read(numeric/'numeric.jsonl',bound['reference_sha256'],bound['refined_sha256']);save(numeric/'RESULTS.json',nr)
        base.compress(numeric/'numeric.jsonl',{'raw_bytes_per_stream':536870912})
        for mode in bench.MODES:
            project=work/('qual-baseline' if mode=='baseline' else 'qual-candidate')
            base.command([str(engine),'--headless','--path',str(project),'-s','res://decision_gate.gd','--',mode,str(logs/(mode+'.jsonl'))],logs,mode)
            require((logs/(mode+'.jsonl')).read_bytes()==(out/'original-qualification/raw'/(mode+'.jsonl')).read_bytes(),'COMPATIBILITY:'+mode)
        base.command([str(engine),'--headless','--path',str(work/'refined'),'-s','res://cache_gate.gd','--',str(logs/'cache-lifecycle.jsonl')],logs,'cache-lifecycle')
        cmd=[str(engine),'--headless','--path',str(work/'stale-mutant'),'-s','res://cache_gate.gd','--',str(logs/'stale-mutant.jsonl')]
        with (logs/'stale-mutant.stdout').open('wb') as a,(logs/'stale-mutant.stderr').open('wb') as b:
            r=subprocess.run(cmd,stdout=a,stderr=b,timeout=120,env=dict(os.environ,GODOT_SILENCE_ROOT_WARNING='1'))
        require(r.returncode==3 and b'ERROR:' not in (logs/'stale-mutant.stderr').read_bytes(),'NEGATIVE_EXIT')
        save(logs/'MUTANT.json',{'argv':cmd,'returncode':r.returncode,'expected':3})
        if publish:head=base.publish(repo,out,head,'research(p9): preserve float-domain and full-state preflight before timings')
        p=json.loads((old/'RESOLVED-PROTOCOLS.json').read_bytes())['planner']
        for rep in (0,1):
            for method in METHODS:(out/f'r{rep}'/method).mkdir(parents=True)
            for stem in CELLS:
                cfg=json.loads((old/'v5/planner'/(stem+'.config.json')).read_bytes())
                require(cfg['first']==int(stem.split('-')[1]) and cfg['count']==2 and cfg['vow']==5,'FIXED_ASSIGNMENT')
                for method in (METHODS if rep==0 else tuple(reversed(METHODS))):
                    folder=out/f'r{rep}'/method
                    result=value.cell(cfg,work/method,engine,folder,p,base,reader);require(result['status']=='COMPLETE','TIMING_CELL')
                    compare_cell(old/'v5/planner',folder,stem,bench)
                if publish:head=base.publish(repo,out,head,f'research(p9): retain assigned float benchmark repetition {rep} {stem}')
        result=read(repo,out);save(out/'RESULTS.json',result);terminal['status']=result['status']
    except Exception as exc:terminal['failure']=repr(exc)
    finally:
        save(out/'TERMINAL.json',terminal)
        save(out/'FILES.json',[{'path':str(p.relative_to(out)),'bytes':p.stat().st_size,'sha256':sha(p.read_bytes())} for p in sorted(out.rglob('*')) if p.is_file() and p!=out/'FILES.json'])
        if publish:head=base.publish(repo,out,head,'research(p9): preserve complete float refinement terminal without promoting P9')
        if os.environ.get('GITHUB_ENV'):
            with open(os.environ['GITHUB_ENV'],'a') as f:f.write('PUBLISHED_HEAD='+head+'\n')
        print(json.dumps(terminal,indent=2))
    return 3 if terminal['status']=='INCONCLUSIVE' else 0

def verify(repo,original,cold,receipt):
    repo,original,cold,receipt=map(Path,(repo,original,cold,receipt))
    require(not receipt.exists(),'READBACK_EXISTS')
    entries=json.loads((original/'FILES.json').read_bytes())
    require((original/'FILES.json').read_bytes()==(cold/'FILES.json').read_bytes(),'MANIFEST_READBACK')
    require(len({r['path'] for r in entries})==len(entries),'DUPLICATE_CAPTURE_PATH')
    for row in entries:
        p=Path(row['path']);require(not p.is_absolute() and '..' not in p.parts,'PATH')
        data=(cold/p).read_bytes();require(data==(original/p).read_bytes() and len(data)==row['bytes'] and sha(data)==row['sha256'],'COLD_BYTE:'+str(p))
    terminal=json.loads((cold/'TERMINAL.json').read_bytes());reproduced=False
    if (cold/'RESULTS.json').exists():
        result=read(repo,cold);require((json.dumps(result,indent=2)+'\n').encode()==(cold/'RESULTS.json').read_bytes(),'READOUT_RECONSTRUCTION');reproduced=True
    save(receipt,{'kind':'FULL_FLOAT_FASTPATH_COLD_READBACK','files':len(entries)+1,'all_bytes_equal':True,
                  'readout_reproduced':reproduced,'scientific_status':terminal['status'],
                  'new_native_runs':0,'packages_admitted':0,'p9_certified':False})

if __name__=='__main__':
    if sys.argv[1]=='run':raise SystemExit(run(*sys.argv[2:6],publish='--publish' in sys.argv))
    elif sys.argv[1]=='verify':verify(*sys.argv[2:])
    elif sys.argv[1]=='read':print(json.dumps(read(Path(sys.argv[2]),Path(sys.argv[3])),indent=2))
    else:raise SystemExit('MODE')
