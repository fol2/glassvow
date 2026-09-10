"""Correct one consumer-schema error and reuse every complete native observation.
No decision/runtime/configuration or statistical/support/resource condition changes.
"""
from __future__ import annotations
from concurrent.futures import ThreadPoolExecutor
import copy,hashlib,importlib.util,json,os,shutil,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent
P=Path('research/p9-six-route/ash-inheritance-20260909/planner-v1')
OWN=P/'one-sample-v1'
BAD="isinstance(d.get('alternatives'),list) and len(d['alternatives'])>0 and d['root_rollouts']==len(d['alternatives'])"
GOOD="type(d['root_rollouts']) is int and d['root_rollouts']>=1"

def require(ok,why):
 if not ok:raise ValueError(why)
def sha(b):return hashlib.sha256(b).hexdigest()
def save(p,x):p.write_text(json.dumps(x,indent=2)+'\n')
def module(name,p):
 spec=importlib.util.spec_from_file_location(name,p);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m

def fixed_reader(source):
 require(source.count(BAD)==1,'EXACT_READER_FAILURE_ANCHOR')
 fixed=source.replace(BAD,GOOD,1)
 require(fixed.replace(GOOD,BAD,1)==source,'UNRELATED_READER_DELTA')
 return fixed

def setup(repo):
 bound=repo/OWN/'bound-source';freeze=json.loads((bound/'FREEZE.json').read_bytes())
 for name,digest in freeze['source_sha256'].items():require(sha((bound/name).read_bytes())==digest,'BOUND_SOURCE:'+name)
 original=(bound/'read_value.py').read_text();corrected=fixed_reader(original)
 target=HERE/'read_value.py'
 if target.exists():require(target.read_text()==corrected,'REPAIRED_SOURCE_MISMATCH')
 else:target.write_text(corrected)
 sys.path.insert(0,str(HERE));sys.modules['read_value']=module('read_value',target)
 value=module('bound_value',bound/'experiment.py');base,reader,binder=value.dependencies(repo)
 require(value.read_value is sys.modules['read_value'],'READER_DISPATCH')
 helper=repo/P/'continuation-cache-v1/benchmark.py';data=helper.read_bytes()
 require(hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()=='5d8a0dfc11a003c62cd5cd1305a659d3909a081a','ARCHIVE_HELPER_IDENTITY')
 bench=module('bound_archive',helper)
 return value,base,reader,bench

def audit_reuse(repo,out,value,reader):
 original=repo/OWN/'execution-1';t=json.loads((original/'TERMINAL.json').read_bytes())
 require(t['status']=='INCONCLUSIVE' and t['population_terminal']['failure']=="ValueError('INCOMPLETE_PLANNER_STAGE')" and not t['population_terminal']['stages'],'EXACT_ORIGINAL_TERMINAL')
 rb=json.loads((original/'REMOTE-READBACK.json').read_bytes())
 require(rb['all_bytes_equal'] and rb['population_reproduced'],'ORIGINAL_COLD_READBACK')
 for r in json.loads((original/'FILES.json').read_bytes()):
  p=Path(r['path']);require(not p.is_absolute() and '..' not in p.parts,'INPUT_PATH')
  b=(original/p).read_bytes();require(len(b)==r['bytes'] and sha(b)==r['sha256'],'RETAINED_BYTES:'+str(p))
 shutil.copytree(original/'preflight',out/'preflight')
 shutil.copytree(original/'population',out/'population')
 pop=out/'population'
 (pop/'TERMINAL.json').rename(pop/'PRE_REPAIR_TERMINAL.json')
 (pop/'FILES.json').rename(pop/'PRE_REPAIR_FILES.json')
 oldread=module('faulty_reader',repo/OWN/'bound-source/read_value.py')
 ps=json.loads((pop/'RESOLVED-PROTOCOLS.json').read_bytes())
 require(all(p['policy_root']==73409000 and p['seeds']==[73412100,73412101,73412102,73412103] for p in ps.values()),'UNCHANGED_ASSIGNMENT')
 require(json.loads((pop/'qualification/RESULTS.json').read_bytes())['status']=='COMBAT_DISPATCH_AND_SIGNED_NULL_PASS','ORIGINAL_SIGNED_QUALIFICATION')
 records=[];schema=set();repaired=0
 for method in ('stock','planner'):
  folder=pop/'v5'/method
  configs=sorted(folder.glob('v5-*.config.json'))
  require([json.loads(p.read_bytes())['first'] for p in configs]==[0,2,4,6],'EXACT_PARTIAL_ASSIGNMENT')
  for path in configs:
   cfg=json.loads(path.read_bytes());stem=path.name[:-len('.config.json')]
   receipt_path=folder/(stem+'.RECEIPT.json');before=receipt_path.read_bytes();r=json.loads(before)
   command=json.loads((folder/(stem+'.command.json')).read_bytes())
   require(command['returncode']==0 and command['error'] is None,'NOT_READER_ONLY_FAILURE')
   for item in r['raw']:
    packed=(folder/item['name']).read_bytes();raw=__import__('lzma').decompress(packed)
    require(sha(packed)==item['packed_sha256'] and sha(raw)==item['raw_sha256'] and len(raw)==item['raw_bytes'],'RAW_IDENTITY')
   rows=reader.outcome_records(folder/(stem+'.outcomes.jsonl.xz'),cfg,ps[method])
   if method=='planner':
    require(r['status']=='INCONCLUSIVE' and r['failure']=="ValueError('PLANNER_QUERY_BOUNDARY')",'FAILURE_CLASS')
    red=False
    try:oldread.validate_extra(rows,method)
    except ValueError as exc:red=str(exc)=='PLANNER_QUERY_BOUNDARY'
    require(red,'ORIGINAL_READER_NOT_RED')
    for row in rows:
     for d in row['decisions']:
      schema.update(d)
      require('alternatives' not in d and 'best' in d,'ACTUAL_PRODUCER_SCHEMA')
    repaired+=1
   else:require(r['status']=='COMPLETE','STOCK_CAPTURE_NOT_COMPLETE')
   value.read_value.validate_extra(rows,method)
   reader.trace_summary(folder/(stem+'.traces.jsonl.xz'),{r['row_key'] for r in rows})
   cpu=list(map(float,(folder/(stem+'.cpu.txt')).read_text().split()))
   require(len(cpu)==3 and all(__import__('math').isfinite(x) and x>=0 for x in cpu),'ACTUAL_CPU_RECORD')
   if method=='planner':
    r.pop('failure');r.update(status='COMPLETE',rows=len(rows),cpu=dict(zip(('user','system','elapsed'),cpu)),
     reused_original_receipt_sha256=sha(before),correction='Reader schema only; native outputs and actual CPU bytes are unchanged.')
    save(receipt_path,r)
   else:require(r['cpu']==dict(zip(('user','system','elapsed'),cpu)),'STOCK_CPU_RECONCILIATION')
   records.append({'method':method,'stem':stem,'rows':len(rows),'original_receipt_sha256':sha(before),'result_receipt_sha256':sha(receipt_path.read_bytes())})
 require(repaired==4 and len(records)==8,'EXACT_REPAIR_COVERAGE')
 result={'kind':'CAPTURED_SCHEMA_RED_GREEN_WITHOUT_NATIVE_REPLAY','reused_outcomes':sum(r['rows'] for r in records),
  'repaired_reader_receipts':repaired,'actual_decision_fields':sorted(schema),'records':records,
  'old_terminal_sha256':sha((original/'TERMINAL.json').read_bytes()),'native_source_changed':False,
  'seeds_policies_thresholds_unchanged':True,'new_native_runs_in_diagnosis':0,
  'limitation':'Population trace stores best only, not the full alternatives list. One-sample count is bound by the fixed actual controller source and480 finite full-alternative qualification cases; no missing alternatives are fabricated.',
  'packages_admitted':0,'p9_certified':False}
 save(out/'DIAGNOSIS.json',result)
 return ps,result

def run(repo,engine,out,work,publish=False):
 repo,engine,out,work=map(lambda x:Path(x).resolve(),(repo,engine,out,work))
 require(not out.exists() and not work.exists(),'OUTPUT_EXISTS_NO_RERUN');out.mkdir(parents=True);work.mkdir()
 value,base,reader,bench=setup(repo);head=base.git(repo,'rev-parse','HEAD')
 terminal={'status':'INCONCLUSIVE','source_head':head,'stages':{},'packages_admitted':0,'p9_certified':False}
 try:
  require(sha(engine.read_bytes())==bench.ENGINE,'ENGINE')
  ps,diagnosis=audit_reuse(repo,out,value,reader);terminal['reused_native_outcomes']=diagnosis['reused_outcomes']
  projects={}
  for method in ('stock','planner'):
   source=out/'population'/(method+'-source');manifest=json.loads((source/'FINAL-SOURCE-MANIFEST.json').read_bytes())
   archive=source/'bound-runtime.tar.xz';project=work/method
   bench.unpack(archive,project,[dict(path=p,**r) for p,r in manifest.items()],sha(archive.read_bytes()))
   # Import caches are derived; no runtime/source/decision field is patched.
   base.command([str(engine),'--headless','--path',str(project),'--import'],out,method+'-resume-import')
   projects[method]=project
  if publish:head=base.publish(repo,out,head,'research(p9): preserve schema repair and reused native rows before missing assignments')
  from_scope=json.loads((repo/OWN/'bound-source/PROTOCOL.json').read_bytes())
  require(from_scope['cpu_seconds_per_method_per_vow']==3600,'UNCHANGED_CPU_LIMIT')
  for vow in (5,0):
   stage=out/'population'/f'v{vow}';stage.mkdir(exist_ok=True);report={}
   for m in projects:(stage/m).mkdir(exist_ok=True)
   for phase,first,count in [('value-screen',0,32),('reserved-configuration-check',32,96)]:
    specs=[(m,{'root':73409000,'first':i,'count':2,'seeds':ps[m]['seeds'],'vow':vow,'integration':False}) for i in range(first,first+count,2) for m in projects]
    for offset in range(0,len(specs),8):
     missing=[]
     for m,cfg in specs[offset:offset+8]:
      rpath=stage/m/f"v{vow}-{cfg['first']:03d}.RECEIPT.json"
      if rpath.exists():
       r=json.loads(rpath.read_bytes());require(vow==5 and cfg['first'] in [0,2,4,6] and r['status']=='COMPLETE','UNAUTHORISED_REUSE')
      else:missing.append((m,cfg))
     if not missing:continue
     with ThreadPoolExecutor(max_workers=2) as pool:
      receipts=list(pool.map(lambda x:value.cell(x[1],projects[x[0]],engine,stage/x[0],ps[x[0]],base,reader),missing))
     if publish:head=base.publish(repo,out,head,f'research(p9): preserve only missing one-sample v{vow} {phase} group{offset//8+1}')
     require(all(r['status']=='COMPLETE' for r in receipts),'INCOMPLETE_ASSIGNED_CELL')
    rows={};costs={}
    for m in projects:rows[m],costs[m]=value.read_value.read_stage(stage/m,ps[m],vow,first,count,reader)
    result=value.read_value.compare(rows['stock'],rows['planner'],first,count,ps['stock']['seeds']);result['costs']=costs
    result['resource_ceiling_met']=all(costs[m]['process_cpu_seconds']+sum(r['costs'][m]['process_cpu_seconds'] for r in report.values())<=3600 for m in projects)
    save(stage/(phase+'.json'),result);report[phase]=result;terminal['stages'][str(vow)]=report
    if not result['resource_ceiling_met']:
     terminal.update(status='ONE_SAMPLE_RESOURCE_LIMIT_FAIL',last_vow=vow,v0_skipped=vow==5);break
    if not result['pass']:
     terminal.update(status='ONE_SAMPLE_VALUE_NOT_ESTABLISHED',last_vow=vow,v0_skipped=vow==5);break
   else:
    support={m:reader.analyze(stage/m,ps[m],vow) for m in projects}
    for m,r in support.items():save(stage/(m+'-support.json'),r)
    report['support']={m:{k:v for k,v in r.items() if k not in ('row_results','policy_ids')} for m,r in support.items()}
    report['support_pass']=support['planner']['pass'];terminal['stages'][str(vow)]=report
    if not report['support_pass']:
     terminal.update(status='ONE_SAMPLE_INHERITED_PAIR_SUPPORT_NOT_ESTABLISHED',last_vow=vow,v0_skipped=vow==5);break
    if publish:head=base.publish(repo,out,head,f'research(p9): preserve complete one-sample v{vow} value cost and support decision')
    continue
   break
  else:terminal['status']='ONE_SAMPLE_VALUE_AND_PAIR_SUPPORT_PASS_NOT_CERTIFICATE'
 except Exception as exc:terminal['failure']=repr(exc)
 finally:
  pop=out/'population';pop.mkdir(exist_ok=True)
  save(pop/'TERMINAL.json',terminal)
  save(pop/'FILES.json',[{'path':str(p.relative_to(pop)),'bytes':p.stat().st_size,'sha256':sha(p.read_bytes())} for p in sorted(pop.rglob('*')) if p.is_file() and p!=pop/'FILES.json'])
  save(out/'TERMINAL.json',terminal)
  save(out/'FILES.json',[{'path':str(p.relative_to(out)),'bytes':p.stat().st_size,'sha256':sha(p.read_bytes())} for p in sorted(out.rglob('*')) if p.is_file() and p!=out/'FILES.json'])
  head=base.git(repo,'rev-parse','HEAD')
  if publish:head=base.publish(repo,out,head,'research(p9): preserve actual resumed one-sample terminal without data duplication')
  if os.environ.get('GITHUB_ENV'):
   with open(os.environ['GITHUB_ENV'],'a') as f:f.write('PUBLISHED_HEAD='+head+'\n')
  print(json.dumps(terminal,indent=2))
 return 3 if terminal['status']=='INCONCLUSIVE' else 0

def verify(repo,original,cold,receipt):
 repo,original,cold,receipt=map(Path,(repo,original,cold,receipt));value,base,reader,bench=setup(repo)
 manifest=(original/'FILES.json').read_bytes();require((cold/'FILES.json').read_bytes()==manifest,'MANIFEST')
 for r in json.loads(manifest):
  p=Path(r['path']);require(not p.is_absolute() and '..' not in p.parts,'PATH')
  a=(original/p).read_bytes();b=(cold/p).read_bytes();require(a==b and len(b)==r['bytes'] and sha(b)==r['sha256'],'COLD_BYTES:'+str(p))
 # The unchanged value/source reader reproduces every actually opened phase.
 value.verify(repo,original/'population',cold/'population',receipt.with_name('POPULATION-READBACK.json'))
 old=repo/OWN/'execution-1/TERMINAL.json';d=json.loads((cold/'DIAGNOSIS.json').read_bytes())
 require(sha(old.read_bytes())==d['old_terminal_sha256'],'OLD_TERMINAL_RETENTION')
 t=json.loads((cold/'TERMINAL.json').read_bytes())
 save(receipt,{'kind':'RESUMED_ONE_SAMPLE_COMPLETE_COLD_READBACK','files':len(json.loads(manifest))+1,
  'all_bytes_equal':True,'readout_reproduced':True,'old_terminal_unchanged':True,
  'reused_native_outcomes':d['reused_outcomes'],'readback_native_runs':0,
  'scientific_status':t['status'],'packages_admitted':0,'p9_certified':False})

if __name__=='__main__':
 if sys.argv[1]=='run':raise SystemExit(run(*sys.argv[2:6],publish='--publish' in sys.argv))
 elif sys.argv[1]=='verify':verify(*sys.argv[2:])
 elif sys.argv[1]=='build':setup(Path(sys.argv[2]).resolve())
 else:raise SystemExit('MODE')
