"""Four fixed stock-shape recipes, disjoint exploratory seeds. Not P9 certification."""
import json, sys
from pathlib import Path
from study_bound import batch
R=Path(__file__).resolve().parent
manifest=json.loads((R/'ramp/CONTENT_MANIFEST.json').read_text())
def panel(n,seed):
    out=[]
    for label,entry in manifest.items():
        for aspect,routes in [(0,['facet','fervor','cycle']),(1,['smolder','hand','ember'])]:
            for vow in [0,5]:
                for route in routes+['balanced']:
                    rb=route=='balanced'
                    out.append({'id':f'{label}-a{aspect}-{route}-v{vow}'+('-RB' if rb else ''),
                        'content_path':entry['path'],'aspect':aspect,'vow':vow,'route':route,
                        'random_build':rb,'random_play':False,'runs':n,'seed0':seed,
                        'params':{'bank_mode':'current-plus-next','native_rollout':True,
                                  'rollout_samples':2,'rollout_steps':12,'leaf_terminal':False,
                                  'banklight_fit':12}})
    return out
if __name__=='__main__':
    mode=sys.argv[1]
    if mode=='smoke':batch('ramp_smoke',panel(1,23000100),workers=4,timeout=180)
    elif mode=='screen':batch('ramp_screen',panel(32,23010000),workers=4,timeout=1200)
    else:raise SystemExit('mode: smoke | screen')
