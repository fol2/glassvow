"""Fixed existing-mechanism Ash screen; not a P9 certificate."""
from pathlib import Path
import json,sys
import study
R=Path(__file__).resolve().parent
ROUTES=['smolder','hand','ember','fervor','cycle','balanced']
CONTENT=R/'fuel_content/production2_demand3.json'
EXPECTED='3c7b2f9dba362d19128ef82ad559d3f26e54925371d823a665767032255eadaa'
def panel(n,seed):
    assert study.sha(CONTENT)==EXPECTED
    return [{'id':f'ash-{route}-v{vow}','content_path':str(CONTENT),'aspect':1,
      'vow':vow,'route':route,'random_build':route=='balanced','random_play':False,
      'runs':n,'seed0':seed,'params':{'bank_mode':'current-plus-next','native_rollout':True,
      'rollout_samples':2,'rollout_steps':12,'leaf_terminal':False}}
      for vow in [0,5] for route in ROUTES]
if __name__=='__main__':
    if len(sys.argv)!=2:raise SystemExit('usage: run_transfer.py smoke|screen')
    if sys.argv[1]=='smoke':study.batch('transfer_smoke',panel(1,41000100),workers=4,timeout=180)
    elif sys.argv[1]=='screen':
        rows=json.loads((R/'studies/transfer_smoke/summary.json').read_text())
        assert len(rows)==12 and all(r['complete'] for r in rows)
        study.batch('transfer_screen',panel(32,41010000),workers=4,timeout=1200)
    else:raise SystemExit('unknown mode')
