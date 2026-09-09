"""Bind the existing v25 planner to the already qualified minimum Bloodfire.
No historic campaign is executed; no old outcomes are read or fitted.
"""
from __future__ import annotations
import hashlib, importlib.util, io, json, shutil, tarfile
from pathlib import Path

ROOT=Path('research/p9-six-route')
REL=ROOT/'ash-inheritance-20260909/planner-v1'
MINIMUM=ROOT/'ash-inheritance-20260909/minimal-v1'
LEGACY='731122ce5fbc0773f6c97696fab449e21df415692b741eceeab79c521c54a72d'
SOURCES={
 'v8/project/lab_policy.gd': ('policy_v8.gd','2131a9463700d05b93a4c9e16364596eb91e7884ee3d40c4434152802004b95c'),
 'v9/project/lab_policy.gd': ('policy_buggy_v9.gd','72868caa9a313fba7211a475c5651e1d55394048be31c8cb64bf7fb4159221fb'),
 'v18/project/greedy_policy.gd': ('additive_policy.gd','642a9597a54e1cabf8f46f95732eed8cad04c15cacaa99a2d3c4e479eb64583b'),
 'v19/recovery/greedy_stock.gd': ('greedy_stock.gd','3ebd81dcc1e3f4aed99a88f7bb26718bb9f7f8a35065517889ad26bc6c5e44d2'),
 'v19/fuel/recovery/greedy_policy.gd': ('greedy_policy.gd','2512e45d942886346acefb0781014f724341c6575560a4489090f188be628214'),
 'v13/project/lab_policy.gd': ('rollout_policy.gd','c13958b6c9e7a97fc22ea74ed9c7530f98f59ed3eda9389cf7d9d5e8ac630aab'),
 'v15/public_rollout.gd': ('public_rollout_base.gd','9e54f661563e5421e62595b9b5335e44e871e68acf89a020db7e8b9d0eacbce7'),
 'v17/tactical/terminal_extension.gd': ('lab_policy.gd','caa33681f1a9996b666db925982ad466aa0b67d3942d31d4456a9c6cea4e3f39')}


def sha(b):return hashlib.sha256(b).hexdigest()
def require(ok,why):
 if not ok:raise ValueError(why)
def write_json(p,x):p.write_text(json.dumps(x,indent=2)+'\n')
def once(s,a,b):
 require(s.count(a)==1,'EXACT_ASSEMBLY_ANCHOR');return s.replace(a,b,1)


def attach(repo,project):
 records={}
 for relative,(name,digest) in SOURCES.items():
  p=repo/ROOT/relative;b=p.read_bytes();require(sha(b)==digest,'HISTORICAL_SOURCE:'+relative)
  (project/name).write_bytes(b);records[name]={'source':str(ROOT/relative),'sha256':digest}
 p=repo/REL/'legacy_policy.gd';b=p.read_bytes();require(sha(b)==LEGACY,'LEGACY_IDENTITY')
 (project/'legacy_policy.gd').write_bytes(b)
 records['legacy_policy.gd']={'source_archive_sha256':'76041bfc907164e0c5b5252d48c4bb0aac7b29223a011eee9f03fef17f180e65','member':'p9_continue_20260905/project_v5/lab_policy.gd','sha256':LEGACY}
 # Exactly the already-published v21/v25 assembly corrections. No new scoring.
 p=project/'rollout_policy.gd';s=p.read_text()
 s=once(s,' for action: Dictionary in candidates:\n',' var driver: RefCounted=Greedy.new();driver.route=route;driver.params=params.duplicate()\n for action: Dictionary in candidates:\n')
 s=once(s,'   var driver: RefCounted=Greedy.new();driver.route=route;driver.params=params.duplicate()', '   driver._turn_key="";driver._draw_seen.clear();driver.repeat_draw_avoided=0')
 p.write_text(s)
 p=project/'lab_policy.gd';s=p.read_text()
 s=once(s,'"value":1000000.0+10.0*model.cb.player.hp','"value":1000000.0+10.0*model.run.player.hp')
 s=once(s,' if g.cb.over or not params.get("leaf_terminal",false):return super.future_value(g)', ' if g.cb.over:\n  return 1000000.0+10.0*g.run.player.hp if g.cb.result=="win" and g.run.player.hp>0 else -1000000.0\n if not params.get("leaf_terminal",false):return super.future_value(g)')
 p.write_text(s)
 for name in ('public_rollout.gd','decision_gate.gd'):
  shutil.copyfile(repo/REL/name,project/name)
 for name in records:records[name]['assembled_sha256']=sha((project/name).read_bytes())
 records['public_rollout.gd']={'source':str(REL/'public_rollout.gd'),'assembled_sha256':sha((project/'public_rollout.gd').read_bytes()),'delta':'Only propagate three existing research intervention booleans to the copied rules; no state values, weights or action grammar change.'}
 return records


def assemble(repo,out):
 repo=Path(repo).resolve();out=Path(out).resolve();require(not out.exists(),'OUTPUT_EXISTS');out.mkdir(parents=True)
 minimum=repo/MINIMUM
 b=(minimum/'build.py').read_bytes();require(sha(b)=='770c061b79d150e8fe5e58d807ff2875aa18a1fba9de22d475ba2dccb521157c','MINIMUM_BUILDER_IDENTITY')
 spec=importlib.util.spec_from_file_location('minimum_build',minimum/'build.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
 # Reuse the retained selected projection. No reconstruction of history needed.
 packed=(minimum/'execution-1/capture.tar.xz').read_bytes()
 require(sha(packed)=='aae318079ac78a75aba6480892e61bda7177fd5f83d97eae2f579ad758c9a165','PREFLIGHT_ARCHIVE')
 archive_manifest=json.loads((minimum/'execution-1/ARCHIVE.json').read_bytes())
 with tarfile.open(fileobj=io.BytesIO(packed),mode='r:xz') as archive:
  members=[x for x in archive.getmembers() if x.name.endswith('/SELECTED-PROJECTION.json') or x.name=='SELECTED-PROJECTION.json']
  require(len(members)==1 and members[0].isfile(),'UNIQUE_SELECTED_PROJECTION')
  data=archive.extractfile(members[0]).read()
  record=next(x for x in archive_manifest['files'] if x['path']==members[0].name)
  require(sha(data)==record['sha256'] and len(data)==record['bytes'],'PROJECTION_BYTES')
  projection=json.loads(data)
 reference=json.loads((minimum/'execution-1/ASSEMBLY.json').read_bytes())
 assembled={};provenance={}
 for label,active in [('baseline',False),('candidate',True)]:
  project=out/label;m.assemble(repo,project,projection,active)
  for path in ['content/full-content.json','domain/rules/combat.gd']:
   require(sha((project/path).read_bytes())==reference[label][path]['sha256'],'CURRENT_RUNTIME_DELTA:'+label+':'+path)
  provenance[label]=attach(repo,project)
  assembled[label]={str(p.relative_to(project)):{'bytes':p.stat().st_size,'sha256':sha(p.read_bytes())} for p in sorted(project.rglob('*')) if p.is_file()}
 write_json(out/'SOURCE-BINDING.json',{'sources':provenance,'runtime':assembled,'minimum_projection_sha256':sha(data),'new_historical_runs':0,'new_fitted_parameters':0,'p9_certified':False})
 return {name:out/name for name in assembled}

if __name__=='__main__':
 import sys
 assemble(*sys.argv[1:])
