"""Frozen supply/echo factorial; do not select from partial results."""
from pathlib import Path
import json,sys
import study
R=Path(__file__).resolve().parent

def panel(n,seed,ash=False):
    manifest=json.loads((R/'content/manifest.json').read_text());out=[]
    for label,entry in manifest.items():
        assert study.sha(entry['path'])==entry['sha256']
        for a in ([0,1] if ash else [0]):
            for v in (0,5):
                for route in study.ROUTES[a]+['balanced']:
                    name=f'{label}-a{a}-{route}-v{v}'
                    out.append({'id':name,'content_path':entry['path'],'aspect':a,'vow':v,
                      'route':route,'random_build':route=='balanced','random_play':False,
                      'runs':n,'seed0':seed,'params':{'bank_mode':'current-plus-next',
                      'native_rollout':True,'rollout_samples':2,'rollout_steps':12,
                      'leaf_terminal':False}})
    return out

if __name__=='__main__':
    if len(sys.argv)!=2:raise SystemExit('usage: run_echo.py smoke|screen')
    if sys.argv[1]=='smoke':study.batch('echo_smoke',panel(1,34000100,True),workers=4,timeout=180)
    elif sys.argv[1]=='screen':
        rows=json.loads((R/'studies/echo_smoke/summary.json').read_text())
        assert len(rows)==64 and all(r['complete'] for r in rows)
        study.batch('echo_screen',panel(32,34010000),workers=4,timeout=900)
    else:raise SystemExit('unknown mode')
