"""One newly nominated public-determinization budget; old studies stay closed.
Build and commit exact derivatives before any native observation. No tuning loop.
"""
from __future__ import annotations
import hashlib,importlib.util,json,os,shutil,subprocess,sys,tarfile
from pathlib import Path

HERE=Path(__file__).resolve().parent
P=Path('research/p9-six-route/ash-inheritance-20260909/planner-v1')
OLD=P/'value-v1/repaired-source-1'
ENGINE='8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e'
SOURCE_BLOBS={
 'experiment.py':'4a53245727489203100e71545af15b806046dc34',
 'read_value.py':'48e97d785a945df2bb5bcf00574047edf8c8513f',
 'combat_bridge.gd':'f7c93b5d01ae60891e7ad0530d4cf198e71ddc7f',
 'value_probe.gd':'11e05ace434286b64dc59d4bf7506dfb9190e62e',
 'null_bridge.gd':'77f5d37ffad1c0cfbef279bcbb4948882983917c',
 'test_value.py':'31acf7c9826f115c3e4a651925d6ed52e0cf84b4'}
MODES=('baseline','active','off','producer_off','consumer_off')


def require(ok,why):
 if not ok:raise ValueError(why)
def sha(data):return hashlib.sha256(data).hexdigest()
def blob(data):return hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
def save(path,obj):path.write_text(json.dumps(obj,indent=2)+'\n')
def module(name,path):
 spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m

def replace(text,before,after,count=1):
 require(text.count(before)==count,'EXACT_SOURCE_ANCHOR:'+before[:70])
 return text.replace(before,after)

def convert(kind,text):
 if kind=='combat_bridge.gd':return replace(text,'"rollout_samples":2','"rollout_samples":1')
 if kind=='decision_gate.gd':
  text=replace(text,'"rollout_samples":2','"rollout_samples":1')
  text=replace(text,'"fixed_two_samples"','"fixed_one_sample"')
  return replace(text,'normal.legal_candidates.size()*2','normal.legal_candidates.size()')
 if kind=='compatibility_read.py':
  text=replace(text,"'rollout_samples':2","'rollout_samples':1")
  text=replace(text,"'fixed_two_samples'","'fixed_one_sample'",2)
  return replace(text,"d['root_rollouts']==2*len(d['legal_candidates'])","d['root_rollouts']==len(d['legal_candidates'])")
 if kind=='read_value.py':
  return replace(text,"d['root_rollouts']>=2 and d['root_rollouts']%2==0",
   "isinstance(d.get('alternatives'),list) and len(d['alternatives'])>0 and d['root_rollouts']==len(d['alternatives'])")
 return text

def comparison_body(text):return text[text.index('def compare('):text.index('def validate_extra(')]

def seed_check(repo,own,seeds):
 checked=0;collisions=[]
 for path in sorted((repo/'research/p9-six-route').rglob('*.config.json')):
  if own in path.parents:continue
  cfg=json.loads(path.read_bytes());checked+=1
  def integers(value):
   if isinstance(value,dict):return {n for v in value.values() for n in integers(v)}
   if isinstance(value,list):return {n for v in value for n in integers(v)}
   return {value} if type(value) is int else set()
  if integers(cfg)&set(seeds):collisions.append(str(path.relative_to(repo)))
 require(not collisions,'PREEXISTING_CONFIG_SEED_COLLISION:'+','.join(collisions))
 return {'retained_config_files_checked':checked,'requested_seeds':seeds,'collisions':[],
  'scope':'Retained executable configuration metadata only; no outcome/holdout reading or claim of global seed independence.'}

def build(repo):
 repo=Path(repo).resolve();out=HERE/'bound-source';require(not out.exists(),'BOUND_SOURCE_EXISTS')
 w=json.loads((HERE/'WORK-ORDER.json').read_bytes());assignment=w['assignment']
 require(assignment['policy_root']==73409000 and assignment['seeds']==[73412100,73412101,73412102,73412103], 'FROZEN_ASSIGNMENT')
 seed_report=seed_check(repo,HERE,assignment['seeds']+[assignment['qualification_seed']])
 # This is a new policy, not a failed cache implementation being promoted.
 negative=json.loads((repo/P/'float-fastpath-v1/execution-1/RESULTS.json').read_bytes())
 readback=json.loads((repo/P/'float-fastpath-v1/execution-1/REMOTE-READBACK.json').read_bytes())
 require(negative['status']=='FLOAT_FASTPATH_SPEED_NOT_ESTABLISHED' and negative['pass'] is False,'PRIOR_DECISION')
 require(readback['all_bytes_equal'] and readback['readout_reproduced'],'PRIOR_NOT_PRESERVED')
 out.mkdir();records=[]
 for name,expected in SOURCE_BLOBS.items():
  path=repo/OLD/name;data=path.read_bytes();require(blob(data)==expected,'SOURCE:'+name)
  changed=convert(name,data.decode()).encode();(out/name).write_bytes(changed)
  if name=='read_value.py':require(comparison_body(data.decode())==comparison_body(changed.decode()),'STATISTICAL_PROCEDURE_CHANGE')
  records.append({'file':name,'source':str(OLD/name),'before_sha256':sha(data),'after_sha256':sha(changed),'changed':data!=changed})
 for name,oldname,expected in [('decision_gate.gd','decision_gate.gd','5ade7650f7bb09ca97d33656dec8500f558206be'),('compatibility_read.py','read.py','f66938d57eba4f0f122ecaf2c061ce69ea6e1a2c')]:
  data=(repo/P/oldname).read_bytes();require(blob(data)==expected,'COMPATIBILITY_SOURCE')
  changed=convert(name,data.decode()).encode();(out/name).write_bytes(changed)
  records.append({'file':name,'source':str(P/oldname),'before_sha256':sha(data),'after_sha256':sha(changed),'changed':data!=changed})
 p={'kind':'ONE_PUBLIC_DETERMINIZATION_COMBAT_VALUE_AND_NECESSARY_PAIR_SUPPORT',
    'engine_sha256':ENGINE,'policy_root':assignment['policy_root'],'seeds':assignment['seeds'],
    'qualification_seed':assignment['qualification_seed'],'policies_per_cell':2,
    'cpu_seconds_per_method_per_vow':3600,'maximum_outcomes':2048,
    'methods':['stock','planner'],'vow_order':[5,0],'blocks':[[0,32],[32,96]],
    'parameters':w['single_nomination'],'value':'>=5 percentage point gain and positive unchanged paired-configuration bootstrap lower bound in BOTH fixed blocks',
    'support_bounds':{'active':32,'inactive':32,'reachable':16,'exclusive':8},
    'source_delta':'Only sample count2->1 in actual combat/qualification; exact sample-count observables updated. Statistical value and support definitions are unchanged.',
    'scope':'Not same-decision equivalence, package admission, independent seed confirmation or P9.',
    'work_order_sha256':sha((HERE/'WORK-ORDER.json').read_bytes()),'packages_admitted':0,'p9_certified':False}
 save(out/'PROTOCOL.json',p);save(out/'SOURCE-BINDING.json',{'records':records,'seed_metadata':seed_report,'old_terminals_unchanged':True})
 save(out/'FREEZE.json',{'source_sha256':{f.name:sha(f.read_bytes()) for f in sorted(out.iterdir()) if f.is_file()},'native_rows_at_freeze':0})
 return p

def dependencies(repo):
 bound=HERE/'bound-source';freeze=json.loads((bound/'FREEZE.json').read_bytes())
 for name,digest in freeze['source_sha256'].items():require(sha((bound/name).read_bytes())==digest,'BOUND_SOURCE:'+name)
 sys.path.insert(0,str(bound));sys.modules['read_value']=module('read_value',bound/'read_value.py')
 value=module('one_sample_value',bound/'experiment.py');base,reader,binder=value.dependencies(repo)
 source=repo/P/'continuation-cache-v1/benchmark.py';require(blob(source.read_bytes())=='5d8a0dfc11a003c62cd5cd1305a659d3909a081a','ARCHIVE_HELPER')
 bench=module('one_sample_archive',source)
 return value,base,reader,bench

def qualify(repo,engine,out,work,base,bench):
 out.mkdir();work.mkdir()
 old=repo/P/'execution-2';manifest=json.loads((old/'ARCHIVE.json').read_bytes())
 bench.unpack(old/'capture.tar.xz',work/'original',manifest['files'],bench.QUAL_ARCHIVE)
 source_binding=json.loads((work/'original/assembly/SOURCE-BINDING.json').read_bytes())
 projects={}
 for name in ('baseline','candidate'):
  project=work/'original/assembly'/name;projects[name]=project
  shutil.copyfile(HERE/'bound-source/decision_gate.gd',project/'decision_gate.gd')
  gate=(project/'decision_gate.gd').read_bytes()
  source_binding['runtime'][name]['decision_gate.gd']={'bytes':len(gate),'sha256':sha(gate)}
 with tarfile.open(out/'runtime-source.tar.xz','w:xz') as tf:
  for name,project in projects.items():
   for file in sorted(project.rglob('*')):
    if file.is_file() and '.godot' not in file.parts:tf.add(file,arcname=name+'/'+str(file.relative_to(project)),recursive=False)
 save(out/'SOURCE-BINDING.json',source_binding)
 logs=out/'logs';logs.mkdir();raw=out/'raw';raw.mkdir()
 for name,project in projects.items():
  base.command([str(engine),'--headless','--path',str(project),'--import'],logs,name+'-import')
  base.command(['env','GODOT='+str(engine),'bash','tools/check_scripts.sh','decision_gate.gd'],logs,name+'-parse',cwd=project)
 for mode in MODES:
  project=projects['baseline' if mode=='baseline' else 'candidate']
  base.command([str(engine),'--headless','--path',str(project),'-s','res://decision_gate.gd','--',mode,str(raw/(mode+'.jsonl'))],logs,mode)
 q=module('one_sample_compatibility',HERE/'bound-source/compatibility_read.py')
 result=q.analyze(raw,source_binding);save(out/'RESULTS.json',result)
 require(result['status']=='PLANNER_CURRENT_RUNTIME_COMPATIBILITY_PASS' and result['parameters']['rollout_samples']==1,'ONE_SAMPLE_QUALIFICATION')
 return result

def run(repo,engine,out,work,publish=False):
 repo,engine,out,work=map(lambda x:Path(x).resolve(),(repo,engine,out,work))
 require(not out.exists() and not work.exists(),'OUTPUT_EXISTS');out.mkdir(parents=True);work.mkdir(parents=True)
 value,base,reader,bench=dependencies(repo);head=base.git(repo,'rev-parse','HEAD')
 terminal={'status':'INCONCLUSIVE','source_head':head,'new_controller_samples':1,'packages_admitted':0,'p9_certified':False}
 try:
  require(sha(engine.read_bytes())==ENGINE,'ENGINE')
  q=qualify(repo,engine,out/'preflight',work/'qualification',base,bench)
  terminal['qualified_cases']=q['constructed_cases']
  if publish:head=base.publish(repo,out,head,'research(p9): preserve actual one-sample controller qualification before population')
  value.run(repo,engine,out/'population',work/'population',publish=publish)
  head=base.git(repo,'rev-parse','HEAD')
  result=json.loads((out/'population/TERMINAL.json').read_bytes())
  terminal.update(status=result['status'],population_terminal=result)
 except Exception as exc:terminal['failure']=repr(exc)
 finally:
  head=base.git(repo,'rev-parse','HEAD')
  save(out/'TERMINAL.json',terminal)
  save(out/'FILES.json',[{'path':str(p.relative_to(out)),'bytes':p.stat().st_size,'sha256':sha(p.read_bytes())} for p in sorted(out.rglob('*')) if p.is_file() and p!=out/'FILES.json'])
  if publish:head=base.publish(repo,out,head,'research(p9): preserve complete one-sample nomination terminal')
  if os.environ.get('GITHUB_ENV'):
   with open(os.environ['GITHUB_ENV'],'a') as f:f.write('PUBLISHED_HEAD='+head+'\n')
  print(json.dumps(terminal,indent=2))
 return 3 if terminal['status']=='INCONCLUSIVE' else 0

def verify(repo,original,cold,receipt):
 repo,original,cold,receipt=map(Path,(repo,original,cold,receipt));require(not receipt.exists(),'READBACK_EXISTS')
 value,base,reader,bench=dependencies(repo)
 a=(original/'FILES.json').read_bytes();require(a==(cold/'FILES.json').read_bytes(),'MANIFEST')
 entries=json.loads(a);require(len({r['path'] for r in entries})==len(entries),'DUPLICATE_CAPTURE')
 for r in entries:
  path=Path(r['path']);require(not path.is_absolute() and '..' not in path.parts,'PATH')
  data=(cold/path).read_bytes();require(data==(original/path).read_bytes() and len(data)==r['bytes'] and sha(data)==r['sha256'],'COLD_BYTES:'+str(path))
 terminal=json.loads((cold/'TERMINAL.json').read_bytes());qualified=False;population=False
 if (cold/'preflight/RESULTS.json').exists():
  q=module('cold_compatibility',HERE/'bound-source/compatibility_read.py')
  result=q.analyze(cold/'preflight/raw',json.loads((cold/'preflight/SOURCE-BINDING.json').read_bytes()))
  require((json.dumps(result,indent=2)+'\n').encode()==(cold/'preflight/RESULTS.json').read_bytes(),'QUALIFICATION_REPLAY');qualified=True
 if (cold/'population/FILES.json').exists():
  nested=receipt.with_name('POPULATION-READBACK.json')
  value.verify(repo,original/'population',cold/'population',nested);population=True
  require(terminal.get('population_terminal')==json.loads((cold/'population/TERMINAL.json').read_bytes()),'TERMINAL_BINDING')
 save(receipt,{'kind':'COMPLETE_ONE_SAMPLE_CONTROLLER_COLD_READBACK','files':len(entries)+1,
  'all_bytes_equal':True,'qualification_reproduced':qualified,'population_reproduced':population,
  'scientific_status':terminal['status'],'old_outcomes_replayed_as_new':False,
  'readback_native_runs':0,'packages_admitted':0,'p9_certified':False})

if __name__=='__main__':
 if sys.argv[1]=='build':print(json.dumps(build(sys.argv[2]),indent=2))
 elif sys.argv[1]=='run':raise SystemExit(run(*sys.argv[2:6],publish='--publish' in sys.argv))
 elif sys.argv[1]=='verify':verify(*sys.argv[2:])
 else:raise SystemExit('MODE')
