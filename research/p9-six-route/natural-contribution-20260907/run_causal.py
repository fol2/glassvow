"""Fixed observed-state contribution study. No source/content tuning within batches."""
from pathlib import Path
import json,sys
import study
R=Path(__file__).resolve().parent
CONTENT=R/'fuel_content/production2_demand3.json'
EXPECTED='3c7b2f9dba362d19128ef82ad559d3f26e54925371d823a665767032255eadaa'
ROUTES={0:['facet','fervor','cycle','balanced'],1:['smolder','hand','cycle','fervor','balanced']}
def panel(n,seed,paired=False):
    assert study.sha(CONTENT)==EXPECTED
    out=[]
    for aspect,routes in ROUTES.items():
        for vow in (0,5):
            for route in routes:
                for enabled in (False,True) if paired else (True,):
                    out.append({'id':f'a{aspect}-{route}-v{vow}-probe{int(enabled)}',
                      'content_path':str(CONTENT),'aspect':aspect,'vow':vow,'route':route,
                      'random_build':route=='balanced','random_play':False,
                      'runs':n,'seed0':seed,'causal_probe':enabled,
                      'params':{'bank_mode':'current-plus-next','native_rollout':True,
                       'rollout_samples':2,'rollout_steps':12,'leaf_terminal':False}})
    return out
if __name__=='__main__':
    if len(sys.argv)!=2:raise SystemExit('usage: run_causal.py smoke|screen')
    if sys.argv[1]=='smoke':study.batch('causal_smoke',panel(1,43000100,True),workers=4,timeout=180)
    elif sys.argv[1]=='screen':
        parity=json.loads((R/'studies/causal_smoke/PARITY.json').read_text())
        assert parity['equal_pairs']==18 and parity['all_complete']
        study.batch('causal_screen',panel(16,43010000),workers=4,timeout=1200)
    else:raise SystemExit('unknown mode')
