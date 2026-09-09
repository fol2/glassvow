"""Profile one already captured workload cell; preserve every semantic output.
No new candidate, seed, value test, or resource admission. Timing is write-only.
"""
from __future__ import annotations
import copy,hashlib,importlib.util,json,lzma,os,shutil,sys,tarfile
from pathlib import Path

P=Path('research/p9-six-route/ash-inheritance-20260909/planner-v1')
HERE=Path(__file__).resolve().parent
STEM='v5-000'
PERF='''extends RefCounted
static var totals: Dictionary = {}
static func record(name: String, elapsed: int) -> void:
 if not totals.has(name):totals[name]={"calls":0,"usec":0}
 totals[name]["calls"]+=1
 totals[name]["usec"]+=elapsed
static func result() -> Dictionary:
 return totals.duplicate(true)
'''

def require(ok,why):
 if not ok:raise ValueError(why)
def sha(b):return hashlib.sha256(b).hexdigest()
def save(p,x):p.write_text(json.dumps(x,indent=2)+'\n')
def once(s,a,b):
 require(s.count(a)==1,'EXACT_TIMING_ANCHOR:'+a[:50]);return s.replace(a,b,1)
def module(name,path):
 spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m

def instrument(project):
 manifest={}
 def change(name,fn):
  p=project/name;old=p.read_bytes();new=fn(old.decode()).encode();p.write_bytes(new)
  manifest[name]={'old_sha256':sha(old),'new_sha256':sha(new)}
 change('public_rollout.gd',lambda s:once(once(s,'static func clone_public(g: GlassvowGame, sample: int) -> GlassvowGame:\n','static func clone_public(g: GlassvowGame, sample: int) -> GlassvowGame:\n var profile_begin: int=Time.get_ticks_usec()\n'), ' return out\n',' preload("res://profile_clock.gd").record("clone",Time.get_ticks_usec()-profile_begin)\n return out\n'))
 change('public_rollout_base.gd',lambda s:once(s,'   obj.set(key,copy_value(v.get(key),memo))','''   if key=="map" and v is RunState:
    var profile_map_begin: int=Time.get_ticks_usec()
    obj.set(key,copy_value(v.get(key),memo))
    preload("res://profile_clock.gd").record("run_map_copy",Time.get_ticks_usec()-profile_map_begin)
   else:obj.set(key,copy_value(v.get(key),memo))'''))
 change('legacy_policy.gd',lambda s:once(once(s,'func choose_action(g: GlassvowGame) -> Dictionary:\n','func choose_action(g: GlassvowGame) -> Dictionary:\n var profile_begin: int=Time.get_ticks_usec()\n'), ' return {} if best<0 else aa[best]',' preload("res://profile_clock.gd").record("greedy",Time.get_ticks_usec()-profile_begin)\n return {} if best<0 else aa[best]'))
 change('rollout_policy.gd',lambda s:once(once(s,'func choose_action(g: GlassvowGame) -> Dictionary:\n','func choose_action(g: GlassvowGame) -> Dictionary:\n var profile_begin: int=Time.get_ticks_usec()\n'), ' return {} if best.get("t")=="endTurn" else best',' preload("res://profile_clock.gd").record("root",Time.get_ticks_usec()-profile_begin)\n return {} if best.get("t")=="endTurn" else best'))
 def leaf(s):
  s=once(s,'func future_value(g: GlassvowGame) -> float:','func profile_original_future_value(g: GlassvowGame) -> float:')
  return s+'''\nfunc future_value(g: GlassvowGame) -> float:
 var profile_begin: int=Time.get_ticks_usec()
 var answer: float=profile_original_future_value(g)
 preload("res://profile_clock.gd").record("leaf",Time.get_ticks_usec()-profile_begin)
 return answer
'''
 change('lab_policy.gd',leaf)
 change('probe.gd',lambda s:once(s,' output.close();traces.close();quit(0)',''' var profile_file: FileAccess=FileAccess.open(args[1]+".profile.json",FileAccess.WRITE)
 profile_file.store_string(JSON.stringify(preload("res://profile_clock.gd").result()))
 profile_file.close()
 output.close();traces.close();quit(0)'''))
 (project/'profile_clock.gd').write_text(PERF)
 manifest['profile_clock.gd']={'old_sha256':None,'new_sha256':sha(PERF.encode())}
 return manifest

def canonical_records(data,probe_sha):
 rows=[json.loads(x) for x in data.splitlines()]
 require(rows[0]['kind']=='header' and rows[0]['probe_sha256']==probe_sha,'BOUND_PROFILE_DRIVER')
 rows[0]['probe_sha256']='BOUND_DRIVER_IDENTITY_DIFFERENCE_ONLY'
 for r in rows[1:-1]:
  require(r['kind']=='outcome' and set(('run_usec','query_usec'))<=set(r),'PERFORMANCE_FIELDS')
  del r['run_usec'];del r['query_usec']
 return (json.dumps(rows,sort_keys=True,separators=(',',':'))+'\n').encode()

def compare(original,new,old_probe,new_probe):
 a=lzma.decompress((original/(STEM+'.outcomes.jsonl.xz')).read_bytes());b=lzma.decompress((new/(STEM+'.outcomes.jsonl.xz')).read_bytes())
 require(canonical_records(a,old_probe)==canonical_records(b,new_probe),'SEMANTIC_ENDPOINT_OR_DECISION_CHANGED')
 at=lzma.decompress((original/(STEM+'.traces.jsonl.xz')).read_bytes());bt=lzma.decompress((new/(STEM+'.traces.jsonl.xz')).read_bytes())
 require(at==bt,'FULL_NATIVE_TRACE_CHANGED')
 rows=[json.loads(x) for x in b.splitlines()][1:-1]
 q=sum(r['query_count'] for r in rows);rolls=sum(r['root_rollouts'] for r in rows)
 profile=json.loads((new/(STEM+'.outcomes.jsonl.profile.json')).read_bytes())
 require(profile['root']['calls']==q and profile['clone']['calls']==profile['leaf']['calls']==profile['run_map_copy']['calls']==rolls,'COMPLETE_TIMING_COVERAGE')
 root=profile['root']['usec'];accounted=sum(profile[k]['usec'] for k in ('clone','greedy','leaf'))
 require(root>0 and accounted<=root,'INCLUSIVE_TIME_PARTITION')
 require(profile['run_map_copy']['usec']<=profile['clone']['usec'],'NESTED_MAP_COST')
 receipt=json.loads((new/(STEM+'.RECEIPT.json')).read_bytes());require(receipt['status']=='COMPLETE','COMPLETE_CELL')
 return {'kind':'FIXED_OLD_CELL_COMPUTATION_PROFILE','outcomes':len(rows),'cell':STEM,'all_native_trace_bytes_equal':True,
 'all_endpoint_policy_and_decision_values_equal':True,'excluded_from_endpoint_comparison':['top-level run_usec','top-level query_usec','separately source-bound header probe_sha256'],
 'root_queries':q,'root_rollouts':rolls,'profile':profile,'unattributed_root_usec':root-accounted,
 'root_time_fractions':{k:profile[k]['usec']/root for k in ('clone','greedy','leaf','run_map_copy')},
 'cpu':receipt['cpu'],'original_trace_sha256':sha(at),'profiled_trace_sha256':sha(bt),
 'scope':'One predetermined old eight-outcome cell, timing instrumentation only. Inclusive map time is inside clone time. Instrumented cost is not the original workload timing or a speedup claim.',
 'new_independent_samples':0,'new_policy_selected':False,'whole_run_resource_ceiling_requalified':False,'packages_admitted':0,'p9_certified':False}

def run(repo,engine,out):
 repo=Path(repo).resolve();engine=Path(engine).resolve();out=Path(out).resolve();require(not out.exists(),'OUTPUT_EXISTS');out.mkdir(parents=True)
 freeze=json.loads((HERE/'FREEZE.json').read_bytes())
 for name,want in freeze['sources'].items():require(sha((HERE/name).read_bytes())==want,'FROZEN_SOURCE')
 original=repo/P/'value-v1/execution-2';sys.path.insert(0,str(repo/P/'value-v1/repaired-source-1'))
 value=module('fixed_experiment',repo/P/'value-v1/repaired-source-1/experiment.py');base,reader,binder=value.dependencies(repo)
 require(sha(engine.read_bytes())=='8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e','ENGINE')
 terminal={'status':'INCONCLUSIVE','packages_admitted':0,'p9_certified':False}
 try:
  record=json.loads((original/'FILES.json').read_bytes());byname={x['path']:x for x in record}
  source=original/'planner-source/bound-runtime.tar.xz';require(sha(source.read_bytes())==byname['planner-source/bound-runtime.tar.xz']['sha256'],'ORIGINAL_RUNTIME')
  project=out/'runtime';project.mkdir()
  manifest=json.loads((original/'planner-source/FINAL-SOURCE-MANIFEST.json').read_bytes())
  with tarfile.open(source,'r:xz') as archive:
   members=archive.getmembers();require(len(members)==len(manifest) and {x.name for x in members}==set(manifest),'RUNTIME_COVERAGE')
   for m in members:
    require(m.isfile() and not m.name.startswith('/') and '..' not in Path(m.name).parts,'PATH')
    b=archive.extractfile(m).read();require(sha(b)==manifest[m.name]['sha256'] and len(b)==manifest[m.name]['bytes'],'RUNTIME_BYTES')
    dst=project/m.name;dst.parent.mkdir(parents=True,exist_ok=True);dst.write_bytes(b)
  delta=instrument(project);save(out/'SOURCE-DELTA.json',delta)
  save(out/'PROFILED-SOURCE-MANIFEST.json',{str(p.relative_to(project)):{'bytes':p.stat().st_size,'sha256':sha(p.read_bytes())} for p in sorted(project.rglob('*')) if p.is_file()})
  p=json.loads((original/'RESOLVED-PROTOCOLS.json').read_bytes())['planner'];old_probe=p['runtime']['probe_sha256'];p['runtime']['probe_sha256']=sha((project/'probe.gd').read_bytes())
  save(out/'RESOLVED-PROTOCOL.json',p)
  logs=out/'logs';logs.mkdir();data=out/'cell';data.mkdir()
  base.command([str(engine),'--headless','--path',str(project),'--import'],logs,'import')
  base.command(['env','GODOT='+str(engine),'bash','tools/check_scripts.sh',*sorted(f.name for f in project.glob('*.gd'))],logs,'parse',cwd=project)
  reference=original/'v5/planner';cfg=json.loads((reference/(STEM+'.config.json')).read_bytes());require(cfg['first']==0 and cfg['count']==2 and cfg['vow']==5,'FIXED_FIRST_CELL')
  receipt=value.cell(cfg,project,engine,data,p,base,reader);require(receipt['status']=='COMPLETE','PROFILE_CELL')
  result=compare(reference,data,old_probe,p['runtime']['probe_sha256']);save(out/'RESULTS.json',result)
  terminal.update(status='PROFILE_COMPLETE_WITH_EXACT_NATIVE_AND_DECISION_REPRODUCTION',outcomes=result['outcomes'])
 except Exception as exc:terminal['failure']=repr(exc)
 save(out/'TERMINAL.json',terminal);print(json.dumps(terminal,indent=2))
 return 3 if terminal['status']=='INCONCLUSIVE' else 0

if __name__=='__main__':
 if sys.argv[1]=='run':raise SystemExit(run(*sys.argv[2:]))
 else:
  original,new=map(Path,sys.argv[2:4]);p=json.loads((new.parent/'RESOLVED-PROTOCOL.json').read_bytes())
  oldp=json.loads((original.parents[1]/'RESOLVED-PROTOCOLS.json').read_bytes())['planner']
  print(json.dumps(compare(original,new,oldp['runtime']['probe_sha256'],p['runtime']['probe_sha256']),indent=2))
