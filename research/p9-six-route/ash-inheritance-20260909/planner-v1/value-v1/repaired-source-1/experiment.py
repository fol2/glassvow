"""One source-bound, conditionally staged planner comparison. No retune or old rerun."""
from __future__ import annotations
from concurrent.futures import ThreadPoolExecutor
import copy,hashlib,importlib.util,json,os,shutil,subprocess,sys,tarfile,tempfile
from pathlib import Path
import read_value

R=Path(__file__).resolve().parent
BASE=Path('research/p9-six-route/ash-inheritance-20260909')
BRANCH='research/p9-six-route-local-20260905'

def sha(b):return hashlib.sha256(b).hexdigest()
def require(ok,why):
 if not ok:raise ValueError(why)
def save(p,x):p.write_text(json.dumps(x,indent=2)+'\n')
def load(name,path):
 spec=importlib.util.spec_from_file_location(name,path);mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod);return mod

def dependencies(repo):
 expected={'pair-v1/run_pair.py':'6850277fbe8a289a9b0308148a21760cb3551331','pair-v1/read_pair.py':'51f606a1f9370b14bc6b28f236ae78a7ed2806fb','pair-v1/observed_game.gd':'f1a60da814b2eff8b5c10bc7d2ce29e00d12268f','planner-v1/bind.py':'910097e432220a0b08e839168bab5f3f77c2db97'}
 for name,want in expected.items():
  b=(repo/BASE/name).read_bytes();require(hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()==want,'DEPENDENCY:'+name)
 sys.path.insert(0,str(repo/BASE/'pair-v1'))
 reader=load('read_pair',repo/BASE/'pair-v1/read_pair.py');sys.modules['read_pair']=reader
 return load('preserved_pair',repo/BASE/'pair-v1/run_pair.py'),reader,load('planner_bind',repo/BASE/'planner-v1/bind.py')

def prepare(repo,work,out,p,base,binder):
 original=json.loads((repo/BASE/'pair-v1/PROTOCOL.json').read_bytes());projects={};protocols={}
 for name in ('stock','planner'):
  target=work/name;target.mkdir();metadata=out/(name+'-source');metadata.mkdir()
  q=copy.deepcopy(original)
  q.update(policy_root=p['policy_root'],policies=128,policies_per_cell=p['policies_per_cell'],seeds=p['seeds'],method=name)
  project=base.prepare(repo,target,metadata,q)
  binder.attach(repo,project)
  for src,dst in [('combat_bridge.gd','combat_bridge.gd'),('value_probe.gd','probe.gd'),('null_bridge.gd','null_bridge.gd')]:shutil.copyfile(R/src,project/dst)
  (project/'method.txt').write_text(name+'\n')
  f=project/'tools/observed_sim.gd';text=f.read_text();old='\t\tPilot.play_turn(game)'
  require(text.count(old)==1,'COMBAT_DISPATCH_ANCHOR')
  f.write_text(text.replace(old,'\t\tpreload("res://combat_bridge.gd").play_turn(game)',1))
  q['runtime']['sources']['observed_sim.gd']=sha(f.read_bytes());q['runtime']['probe_sha256']=sha((project/'probe.gd').read_bytes())
  q['runtime']['bridge_sha256']=sha((project/'combat_bridge.gd').read_bytes())
  save(metadata/'FINAL-SOURCE-MANIFEST.json',{str(f.relative_to(project)):{'bytes':f.stat().st_size,'sha256':sha(f.read_bytes())} for f in sorted(project.rglob('*')) if f.is_file()})
  with tarfile.open(metadata/'bound-runtime.tar.xz','w:xz') as archive:
   for f in sorted(project.rglob('*')):
    if f.is_file():archive.add(f,arcname=str(f.relative_to(project)),recursive=False)
  projects[name]=project;protocols[name]=q
 save(out/'RESOLVED-PROTOCOLS.json',protocols)
 return projects,protocols

def cell(cfg,project,engine,out,p,base,reader):
 stem=f"v{cfg['vow']}-{cfg['first']:03d}";config=out/(stem+'.config.json');save(config,cfg)
 outcomes=out/(stem+'.outcomes.jsonl');traces=out/(stem+'.traces.jsonl');cost=out/(stem+'.cpu.txt')
 receipt={'status':'INCONCLUSIVE','cfg':cfg,'raw':[]}
 try:
  base.command(['/usr/bin/time','-f','%U %S %e','-o',str(cost),str(engine),'--headless','--path',str(project),'-s','res://probe.gd','--',str(config),str(outcomes),str(traces)],out,stem,seconds=240)
  rows=reader.outcome_records(outcomes,cfg,p);read_value.validate_extra(rows,p['method'])
  header=next(reader.stream(outcomes));require(header['bridge_sha256']==p['runtime']['bridge_sha256'] and header['method']==p['method'],'WRAPPER_BINDING')
  reader.trace_summary(traces,{r['row_key'] for r in rows})
  cpu=[float(x) for x in cost.read_text().split()];require(len(cpu)==3 and all(x>=0 for x in cpu),'CPU_RECEIPT')
  receipt.update(status='COMPLETE',rows=len(rows),cpu=dict(zip(('user','system','elapsed'),cpu)))
 except Exception as exc:receipt['failure']=repr(exc)
 for f in (outcomes,traces):
  if f.exists():receipt['raw'].append(base.compress(f,p))
 save(out/(stem+'.RECEIPT.json'),receipt)
 return receipt

def run(repo,engine,out,work,publish=False):
 repo,engine,out,work=map(lambda x:Path(x).resolve(),(repo,engine,out,work))
 require(not out.exists() and not work.exists(),'OUTPUT_EXISTS_NO_RERUN');out.mkdir(parents=True);work.mkdir()
 base,reader,binder=dependencies(repo);head=base.git(repo,'rev-parse','HEAD')
 p=json.loads((R/'PROTOCOL.json').read_bytes());freeze=json.loads((R/'FREEZE.json').read_bytes())
 require(sha(engine.read_bytes())==p['engine_sha256'],'ENGINE')
 for name,want in freeze['source_sha256'].items():require(sha((R/name).read_bytes())==want,'OWN_SOURCE:'+name)
 entry=json.loads((repo/BASE/'planner-v1/execution-2/RESULTS.json').read_bytes())
 rb=json.loads((repo/BASE/'planner-v1/execution-2/REMOTE-READBACK.json').read_bytes())
 require(entry['status']=='PLANNER_CURRENT_RUNTIME_COMPATIBILITY_PASS' and rb['all_bytes_equal'] and rb['readout_reproduced'],'PLANNER_PREREQUISITE')
 terminal={'status':'INCONCLUSIVE','source_head':head,'stages':{},'packages_admitted':0,'p9_certified':False}
 try:
  projects,ps=prepare(repo,work,out,p,base,binder)
  if publish:head=base.publish(repo,out,head,'research(p9): bind exact combat-only comparison runtime before observations')
  q=out/'qualification';q.mkdir()
  base.command([sys.executable,'-m','unittest','-v','test_value'],q,'tests',cwd=R)
  for name,project in projects.items():
   base.command([str(engine),'--headless','--path',str(project),'--import'],q,name+'-import')
   base.command(['env','GODOT='+str(engine),'bash','tools/check_scripts.sh',*sorted(f.name for f in project.glob('*.gd')),'tools/observed_sim.gd'],q,name+'-parse',cwd=project)
  base.command([str(engine),'--headless','--path',str(projects['planner']),'-s','res://null_bridge.gd','--',str(q/'signed.jsonl'),str(q/'signed.traces.jsonl')],q,'signed-null')
  signed=list(reader.stream(q/'signed.jsonl'));require(signed[-1]=={'kind':'terminal','pairs':8,'failures':0},'SIGNED_NULL_COUNT')
  require(all(r['actual']==r['original'] and r['planner_queries']==0 and r['equal'] for r in signed[:-1]),'SIGNED_NULL_PARITY')
  for v in (5,0):
   c={'root':p['policy_root'],'first':0,'count':1,'seeds':[p['qualification_seed']],'vow':v,'integration':True}
   r=cell(c,projects['stock'],engine,q,ps['stock'],base,reader);require(r['status']=='COMPLETE','STOCK_WRAPPER_PARITY')
  save(q/'RESULTS.json',{'status':'COMBAT_DISPATCH_AND_SIGNED_NULL_PASS','signed_full_endpoint_pairs':8,'stock_wrapper_endpoint_pairs':2,'new_independent_confirmation_samples':0})
  if publish:head=base.publish(repo,out,head,'research(p9): preserve signed-arm and unchanged acquisition qualification')
  for vow in (5,0):
   stage=out/f'v{vow}';stage.mkdir()
   for method in projects:(stage/method).mkdir()
   stage_report={}
   for phase,first,count in [('value-screen',0,32),('reserved-configuration-check',32,96)]:
    specs=[(method,{'root':p['policy_root'],'first':i,'count':p['policies_per_cell'],'seeds':p['seeds'],'vow':vow,'integration':False}) for i in range(first,first+count,p['policies_per_cell']) for method in projects]
    # Same two-slot execution venue, alternating fixed method order. No response-adaptive sampling.
    for group in range(0,len(specs),8):
     with ThreadPoolExecutor(max_workers=2) as pool:
      receipts=list(pool.map(lambda x:cell(x[1],projects[x[0]],engine,stage/x[0],ps[x[0]],base,reader),specs[group:group+8]))
     if publish:head=base.publish(repo,out,head,f'research(p9): preserve matched planner v{vow} {phase} assigned group {group//8+1}')
     require(all(r['status']=='COMPLETE' for r in receipts),'INCOMPLETE_PLANNER_STAGE')
    rows={};costs={}
    for method in projects:rows[method],costs[method]=read_value.read_stage(stage/method,ps[method],vow,first,count,reader)
    value=read_value.compare(rows['stock'],rows['planner'],first,count,p['seeds'])
    value['costs']=costs
    value['resource_ceiling_met']=all(costs[m]['process_cpu_seconds']+sum(v['costs'][m]['process_cpu_seconds'] for v in stage_report.values())<=p['cpu_seconds_per_method_per_vow'] for m in projects)
    require(value['resource_ceiling_met'],'MATCHED_RESOURCE_CEILING')
    save(stage/(phase+'.json'),value);stage_report[phase]=value
    if not value['pass']:break
   else:
    support={m:reader.analyze(stage/m,ps[m],vow) for m in projects}
    for m,r in support.items():save(stage/(m+'-support.json'),r)
    stage_report['support']={m:{k:v for k,v in r.items() if k not in ('row_results','policy_ids')} for m,r in support.items()}
    stage_report['support_pass']=support['planner']['pass']
   terminal['stages'][str(vow)]=stage_report
   passed=all(stage_report.get(phase,{}).get('pass',False) for phase in ('value-screen','reserved-configuration-check')) and stage_report.get('support_pass',False)
   if not passed:
    terminal.update(status='FIXED_PLANNER_VALUE_OR_SUPPORT_NOT_ESTABLISHED',last_vow=vow,v0_skipped=(vow==5));break
  else:terminal['status']='PLANNER_VALUE_AND_INHERITED_PAIR_SUPPORT_PASS_NOT_CERTIFICATE'
 except Exception as exc:terminal['failure']=repr(exc)
 finally:
  save(out/'TERMINAL.json',terminal)
  save(out/'FILES.json',[{'path':str(f.relative_to(out)),'bytes':f.stat().st_size,'sha256':sha(f.read_bytes())} for f in sorted(out.rglob('*')) if f.is_file()])
  if publish:head=base.publish(repo,out,head,'research(p9): preserve actual terminal of fixed planner value study')
  if os.environ.get('GITHUB_ENV'):
   with open(os.environ['GITHUB_ENV'],'a') as env:env.write('PUBLISHED_HEAD='+head+'\n')
  print(json.dumps(terminal,indent=2))
 return 3 if terminal['status']=='INCONCLUSIVE' else 0

def verify(repo,original,cold,receipt):
 repo,original,cold,receipt=map(Path,(repo,original,cold,receipt));base,reader,binder=dependencies(repo)
 entries=json.loads((original/'FILES.json').read_bytes())
 for r in entries:
  rel=Path(r['path']);require(not rel.is_absolute() and '..' not in rel.parts,'PATH')
  a=(original/rel).read_bytes();b=(cold/rel).read_bytes();require(a==b and len(b)==r['bytes'] and sha(b)==r['sha256'],'COLD_BYTE:'+str(rel))
 require((original/'FILES.json').read_bytes()==(cold/'FILES.json').read_bytes(),'MANIFEST')
 ps=json.loads((cold/'RESOLVED-PROTOCOLS.json').read_bytes());terminal=json.loads((cold/'TERMINAL.json').read_bytes());protocol=json.loads((R/'PROTOCOL.json').read_bytes())
 for vow,s in terminal['stages'].items():
  cumulative={'stock':0.0,'planner':0.0}
  for phase,first,count in [('value-screen',0,32),('reserved-configuration-check',32,96)]:
   if phase not in s:continue
   rows={};costs={}
   for m in ('stock','planner'):rows[m],costs[m]=read_value.read_stage(cold/f'v{vow}'/m,ps[m],int(vow),first,count,reader)
   r=read_value.compare(rows['stock'],rows['planner'],first,count,ps['stock']['seeds']);r['costs']=costs
   for m in cumulative:cumulative[m]+=costs[m]['process_cpu_seconds']
   r['resource_ceiling_met']=all(c<=protocol['cpu_seconds_per_method_per_vow'] for c in cumulative.values())
   require((json.dumps(r,indent=2)+'\n').encode()==(cold/f'v{vow}'/(phase+'.json')).read_bytes(),'VALUE_RECONSTRUCTION')
  if 'support' in s:
   for m in ('stock','planner'):
    r=reader.analyze(cold/f'v{vow}'/m,ps[m],int(vow));require((json.dumps(r,indent=2)+'\n').encode()==(cold/f'v{vow}'/(m+'-support.json')).read_bytes(),'SUPPORT_RECONSTRUCTION')
 save(receipt,{'kind':'COMPLETE_PLANNER_VALUE_COLD_READBACK','files':len(entries)+1,'all_bytes_equal':True,'reproduced_stages':list(terminal['stages']),'scientific_status':terminal['status'],'new_native_runs':0,'packages_admitted':0,'p9_certified':False})

if __name__=='__main__':
 if sys.argv[1]=='run':raise SystemExit(run(*sys.argv[2:6],publish='--publish' in sys.argv))
 else:verify(*sys.argv[2:])
