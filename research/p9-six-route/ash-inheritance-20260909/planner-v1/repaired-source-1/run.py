"""Execute the frozen planner compatibility matrix once; preserve every capture."""
from __future__ import annotations
import hashlib,json,os,subprocess,sys,time
from pathlib import Path
import bind, read

R=Path(__file__).resolve().parent

def save(p,x):p.write_text(json.dumps(x,indent=2)+'\n')
def command(args,label,out,cwd=None,seconds=180):
 start=time.monotonic();rc=None;error=None
 try:
  with (out/(label+'.stdout')).open('wb') as so,(out/(label+'.stderr')).open('wb') as se:
   rc=subprocess.run(args,cwd=cwd,stdout=so,stderr=se,timeout=seconds,env=dict(os.environ,GODOT_SILENCE_ROOT_WARNING='1')).returncode
 except subprocess.TimeoutExpired:error='WATCHDOG'
 data=(out/(label+'.stderr')).read_bytes()
 if b'ERROR:' in data or b'Failed to load script' in data:error='SCRIPT_DIAGNOSTIC'
 result={'argv':args,'returncode':rc,'diagnostic':error,'seconds':time.monotonic()-start}
 save(out/(label+'.command.json'),result)
 return result

def main(repo,engine,output):
 repo,engine,out=map(lambda x:Path(x).resolve(),(repo,engine,output))
 bind.require(not out.exists(),'OUTPUT_EXISTS');out.mkdir(parents=True)
 p=json.loads((R/'PROTOCOL.json').read_bytes());freeze=json.loads((R/'FREEZE.json').read_bytes())
 for name,want in freeze['source_sha256'].items():bind.require(bind.sha((R/name).read_bytes())==want,'SOURCE:'+name)
 bind.require(bind.sha(engine.read_bytes())==p['engine_sha256'],'ENGINE_IDENTITY')
 os.environ['GODOT']=str(engine)
 terminal={'status':'INCONCLUSIVE','source_head':freeze['source_head'],'packages_admitted':0,'p9_certified':False}
 try:
  projects=bind.assemble(repo,out/'assembly');raw=out/'raw';raw.mkdir()
  test=command([sys.executable,'-m','unittest','-v','test_planner'],'tests',out,cwd=R)
  bind.require(test['returncode']==0 and not test['diagnostic'],'PYTHON_TESTS')
  for mode,project in projects.items():
   q=command([str(engine),'--headless','--path',str(project),'--import'],mode+'-import',out)
   bind.require(q['returncode']==0 and not q['diagnostic'],'IMPORT')
   q=command(['bash',str(project/'tools/check_scripts.sh'),*sorted(x.name for x in project.glob('*.gd'))],mode+'-parse',out,cwd=project)
   bind.require(q['returncode']==0 and not q['diagnostic'],'PARSE')
  for mode in read.MODES:
   project=projects['baseline' if mode=='baseline' else 'candidate']
   q=command([str(engine),'--headless','--path',str(project),'-s','res://decision_gate.gd','--',mode,str(raw/(mode+'.jsonl'))],mode,out,seconds=p['invocation_seconds'])
   bind.require(not q['diagnostic'] and q['returncode'] in (0,3),'NATIVE_DELIVERY')
   bind.require((raw/(mode+'.jsonl')).stat().st_size<=p['raw_bytes_per_mode'],'RAW_CAP')
  result=read.analyze(raw,json.loads((out/'assembly/SOURCE-BINDING.json').read_bytes()));save(out/'RESULTS.json',result)
  terminal.update(status=result['status'],constructed_cases=result['constructed_cases'],failed_checks=len(result['failed_checks']))
 except Exception as exc:terminal['failure']=repr(exc)
 save(out/'TERMINAL.json',terminal);print(json.dumps(terminal,indent=2))
 return 0 if terminal['status']!='INCONCLUSIVE' else 3

if __name__=='__main__':raise SystemExit(main(*sys.argv[1:]))
