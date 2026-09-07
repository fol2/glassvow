"""Whole-run Ash Fervor component factorial; reuse the unchanged native planner."""
from pathlib import Path
import json,sys,subprocess,fcntl
import study
R=Path(__file__).resolve().parent
ROUTES=['smolder','hand','fervor','balanced']
def specs(n,seed):
 out=[]
 for label,e in json.loads((R/'content/manifest.json').read_text()).items():
  assert study.sha(e['path'])==e['sha256']
  for v in (0,5):
   for route in ROUTES:
    out.append({'id':f'{label}-{route}-v{v}','content_path':e['path'],'aspect':1,'vow':v,'route':route,
      'random_build':route=='balanced','random_play':False,'runs':n,'seed0':seed,
      'params':{'native_rollout':True,'rollout_samples':2,'rollout_steps':12,'bank_mode':'current-plus-next','leaf_terminal':False}})
 return out
if __name__=='__main__':
 lock=(R/'selectivity.lock').open('a');fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
 A=R.parent/'snapshot/research/p9-six-route/v17/audit_study.py'
 prior=R.parent/'study/studies/ash_transfer_screen/audit.json'
 assert prior.exists() and json.loads(prior.read_text())['rows']==320,'Finish the existing study first'
 study.batch('fervor_smoke',specs(1,36000100),workers=4,timeout=180)
 subprocess.run([sys.executable,str(A),str(R/'studies/fervor_smoke')],check=True,stdout=(R.parent/'logs/fervor-smoke-audit.log').open('w'),stderr=subprocess.STDOUT)
 pairs=0
 for v in (0,5):
  for route in ROUTES:
   old=R.parent/f'study/studies/ash_transfer_smoke/ash-{route}-v{v}.ndjson'
   new=R/f'studies/fervor_smoke/p1c1-{route}-v{v}.ndjson'
   a=[json.loads(s) for s in old.read_text().splitlines()][1:]
   b=[json.loads(s) for s in new.read_text().splitlines()][1:]
   assert a==b,(route,v,'control behavior drift')
   pairs+=1
 (R/'studies/fervor_smoke/PARITY.json').write_text(json.dumps({'equal_pairs':pairs,'scope':'control replay, not fresh evidence'})+'\n')
 study.batch('fervor_screen',specs(16,48010000),workers=4,timeout=900)
 subprocess.run([sys.executable,str(A),str(R/'studies/fervor_screen')],check=True,stdout=(R.parent/'logs/fervor-screen-audit.log').open('w'),stderr=subprocess.STDOUT)
 print('FERVOR_COMPONENT_COMPLETE_AUDITED_NOT_P9',flush=True)
