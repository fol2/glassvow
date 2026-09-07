"""Execute the previously published v26 transfer, retaining all declared policies."""
from pathlib import Path
import json,sys
import study
R=Path(__file__).resolve().parent
EXPECTED='3c7b2f9dba362d19128ef82ad559d3f26e54925371d823a665767032255eadaa'
def panel(n,seed):
 p=R/'content/fixed.json';assert study.sha(p)==EXPECTED
 return [{'id':f'a1-{route}-v{vow}','content_path':str(p),'aspect':1,'vow':vow,
  'route':route,'random_build':route=='balanced','random_play':False,'runs':n,'seed0':seed,
  'params':{'bank_mode':'current-plus-next','native_rollout':True,'rollout_samples':2,'rollout_steps':12,'leaf_terminal':False}}
  for vow in (0,5) for route in ('smolder','hand','ember','fervor','balanced')]
if __name__=='__main__':
 if sys.argv[1]=='smoke':study.batch('shared_smoke',panel(1,36000100),workers=4,timeout=180)
 elif sys.argv[1]=='screen':
  smoke=json.loads((R/'studies/shared_smoke/summary.json').read_text());assert len(smoke)==10 and all(r['complete'] for r in smoke)
  study.batch('shared_screen',panel(32,36010000),workers=4,timeout=900)
 else:raise SystemExit('usage: run_shared.py smoke|screen')
