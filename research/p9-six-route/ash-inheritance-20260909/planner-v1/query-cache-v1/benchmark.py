"""Bounded computational equivalence regression on preserved qualification cases.
No old research panel, policy selection, new reward law or P9 admission.
"""
from __future__ import annotations
import hashlib,io,json,os,shutil,subprocess,sys,tarfile,time
from pathlib import Path

P=Path('research/p9-six-route/ash-inheritance-20260909/planner-v1')
HERE=Path(__file__).resolve().parent
MODES=('baseline','active','off','producer_off','consumer_off')
ENGINE='8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e'
GREEDY='2512e45d942886346acefb0781014f724341c6575560a4489090f188be628214'


def require(ok,why):
 if not ok:raise ValueError(why)
def sha(b):return hashlib.sha256(b).hexdigest()
def save(p,x):p.write_text(json.dumps(x,indent=2)+'\n')

def unpack(execution,target):
 m=json.loads((execution/'ARCHIVE.json').read_bytes());raw=(execution/'capture.tar.xz').read_bytes()
 require(sha(raw)==m['archive_sha256'] and len(raw)==m['archive_bytes'],'INPUT_ARCHIVE')
 expected={r['path']:r for r in m['files']};require(len(expected)==len(m['files']),'DUPLICATE_INPUT')
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz') as t:
  members=t.getmembers();require(len(members)==len(expected) and {x.name for x in members}==set(expected),'INPUT_MEMBERS')
  for member in members:
   path=Path(member.name);require(member.isfile() and not path.is_absolute() and '..' not in path.parts,'PATH')
   data=t.extractfile(member).read();r=expected[member.name]
   require(len(data)==r['bytes'] and sha(data)==r['sha256'],'INPUT_MEMBER:'+member.name)
   p=target/path;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
 return m

def patch(project,adapter):
 target=project/'greedy_policy.gd';old=target.read_bytes();require(sha(old)==GREEDY,'EXACT_EVALUATOR')
 require(not (project/'uncached_greedy_policy.gd').exists(),'NEW_CARRIER_COLLISION')
 (project/'uncached_greedy_policy.gd').write_bytes(old);target.write_bytes(adapter)


def command(argv,out,label,cwd=None):
 start=time.monotonic()
 with (out/(label+'.stdout')).open('wb') as so,(out/(label+'.stderr')).open('wb') as se:
  try:r=subprocess.run(argv,cwd=cwd,stdout=so,stderr=se,timeout=180,env=dict(os.environ,GODOT_SILENCE_ROOT_WARNING='1'));rc=r.returncode
  except subprocess.TimeoutExpired:rc=None
 error=(out/(label+'.stderr')).read_bytes()
 record={'argv':argv,'returncode':rc,'elapsed':time.monotonic()-start,'diagnostic_error':b'ERROR:' in error or b'Failed to load script' in error}
 save(out/(label+'.command.json'),record)
 require(rc==0 and not record['diagnostic_error'],'NATIVE_OR_COMPILER_DIAGNOSTIC:'+label)
 return record


def readout(folder):
 folder=Path(folder);p=json.loads((folder/'PROTOCOL.json').read_bytes())
 costs={m:[] for m in ('reference','memo')};count=0;identities=[]
 for repeat in (0,1):
  sums={'reference':0.0,'memo':0.0}
  for mode in MODES:
   reference=(folder/'expected'/(mode+'.jsonl')).read_bytes()
   for method in ('reference','memo'):
    name=f'r{repeat}-{mode}-{method}';data=(folder/'raw'/(name+'.jsonl')).read_bytes()
    require(data==reference,'EXACT_QUALIFICATION_REPLAY:'+name)
    cells=[json.loads(x) for x in data.splitlines()]
    require(cells[-1]['cases']==96 and cells[-1]['failed_checks']==0,'QUALIFICATION_GATE')
    numbers=[float(x) for x in (folder/'logs'/(name+'.cpu.txt')).read_text().split()]
    require(len(numbers)==3 and all(x>=0 for x in numbers),'COST')
    sums[method]+=numbers[0]+numbers[1];count+=96
    identities.append({'path':'raw/'+name+'.jsonl','bytes':len(data),'sha256':sha(data),'cpu_seconds':numbers[0]+numbers[1],'elapsed_seconds':numbers[2]})
  for method in sums:costs[method].append(sums[method])
 ratios=[b/a for a,b in zip(costs['reference'],costs['memo'])]
 return {'kind':'QUERY_LOCAL_MEMOISATION_EQUIVALENCE_AND_COST_REGRESSION','status':'EXACT_EQUIVALENCE_AND_BENCHMARK_SPEEDUP' if all(x<1 for x in ratios) else 'EXACT_EQUIVALENCE_SPEEDUP_NOT_ESTABLISHED',
  'equivalence_cases':count,'all_raw_bytes_equal_preserved_qualification':True,'cpu_seconds_by_repetition':costs,'memo_reference_ratios':ratios,
  'raw':identities,'whole_run_resource_ceiling_requalified':False,'original_value_terminal_overridden':False,
  'same_policy_values_actions_and_native_states':True,'old_v25_study_repeated':False,
  'scope':'Two fixed alternating repetitions of the existing finite qualification matrix; this proves these exact input/output regressions and measured local compute only.',
  'limits':['General equivalence additionally depends on the bound source argument that no native state/content changes within greedy choose_action.',
   'No extrapolated CPU prediction admits the already failed full-workload resource contract.',
   'Performance regression cases are not new independent package samples; no V0 or pair-support stage is opened.'],
  'new_native_benchmark_invocations':20,'new_independent_samples':0,'packages_admitted':0,'p9_certified':False}


def run(repo,engine,out):
 repo=Path(repo).resolve();engine=Path(engine).resolve();out=Path(out).resolve()
 require(not out.exists(),'OUTPUT_EXISTS');out.mkdir(parents=True)
 require(sha(engine.read_bytes())==ENGINE,'ENGINE')
 frozen=json.loads((HERE/'FREEZE.json').read_bytes())
 for name,want in frozen['sources'].items():require(sha((HERE/name).read_bytes())==want,'SOURCE_FREEZE:'+name)
 protocol=json.loads((HERE/'PROTOCOL.json').read_bytes());shutil.copyfile(HERE/'PROTOCOL.json',out/'PROTOCOL.json')
 terminal={'status':'INCONCLUSIVE','p9_certified':False,'packages_admitted':0}
 try:
  prior=repo/P/'execution-2'
  require(json.loads((prior/'TERMINAL.json').read_bytes())['status']=='PLANNER_CURRENT_RUNTIME_COMPATIBILITY_PASS','QUALIFIED_INPUT')
  rb=json.loads((prior/'REMOTE-READBACK.json').read_bytes());require(rb['all_bytes_equal'] and rb['readout_reproduced'],'PRIOR_BYTE_VERIFICATION')
  origin=out/'preserved';unpack(prior,origin)
  (out/'expected').mkdir();(out/'raw').mkdir();(out/'logs').mkdir()
  for mode in MODES:shutil.copyfile(origin/'raw'/(mode+'.jsonl'),out/'expected'/(mode+'.jsonl'))
  adapter=(HERE/'greedy_policy.gd').read_bytes();runtimes={}
  for method in ('reference','memo'):
   runtimes[method]={}
   for name in ('baseline','candidate'):
    dst=out/'runtime'/method/name;shutil.copytree(origin/'assembly'/name,dst)
    require(not (dst/'.godot').exists(),'NO_GENERATED_CACHE_INPUT')
    if method=='memo':patch(dst,adapter)
    runtimes[method][name]=dst
  save(out/'RUNTIME-SOURCE-MANIFEST.json',{str(p.relative_to(out)):{'bytes':p.stat().st_size,'sha256':sha(p.read_bytes())} for p in sorted((out/'runtime').rglob('*')) if p.is_file()})
  for method,projects in runtimes.items():
   for name,project in projects.items():
    command([str(engine),'--headless','--path',str(project),'--import'],out/'logs',method+'-'+name+'-import')
    command(['env','GODOT='+str(engine),'bash','tools/check_scripts.sh',*sorted(p.name for p in project.glob('*.gd'))],out/'logs',method+'-'+name+'-parse',cwd=project)
  for repeat in (0,1):
   for index,mode in enumerate(MODES):
    methods=('reference','memo') if (repeat+index)%2==0 else ('memo','reference')
    for method in methods:
     project=runtimes[method]['baseline' if mode=='baseline' else 'candidate'];label=f'r{repeat}-{mode}-{method}'
     command(['/usr/bin/time','-f','%U %S %e','-o',str(out/'logs'/(label+'.cpu.txt')),str(engine),'--headless','--path',str(project),'-s','res://decision_gate.gd','--',mode,str(out/'raw'/(label+'.jsonl'))],out/'logs',label)
     require((out/'raw'/(label+'.jsonl')).stat().st_size<=67108864,'RAW_CAP')
  result=readout(out);save(out/'RESULTS.json',result);terminal.update(status=result['status'],equivalence_cases=result['equivalence_cases'])
 except Exception as exc:terminal['failure']=repr(exc)
 save(out/'TERMINAL.json',terminal);print(json.dumps(terminal,indent=2))
 return 3 if terminal['status']=='INCONCLUSIVE' else 0

if __name__=='__main__':
 if sys.argv[1]=='run':raise SystemExit(run(*sys.argv[2:]))
 else:print(json.dumps(readout(sys.argv[2]),indent=2))
