"""Existing Fervor factorial with adaptive-policy effects reported, not hidden."""
from pathlib import Path
import json,sys
import study
R=Path(__file__).resolve().parent
ROUTES=['smolder','hand','fervor','cycle']
def panel(n,seed):
 out=[]
 for label,e in json.loads((R/'content/manifest.json').read_text()).items():
  assert study.sha(e['path'])==e['sha256']
  for v in [0,5]:
   for route in ROUTES:
    out.append({'id':f'{label}-{route}-v{v}','content_path':e['path'],'aspect':1,'vow':v,
     'route':route,'random_build':False,'random_play':False,'runs':n,'seed0':seed,
     'params':{'bank_mode':'current-plus-next','native_rollout':True,'rollout_samples':2,
     'rollout_steps':12,'leaf_terminal':False}})
 return out
if __name__=='__main__':
 if sys.argv[1]=='smoke':study.batch('factorial_smoke',panel(1,41000100),workers=4,timeout=180)
 elif sys.argv[1]=='screen':
  rows=json.loads((R/'studies/factorial_smoke/summary.json').read_text())
  assert len(rows)==32 and all(r['complete'] for r in rows)
  parity=json.loads((R/'studies/factorial_smoke/PARITY.json').read_text());assert parity['equal_pairs']==8
  study.batch('factorial_screen',panel(16,41020000),workers=4,timeout=1200)
 else:raise SystemExit('usage: run_factorial.py smoke|screen')
