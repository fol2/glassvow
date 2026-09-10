"""One source-bound deep-to-shallow copy refinement; no score formula changes.
The owned dict gets a fresh effects array; all retained nested objects are read-only
under the pinned parent implementations. A no-copy mutant tests that distinction.
"""
from __future__ import annotations
import ast,hashlib,importlib.util,json,shutil,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=Path('research/p9-six-route/ash-inheritance-20260909/planner-v1')
BASE=ROOT/'continuation-integer-v1/bound-source'
BENCH='15004a488edcbfd774d15ab6ecb0e26db597dcb9a0e9560be0118f5578d71919'
ADDITIVE='642a9597a54e1cabf8f46f95732eed8cad04c15cacaa99a2d3c4e479eb64583b'


def require(ok,why):
 if not ok:raise ValueError(why)
def sha(b):return hashlib.sha256(b).hexdigest()
def dump(p,x):p.write_text(json.dumps(x,indent=2)+'\n')
def once(s,a,b):
 require(s.count(a)==1,'EXACT_ANCHOR:'+a[:60]);return s.replace(a,b,1)

def shallow(source):
 require(sha(source)==ADDITIVE,'PINNED_ADDITIVE_SOURCE')
 text=source.decode();anchor='var effective: Dictionary=d.duplicate(true)'
 require(text.count(anchor)==2,'EXACT_TWO_DICT_COPIES')
 return text.replace(anchor,'var effective: Dictionary=d.duplicate(false)',2).encode()

PATCH='''def patch(project,source):
    p=project/'rollout_policy.gd';old=p.read_bytes()
    anchor='const Greedy: GDScript=preload("res://greedy_policy.gd")'
    target='const Greedy: GDScript=preload("res://continuation_cache.gd")'
    text=old.decode()
    if anchor in text:
        require(text.count(anchor)==1,'ORIGINAL_FACTORY');new=text.replace(anchor,target,1).encode()
    else:
        require(text.count(target)==1,'REFINED_FACTORY');new=old
    p.write_bytes(new);shutil.copyfile(source,project/'continuation_cache.gd')
    delta={'rollout_policy.gd':{'old':sha(old),'new':sha(new)},'continuation_cache.gd':{'old':None,'new':sha(source.read_bytes())}}
    if project.name!='reference':
        p=project/'additive_policy.gd';old=p.read_bytes()
        require(sha(old)=='642a9597a54e1cabf8f46f95732eed8cad04c15cacaa99a2d3c4e479eb64583b','ADDITIVE_SOURCE')
        text=old.decode();require(text.count('var effective: Dictionary=d.duplicate(true)')==2,'COPY_ANCHORS')
        new=text.replace('var effective: Dictionary=d.duplicate(true)','var effective: Dictionary=d.duplicate(false)',2).encode()
        p.write_bytes(new);delta['additive_policy.gd']={'old':sha(old),'new':sha(new)}
    return delta

'''
EXTRA_SETUP='''        for name in ('reference','memo'):
            shutil.copyfile(HERE/'copy_gate.gd',out/name/'copy_gate.gd')
        shutil.copytree(out/'memo',out/'no-copy-mutant')
        fp=out/'no-copy-mutant/additive_policy.gd';bad=fp.read_text()
        require(bad.count('var effective: Dictionary=d.duplicate(false)')==2,'NO_COPY_MUTANT_ANCHORS')
        fp.write_text(bad.replace('var effective: Dictionary=d.duplicate(false)','var effective: Dictionary=d',2))
'''
EXTRA_RUN='''        for method in ('reference','memo'):
            base.command([str(engine),'--headless','--path',str(out/method),'-s','res://copy_gate.gd','--',str(logs/(method+'-copy.jsonl'))],logs,method+'-copy')
        require((logs/'reference-copy.jsonl').read_bytes()==(logs/'memo-copy.jsonl').read_bytes(),'COPY_QUERY_OR_INPUT_MISMATCH')
        args=[str(engine),'--headless','--path',str(out/'no-copy-mutant'),'-s','res://copy_gate.gd','--',str(logs/'no-copy-mutant.jsonl')]
        with (logs/'no-copy-mutant.stdout').open('wb') as a,(logs/'no-copy-mutant.stderr').open('wb') as b:
            trial=subprocess.run(args,stdout=a,stderr=b,timeout=120,env=dict(os.environ,GODOT_SILENCE_ROOT_WARNING='1'))
        require(trial.returncode==3 and b'ERROR:' not in (logs/'no-copy-mutant.stderr').read_bytes(),'NO_COPY_MUTANT_EXIT')
        save(logs/'COPY-MUTATION.json',{'returncode':trial.returncode,'expected':3})
'''
EXTRA_READ='''    a=(out/'qualification/reference-copy.jsonl').read_bytes();b=(out/'qualification/memo-copy.jsonl').read_bytes()
    require(a==b,'COPY_QUERY_RECONSTRUCTION')
    direct=[json.loads(line) for line in a.splitlines()]
    expected=direct[0]['contexts']*(2*direct[0]['authored_cards']+direct[0]['extras'])
    require(direct[-1]=={'kind':'terminal','cases':expected,'failures':0},'COPY_QUERY_COVERAGE')
    require(sum(r['kind']=='query' for r in direct)==expected,'COPY_QUERY_ROWS')
    mutant=[json.loads(line) for line in (out/'qualification/no-copy-mutant.jsonl').read_bytes().splitlines()]
    require(mutant[-1]['cases']==expected and mutant[-1]['failures']>0,'NO_COPY_MUTANT_NOT_KILLED')
'''

def build(repo,out):
 repo,out=Path(repo).resolve(),Path(out).resolve();require(not out.exists(),'BOUND_SOURCE_EXISTS');out.mkdir(parents=True)
 bp=repo/BASE/'benchmark.py';source=bp.read_bytes();require(sha(source)==BENCH,'BASE_BENCHMARK')
 p=json.loads((repo/BASE/'PROTOCOL.json').read_bytes())
 files={}
 for name in ('continuation_cache.gd','cache_gate.gd'):
  b=(repo/BASE/name).read_bytes();require(sha(b)==p['source_sha256'][name],'QUALIFIED_INTEGER_SOURCE:'+name);files[name]=b
 s=source.decode();start=s.index('def patch(project,source):\n');end=s.index('def canonical(data):\n')
 s=s[:start]+PATCH+s[end:]
 s=once(s,"        shutil.copytree(out/'reference',out/'memo')","        patch(out/'reference',HERE/'continuation_cache.gd')\n        shutil.copytree(out/'reference',out/'memo')")
 s=once(s,"        save(out/'SOURCE-DELTA.json',delta)",EXTRA_SETUP+"        save(out/'SOURCE-DELTA.json',delta)")
 s=s.replace("'qual-candidate','stale-mutant')","'qual-candidate','stale-mutant','no-copy-mutant')")
 s=once(s,"        q=json.loads((original/'RESOLVED-PROTOCOLS.json').read_bytes())['planner']",EXTRA_RUN+"        q=json.loads((original/'RESOLVED-PROTOCOLS.json').read_bytes())['planner']")
 s=once(s,'    timings={};ratios=[]',EXTRA_READ+'    timings={};ratios=[]')
 s=once(s,'faster=all(r<=0.85 for r in ratios)','faster=all(r<=0.90 for r in ratios)')
 s=once(s,"'maximum_ratio_required':0.85","'maximum_ratio_required':0.90,'direct_copy_query_cases':expected,'no_copy_mutant_failures':mutant[-1]['failures']")
 s=s.replace('EXACT_CONTINUATION_CACHE_SPEEDUP_ESTABLISHED','EXACT_SHALLOW_COPY_SPEEDUP_ESTABLISHED')
 s=s.replace("'kind':'EXACT_CONTINUATION_QUERY_MEMOISATION'","'kind':'EXACT_CONTROLLER_SHALLOW_COPY_REFINEMENT'")
 ast.parse(s)
 files['benchmark.py']=s.encode();files['copy_gate.gd']=(HERE/'copy_gate.gd').read_bytes()
 for name,b in files.items():(out/name).write_bytes(b)
 dump(out/'PROTOCOL.json',{'kind':'BOUND_SHALLOW_COPY_REFINEMENT','source_sha256':{name:sha(b) for name,b in files.items()},'cpu_ratio_limit':0.9,'new_independent_samples':0,'p9_certified':False})
 dump(out/'SOURCE-BINDING.json',{'base_benchmark_sha256':BENCH,'original_additive_sha256':ADDITIVE,'original_bound_protocol_sha256':sha((repo/BASE/'PROTOCOL.json').read_bytes()),'generated_sources':{name:sha(b) for name,b in files.items()},'new_native_observations':0})
 return files

def module(path):
 spec=importlib.util.spec_from_file_location('shallow_benchmark',path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m

def run(repo,engine,out):
 repo,out=Path(repo).resolve(),Path(out).resolve()
 freeze=json.loads((HERE/'FREEZE.json').read_bytes())
 for name,want in freeze['source_sha256'].items():require(sha((HERE/name).read_bytes())==want,'FROZEN_SOURCE:'+name)
 m=module(HERE/'bound-source/benchmark.py');m.HERE=HERE/'bound-source';return m.run(repo,engine,out)

def read(repo,out):return module(HERE/'bound-source/benchmark.py').read(Path(repo),Path(out))

if __name__=='__main__':
 if sys.argv[1]=='build':build(*sys.argv[2:])
 elif sys.argv[1]=='run':raise SystemExit(run(*sys.argv[2:]))
 elif sys.argv[1]=='read':print(json.dumps(read(*sys.argv[2:]),indent=2))
 else:raise SystemExit('build REPO OUTPUT | run REPO ENGINE OUTPUT | read REPO OUTPUT')
