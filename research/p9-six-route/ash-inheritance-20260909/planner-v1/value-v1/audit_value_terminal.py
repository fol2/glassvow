"""Reconstruct completed, preassigned blocks after the resource terminal.
No engine, support-stage opening, new sample, or retroactive promotion.
"""
from __future__ import annotations
import hashlib, importlib.util, json, sys
from pathlib import Path

REL=Path('research/p9-six-route/ash-inheritance-20260909/planner-v1/value-v1')
TERMINAL_BLOB='f55515cbcf033878c0b8a12ddb49596ce5d03804'
READBACK_BLOB='d845923360b692c9ea89b0227659777a63c43047'


def require(ok,why):
 if not ok:raise ValueError(why)
def sha(b):return hashlib.sha256(b).hexdigest()
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def encoded(x):return (json.dumps(x,indent=2)+'\n').encode()
def safe_relative(s):
 p=Path(s);require(s and not p.is_absolute() and '..' not in p.parts,'PATH');return p

def load(name,path):
 spec=importlib.util.spec_from_file_location(name,path);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module

def coverage(paths):
 present=[p for p in paths if p.exists()]
 failed=[{'name':p.name,'receipt':json.loads(p.read_bytes())} for p in present if json.loads(p.read_bytes())['status']!='COMPLETE']
 return {'complete':len(present)==len(paths) and not failed,'expected_cells':len(paths),'available_cells':len(present),'failed_receipts':failed}

def accumulate(cumulative,costs,ceiling):
 require(ceiling==3600,'FROZEN_RESOURCE_CEILING')
 for method in ('stock','planner'):
  cost=costs[method]['process_cpu_seconds'];require(isinstance(cost,(int,float)) and cost>=0,'NONNEGATIVE_COST')
  cumulative[method]+=cost
 return all(x<=ceiling for x in cumulative.values())

def analyze(repo):
 repo=Path(repo).resolve();root=repo/REL;execution=root/'execution-2'
 t=(execution/'TERMINAL.json').read_bytes();rb=(execution/'REMOTE-READBACK.json').read_bytes()
 require(blob(t)==TERMINAL_BLOB and blob(rb)==READBACK_BLOB,'EXACT_TERMINAL_AND_READBACK')
 terminal=json.loads(t);readback=json.loads(rb)
 require(terminal['status']=='INCONCLUSIVE' and terminal['failure']=="ValueError('MATCHED_RESOURCE_CEILING')" and terminal['stages']=={},'EXACT_RESOURCE_TERMINAL')
 require(readback['all_bytes_equal'] is True and readback['scientific_status']=='INCONCLUSIVE','REMOTE_PRESERVATION')
 freeze=json.loads((root/'repaired-source-1/FREEZE.json').read_bytes())
 for name,want in freeze['source_sha256'].items():
  p=root/'repaired-source-1'/safe_relative(name);require(sha(p.read_bytes())==want,'FROZEN_READER_SOURCE:'+name)
 require((root/'PROTOCOL.json').read_bytes()==(root/'repaired-source-1/PROTOCOL.json').read_bytes(),'PROTOCOL_UNCHANGED')
 sys.path.insert(0,str(root/'repaired-source-1'))
 experiment=load('frozen_value_experiment',root/'repaired-source-1/experiment.py')
 import read_value
 base,reader,binder=experiment.dependencies(repo)
 files=json.loads((execution/'FILES.json').read_bytes())
 require(len({r['path'] for r in files})==len(files),'UNIQUE_INPUT_PATHS')
 for record in files:
  rel=safe_relative(record['path']);data=(execution/rel).read_bytes()
  require(len(data)==record['bytes'] and sha(data)==record['sha256'],'INPUT_BYTES:'+str(rel))
 protocols=json.loads((execution/'RESOLVED-PROTOCOLS.json').read_bytes())
 contract=json.loads((root/'PROTOCOL.json').read_bytes());results={}
 require(not (execution/'v0').exists(),'SKIPPED_V0_NOT_OPENED')
 for vow in (5,):
  stage=execution/f'v{vow}';require(stage.exists(),'ASSIGNED_STAGE_EXISTS')
  cumulative={'stock':0.0,'planner':0.0};report={}
  for name,first,count in [('value-screen',0,32),('reserved-configuration-check',32,96)]:
   paths=[stage/m/f'v{vow}-{i:03d}.RECEIPT.json' for m in ('stock','planner') for i in range(first,first+count,contract['policies_per_cell'])]
   bound=coverage(paths)
   if not bound['complete']:
    report[name]={'status':'INCOMPLETE_NOT_A_VALUE_DECISION',**bound};break
   rows={};costs={}
   for m in ('stock','planner'):
    rows[m],costs[m]=read_value.read_stage(stage/m,protocols[m],vow,first,count,reader)
   result=read_value.compare(rows['stock'],rows['planner'],first,count,contract['seeds']);result['costs']=costs
   result['resource_ceiling_met']=accumulate(cumulative,costs,contract['cpu_seconds_per_method_per_vow'])
   published=stage/(name+'.json')
   if published.exists():require(encoded(result)==published.read_bytes(),'FROZEN_READOUT_DIFFERENCE')
   report[name]={'status':'COMPLETE_FIXED_BLOCK_READOUT_NOT_PROMOTION','original_result_published':published.exists(),'value':result,'cumulative_cpu_seconds':dict(cumulative)}
   if not result['resource_ceiling_met'] or not result['pass']:break
  results[str(vow)]=report
 return {'kind':'PREASSIGNED_VALUE_BLOCK_TERMINAL_AUDIT','terminal_unchanged':terminal,'fixed_blocks':results,
  'input_file_count':len(files),'input_manifest_sha256':sha((execution/'FILES.json').read_bytes()),
  'old_terminal_sha256':sha(t),'old_readback_sha256':sha(rb),'same_frozen_reader':True,
  'support_stage_newly_opened':False,'v0_opened':False,'controller_value_admitted':False,
  'interpretation':['All actual child-process costs remain counted under the original 3600-second per-method per-vow ceiling.',
   'Completed performance observations may be reported, but cannot override the original resource terminal.',
   'Configuration bootstrap is conditional on four common seeds, not independent seed confirmation.',
   'No suffix-only costing, rounding, changed CPU ceiling or later data pooling rescues this assignment.',
   'No new support aggregation is opened by this diagnostic reader.'],
  'review_kind':'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT','new_native_runs':0,'new_independent_samples':0,'packages_admitted':0,'p9_certified':False}

if __name__=='__main__':print(encoded(analyze(sys.argv[1])).decode(),end='')
