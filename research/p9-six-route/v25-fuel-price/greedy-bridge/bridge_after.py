"""Wait for the two existing audited studies, then run the fixed cheap bridge."""
from pathlib import Path
import json,subprocess,sys,time,traceback
R=Path(__file__).resolve().parent
S=R/'BRIDGE_STATUS.json'
# One supervisor owns the bridge. Duplicate starts exit before any file write.
import fcntl
_lock=(R/'bridge.lock').open('a')
try:
 fcntl.flock(_lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
except BlockingIOError:
 raise SystemExit('Bridge already owned')
A=R/'snapshot/research/p9-six-route/v17/audit_study.py'
def status(stage,**data):
 value={'stage':stage,'scope':'exploration, not P9',**data};p=S.with_suffix('.tmp');p.write_text(json.dumps(value,indent=2)+'\n');p.replace(S);print(value,flush=True)
def run(stage,args,cwd):
 status(stage,command=[str(x) for x in args])
 with (R/'logs'/(stage+'.log')).open('wb') as f:p=subprocess.run([str(x) for x in args],cwd=cwd,stdout=f,stderr=subprocess.STDOUT)
 if p.returncode:raise RuntimeError(stage+' exit '+str(p.returncode))
try:
 status('waiting_for_price_and_component_audits')
 while True:
  current=json.loads((R/'PIPELINE_STATUS.json').read_text())
  if current['stage']=='DONE_PRICE_AND_COMPONENT_EXPLORATION_NOT_P9':break
  if current['stage'].startswith('STOPPED'):raise RuntimeError(current)
  time.sleep(10)
 B=R/'greedy_bridge'
 run('greedy_smoke',[sys.executable,'run_bridge.py','smoke'],B)
 run('greedy_smoke_audit',[sys.executable,A,B/'studies/greedy_smoke'],B)
 run('greedy_screen',[sys.executable,'run_bridge.py','screen'],B)
 run('greedy_bridge_audit',[sys.executable,B/'read_bridge.py',R/'price/studies/energy_screen',B/'studies/greedy_screen',A],B)
 import checkpoint
 result=checkpoint.make(Path('/mnt/data/glassvow-p9-price-components-bridge-complete.zip'))
 (R/'FINAL_ARCHIVE.json').write_text(json.dumps(result,indent=2)+'\n')
 status('complete_not_P9',archive={k:v for k,v in result.items() if k!='stages'})
except Exception as e:
 status('stopped_requires_diagnosis',error=repr(e));(R/'logs/bridge-failure.log').write_text(traceback.format_exc());raise
