"""One-factor, route-matched exploratory comparison. No P9 verdict is produced."""
from pathlib import Path
import json, sys
import study
R=Path(__file__).resolve().parent
CONTENT=R/'fuel_content/production2_demand3.json'
EXPECTED='3c7b2f9dba362d19128ef82ad559d3f26e54925371d823a665767032255eadaa'

def specs(n,seed):
    assert study.sha(CONTENT)==EXPECTED
    out=[]
    for a,routes in study.ROUTES.items():
        for v in (0,5):
            for route in routes:
                for random_build in (False,True):
                    for mode in ('mean','expectation'):
                        p={'bank_mode':'current-plus-next','native_rollout':True,
                           'rollout_samples':2,'rollout_steps':12,'leaf_terminal':False,
                           'stock_aggregation':mode}
                        label=f'{mode}-a{a}-{route}-v{v}'+('-RB' if random_build else '')
                        out.append({'id':label,'content_path':str(CONTENT),'aspect':a,
                          'vow':v,'route':route,'random_build':random_build,'random_play':False,
                          'runs':n,'seed0':seed,'params':p})
    return out

if __name__=='__main__':
    if len(sys.argv)!=2:raise SystemExit('usage: run_expectation.py smoke|screen')
    mode=sys.argv[1]
    if mode=='smoke':study.batch('expectation_smoke',specs(1,33000100),workers=4,timeout=180)
    elif mode=='screen':
        q=R/'studies/expectation_smoke/summary.json'
        rows=json.loads(q.read_text())
        assert len(rows)==48 and all(r['complete'] for r in rows)
        study.batch('expectation_screen',specs(32,33010000),workers=4,timeout=900)
    else:raise SystemExit('unknown mode')
