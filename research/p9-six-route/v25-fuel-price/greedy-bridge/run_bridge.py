"""Same content, build rules and exposed indices; native-rollout flag alone differs."""
from pathlib import Path
import json,sys
import study
R=Path(__file__).resolve().parent

def panel(n,seed):
 manifest=json.loads((R.parent/'price/content/manifest.json').read_text());specs=[]
 for label,entry in manifest.items():
  assert study.sha(entry['path'])==entry['sha256']
  for aspect in (0,1):
   for vow in (0,5):
    for route in study.ROUTES[aspect]+['balanced']:
     specs.append({'id':f'{label}-a{aspect}-{route}-v{vow}',
       'content_path':entry['path'],'aspect':aspect,'vow':vow,'route':route,
       'random_build':route=='balanced','random_play':False,'runs':n,'seed0':seed,
       'params':{'bank_mode':'current-plus-next','native_rollout':False,
       'rollout_samples':2,'rollout_steps':12,'leaf_terminal':False}})
 return specs
if __name__=='__main__':
 if len(sys.argv)!=2:raise SystemExit('run_bridge.py smoke|screen')
 if sys.argv[1]=='smoke':study.batch('greedy_smoke',panel(1,35000100),workers=4,timeout=180)
 elif sys.argv[1]=='screen':
  rows=json.loads((R/'studies/greedy_smoke/summary.json').read_text());assert len(rows)==64 and all(r['complete'] for r in rows)
  study.batch('greedy_screen',panel(32,35010000),workers=4,timeout=900)
 else:raise SystemExit('unknown mode')
