"""Repair an observed parse-root invocation defect, never an experimental gate.
Archive and comparison helpers preserve all original capture and case identities.
"""
from __future__ import annotations
import hashlib,io,json,os,shutil,subprocess,sys,tarfile,tempfile
from pathlib import Path

REL=Path('research/p9-six-route/ash-inheritance-20260909/planner-v1')
NAMES=('bind.py','decision_gate.gd','legacy_policy.gd','public_rollout.gd','read.py','run.py','test_planner.py','PROTOCOL.json')

def sha(b):return hashlib.sha256(b).hexdigest()
def require(ok,why):
 if not ok:raise ValueError(why)
def save(p,x):p.write_text(json.dumps(x,indent=2)+'\n')
def git(repo,*args):return subprocess.check_output(['git','-C',str(repo),*args]).decode().strip()

def unpack(execution,target):
 manifest=json.loads((execution/'ARCHIVE.json').read_bytes());raw=(execution/'capture.tar.xz').read_bytes()
 require(len(raw)==manifest['archive_bytes'] and sha(raw)==manifest['archive_sha256'],'PACKED_IDENTITY')
 expected={r['path']:r for r in manifest['files']}
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz') as archive:
  members=archive.getmembers();require(len(members)==len(expected) and {m.name for m in members}==set(expected),'MEMBER_COVERAGE')
  for m in members:
   require(m.isfile() and not m.name.startswith('/') and '..' not in Path(m.name).parts,'ARCHIVE_PATH')
   data=archive.extractfile(m).read();r=expected[m.name]
   require(len(data)==r['bytes'] and sha(data)==r['sha256'],'MEMBER_IDENTITY:'+m.name)
   p=target/m.name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
 return expected

def repair(repo):
 repo=Path(repo).resolve();root=repo/REL;out=root/'repair-1';require(not out.exists(),'REPAIR_EXISTS');out.mkdir()
 with tempfile.TemporaryDirectory() as folder:
  raw=Path(folder);members=unpack(root/'execution-1',raw)
  terminal=json.loads((raw/'TERMINAL.json').read_bytes())
  require(terminal['status']=='INCONCLUSIVE' and terminal['failure']=="ValueError('PARSE')",'DIFFERENT_FAILURE')
  require(not any(p.startswith('raw/') and p.endswith('.jsonl') for p in members),'NATIVE_CASES_ALREADY_EXPOSED')
  command=json.loads((raw/'baseline-parse.command.json').read_bytes())
  argv=command['argv'];require(argv[0]=='bash' and argv[1].endswith('/tools/check_scripts.sh'),'PARSE_COMMAND')
  require(argv[1]==str(repo/'tools/check_scripts.sh'),'OBSERVED_REPOSITORY_ROOT_INVOCATION')
  diag=(raw/'baseline-parse.stdout').read_text()+(raw/'baseline-parse.stderr').read_text()
  require('script check(s) failed' in diag and ('does not exist' in diag or 'Failed to load' in diag or 'LOAD' in diag or 'PROCESS' in diag),'EXPECTED_PATH_DIAGNOSTIC')
  for name in ('baseline-parse.command.json','baseline-parse.stdout','baseline-parse.stderr','TERMINAL.json'):
   shutil.copyfile(raw/name,out/name)
  code=(root/'run.py').read_text();old="str(repo/'tools/check_scripts.sh')";new="str(project/'tools/check_scripts.sh')"
  require(code.count(old)==1,'UNIQUE_CALLSITE')
  gate=(repo/'tools/check_scripts.sh').read_bytes();require(b'cd "$(dirname "$0")/.."' in gate,'SCRIPT_ROOT_BEHAVIOUR')
  # Execute the real shell gate against a stand-in engine to isolate directory
  # resolution. This is a delivery regression, not a Godot behaviour claim.
  fake=raw/'fake';wrong=fake/'repo';correct=fake/'project'
  for p in (wrong,correct):(p/'tools').mkdir(parents=True);(p/'tools/check_scripts.sh').write_bytes(gate)
  (correct/'fixture.gd').write_text('extends RefCounted\n')
  engine=fake/'engine';engine.write_text('#!/bin/sh\nfor last do :; done\ntest -f "$last"\n');engine.chmod(0o755)
  results=[]
  for project in (wrong,correct):
   r=subprocess.run(['bash',str(project/'tools/check_scripts.sh'),'fixture.gd'],cwd=correct,env=dict(os.environ,GODOT=str(engine)),capture_output=True)
   results.append({'root':project.name,'returncode':r.returncode,'stdout':r.stdout.decode(),'stderr':r.stderr.decode()})
  require(results[0]['returncode']!=0 and results[1]['returncode']==0,'RED_GREEN_ROOT_REGRESSION')
  repaired=root/'repaired-source-1';require(not repaired.exists(),'REPAIRED_SOURCE_EXISTS');repaired.mkdir()
  for name in NAMES:shutil.copyfile(root/name,repaired/name)
  (repaired/'run.py').write_text(code.replace(old,new,1))
  changes=[name for name in NAMES if (root/name).read_bytes()!=(repaired/name).read_bytes()]
  require(changes==['run.py'],'ONLY_DELIVERY_CALLSITE_CHANGE')
  hashes={name:sha((repaired/name).read_bytes()) for name in NAMES}
  save(repaired/'FREEZE.json',{'source_head':os.environ['GITHUB_SHA'],'source_sha256':hashes,'native_observations_at_freeze':0,'original_freeze_preserved':True,'p9_certified':False})
  save(out/'DIAGNOSIS.json',{'kind':'PARSE_GATE_PROJECT_ROOT_REPAIR','old_terminal':terminal,'old_command':command,'regression':results,'old_runner_sha256':sha(code.encode()),'new_runner_sha256':hashes['run.py'],'changed_sources':changes,'same_protocol_and_cases':True,'old_native_cases':0,'old_capture_preserved':True,'new_gameplay_or_query_change':False,'p9_certified':False})
  print(diag);print(json.dumps(results,indent=2))

def pack(repo,capture):
 repo=Path(repo);capture=Path(capture);out=repo/REL/'execution-2';out.mkdir(exist_ok=True)
 paths=[p for p in sorted(capture.rglob('*')) if p.is_file() and '.godot' not in p.parts] if capture.exists() else []
 rows=[]
 with tarfile.open(out/'capture.tar.xz','w:xz') as archive:
  for p in paths:
   data=p.read_bytes();rel=str(p.relative_to(capture));rows.append({'path':rel,'bytes':len(data),'sha256':sha(data)});archive.add(p,arcname=rel,recursive=False)
 raw=(out/'capture.tar.xz').read_bytes();save(out/'ARCHIVE.json',{'archive_bytes':len(raw),'archive_sha256':sha(raw),'files':rows,'excluded':'.godot generated cache only','p9_certified':False})
 for name in ('TERMINAL.json','RESULTS.json'):
  if (capture/name).exists():shutil.copyfile(capture/name,out/name)
 for p in paths:
  if p.parent==capture and (p.suffix in ('.stdout','.stderr') or p.name.endswith('.command.json')):shutil.copyfile(p,out/p.name)
 if not (out/'TERMINAL.json').exists():save(out/'TERMINAL.json',{'status':'INCONCLUSIVE','reason':'No runner terminal','p9_certified':False})
 print((out/'TERMINAL.json').read_text())

def verify(repo,cold):
 import importlib.util
 repo=Path(repo);cold=Path(cold);root=repo/REL;other=cold/REL;rows=[]
 for rel in ('repair_delivery.py','repair-1','repaired-source-1','execution-2'):
  p=root/rel
  for f in ([p] if p.is_file() else sorted(p.rglob('*'))):
   if not f.is_file():continue
   b=f.read_bytes();r=f.relative_to(root);require((other/r).read_bytes()==b,'COLD_BYTES:'+str(r));rows.append({'path':str(r),'bytes':len(b),'sha256':sha(b)})
 with tempfile.TemporaryDirectory() as folder:
  target=Path(folder);entries=unpack(other/'execution-2',target)
  terminal=json.loads((other/'execution-2/TERMINAL.json').read_bytes());reproduced=False
  if (target/'RESULTS.json').exists():
   spec=importlib.util.spec_from_file_location('cold_reader',other/'repaired-source-1/read.py');reader=importlib.util.module_from_spec(spec);spec.loader.exec_module(reader)
   result=reader.analyze(target/'raw',json.loads((target/'assembly/SOURCE-BINDING.json').read_bytes()))
   data=(json.dumps(result,indent=2)+'\n').encode();require(data==(target/'RESULTS.json').read_bytes()==(other/'execution-2/RESULTS.json').read_bytes(),'EXACT_READOUT');reproduced=True
  save(root/'execution-2/REMOTE-READBACK.json',{'kind':'REPAIRED_PLANNER_COMPLETE_COLD_READBACK','published_head':os.environ['PUBLISHED_HEAD'],'run_id':os.environ['GITHUB_RUN_ID'],'files':rows,'archived_files':len(entries),'all_bytes_equal':True,'readout_reproduced':reproduced,'scientific_status':terminal['status'],'new_native_runs_during_readback':0,'packages_admitted':0,'p9_certified':False})
  print(json.dumps(terminal,indent=2))

if __name__=='__main__':
 mode,*args=sys.argv[1:];{'repair':repair,'pack':pack,'verify':verify}[mode](*args)
