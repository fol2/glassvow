"""Repair only a pre-population Godot static-assignment delivery defect.
The original programme, fixtures, scoring, seeds and negative capture stay fixed.
"""
from __future__ import annotations
import hashlib,json,os,shutil,subprocess,sys,tempfile
from pathlib import Path

REL=Path('research/p9-six-route/ash-inheritance-20260909/planner-v1/value-v1')
FILES=('PROTOCOL.json','combat_bridge.gd','experiment.py','null_bridge.gd','read_value.py','test_value.py','value_probe.gd')
EXPECTED={'PROTOCOL.json':'e1eb7bfb5bc1e80b0f206dda785503899cd01268000d6b92806445f71729258f','combat_bridge.gd':'dab17b96b58be8c382f95ecc7a4f9dc9d81097d355d702331a11c74a6df63bd3','experiment.py':'189186a038153e01c784f3d0e4d63076ada211bc18ab434040ed6107193a1695','null_bridge.gd':'bce80b99949792f7ec75b0f9dd25530c1871e33789c6d2e486ea0db6f44c12b8','read_value.py':'1ae6c928a743b0927d7a95056069e284fd3b2617d8deeeb4c6f6a9e953554b89','test_value.py':'22b68326d9b454912fdb1d56fd9b7c651d8fa352a9ee9abc05029b0afecda4bc','value_probe.gd':'e7f30416fc8587bfd54681dbbf8231c085a7ce4e3622415fe629ed6f4b97222b'}

def require(ok,why):
 if not ok:raise ValueError(why)
def sha(b):return hashlib.sha256(b).hexdigest()
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def save(p,x):p.write_text(json.dumps(x,indent=2)+'\n')
def replace_once(s,a,b):
 require(s.count(a)==1,'CALLSITE_COUNT:'+a);return s.replace(a,b,1)

def repair(repo,engine):
 repo=Path(repo).resolve();engine=Path(engine).resolve();root=repo/REL;old=root/'execution-1'
 require(sha(engine.read_bytes())=='8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e','ENGINE')
 terminal=json.loads((old/'TERMINAL.json').read_bytes())
 require(terminal['status']=='INCONCLUSIVE' and terminal['stages']=={} and terminal['failure']=="ValueError('PROCESS_OR_SCRIPT_DIAGNOSTIC')",'WRONG_FAILURE')
 require(not list(old.glob('v[05]')) and not (old/'qualification/signed.jsonl').exists(),'PREPOPULATION_ONLY')
 diagnostic=(old/'qualification/stock-parse.stdout').read_bytes()
 require(blob(diagnostic)=='76e8ce6a770c9dda079988b26f8b8027ee43cc33','RETAINED_DIAGNOSTIC')
 require(diagnostic.count(b'Cannot assign a new value to a constant.')==3,'FAILURE_CLASS')
 manifest=json.loads((old/'FILES.json').read_bytes())
 require(not any(r['path'].startswith(('v0/','v5/')) for r in manifest),'NO_OUTCOME_EXPOSURE')
 out=root/'repair-1';patched=root/'repaired-source-1'
 require(not out.exists() and not patched.exists(),'OUTPUT_EXISTS');out.mkdir();patched.mkdir()
 before={}
 for name in FILES:
  b=(root/name).read_bytes();require(sha(b)==EXPECTED[name],'FROZEN_SOURCE:'+name);before[name]=b;shutil.copyfile(root/name,patched/name)
 bridge=before['combat_bridge.gd'].decode()
 bridge=replace_once(bridge,'static func reset() -> void:', 'static func configure(value: bool) -> void:\n enabled=value\n\nstatic func reset() -> void:')
 (patched/'combat_bridge.gd').write_text(bridge)
 probe=before['value_probe.gd'].decode();probe=replace_once(probe,'Bridge.enabled=planned','Bridge.configure(planned)');probe=replace_once(probe,'Bridge.enabled=false','Bridge.configure(false)')
 (patched/'value_probe.gd').write_text(probe)
 null=replace_once(before['null_bridge.gd'].decode(),'Bridge.enabled=true','Bridge.configure(true)');(patched/'null_bridge.gd').write_text(null)
 expected_changes={'combat_bridge.gd','value_probe.gd','null_bridge.gd'}
 require({n for n in FILES if before[n]!=(patched/n).read_bytes()}==expected_changes,'ONLY_DISPATCH_SETTER_CHANGE')
 # Exact supported engine demonstrates the original syntax defect and its
 # replacement on both boolean values. No game or population is executed here.
 source='extends RefCounted\nstatic var enabled: bool = false\nstatic func configure(value: bool) -> void:\n enabled=value\n'
 bad='extends SceneTree\nconst Bridge: GDScript=preload("res://bridge.gd")\nfunc _initialize() -> void:\n Bridge.enabled=true\n quit(0)\n'
 good='extends SceneTree\nconst Bridge: GDScript=preload("res://bridge.gd")\nfunc _initialize() -> void:\n Bridge.configure(true)\n assert(Bridge.enabled == true)\n Bridge.configure(false)\n assert(Bridge.enabled == false)\n print("STATIC_CONFIGURATION_PASS")\n quit(0)\n'
 project=out/'compiler-regression';project.mkdir();(project/'project.godot').write_text('config_version=5\n');(project/'bridge.gd').write_text(source);(project/'bad.gd').write_text(bad);(project/'good.gd').write_text(good)
 results={}
 for name in ('bad','good'):
  r=subprocess.run([str(engine),'--headless','--path',str(project),'-s','res://'+name+'.gd'],capture_output=True,timeout=30,env=dict(os.environ,GODOT_SILENCE_ROOT_WARNING='1'))
  (out/(name+'.stdout')).write_bytes(r.stdout);(out/(name+'.stderr')).write_bytes(r.stderr)
  results[name]={'returncode':r.returncode,'stdout_sha256':sha(r.stdout),'stderr_sha256':sha(r.stderr)}
  if name=='bad':require(r.returncode!=0 and b'Cannot assign a new value to a constant.' in r.stderr,'RED_REGRESSION')
  else:require(r.returncode==0 and b'STATIC_CONFIGURATION_PASS' in r.stdout and b'ERROR:' not in r.stderr,'GREEN_REGRESSION')
 shutil.rmtree(project/'.godot',ignore_errors=True)
 shutil.copyfile(old/'TERMINAL.json',out/'ORIGINAL-TERMINAL.json');(out/'ORIGINAL-PARSE.log').write_bytes(diagnostic)
 hashes={n:sha((patched/n).read_bytes()) for n in FILES}
 save(patched/'FREEZE.json',{'source_head':os.environ['GITHUB_SHA'],'source_sha256':hashes,'original_protocol_sha256':EXPECTED['PROTOCOL.json'],'new_native_population_rows':0,'original_source_and_capture_unchanged':True,'p9_certified':False})
 save(out/'DIAGNOSIS.json',{'kind':'PREPOPULATION_STATIC_ASSIGNMENT_DELIVERY_REPAIR','original_failure':terminal,'old_parse_log_blob':blob(diagnostic),'changed_files':sorted(expected_changes),'unchanged_files':sorted(set(FILES)-expected_changes),'compiler_regression':results,'original_source_sha256':EXPECTED,'repaired_source_sha256':hashes,'same_protocol_scoring_cohort_and_criteria':True,'native_population_rows_before_repair':0,'new_fitted_parameters':0,'packages_admitted':0,'p9_certified':False})
 print(json.dumps(results,indent=2))

if __name__=='__main__':repair(*sys.argv[1:])
