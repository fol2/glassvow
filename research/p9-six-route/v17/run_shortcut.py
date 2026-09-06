"""Continue the published v16 shortcut protocol without selecting on unfinished cells."""
import json,sys
from pathlib import Path
import study
R=Path(__file__).resolve().parent
contents=json.loads((R/'SHORTCUT_RECIPES.json').read_text())
def panel(n,seed,smoke=False):
    specs=[]
    for name,record in contents.items():
        for aspect,routes in study.ROUTES.items():
            if aspect==0 and name in ('lighter_ashfall','both') and not smoke:continue
            for vow in [0,5]:
                for route in routes+['balanced']:
                    specs.append({'id':f'{name}-a{aspect}-{route}-v{vow}','content_path':record['path'],'aspect':aspect,'vow':vow,'route':route,'random_build':route=='balanced','random_play':False,'seed0':seed,'runs':n,'params':{'bank_mode':'current-plus-next','native_rollout':True,'rollout_samples':2,'rollout_steps':12}})
    return specs
if __name__=='__main__':
    mode=sys.argv[1]
    if mode=='smoke':study.batch('shortcut_smoke',panel(1,16020000,True),workers=4,timeout=300)
    elif mode=='screen':study.batch('shortcut_screen',panel(32,16021000),workers=4,timeout=1800)
    else:raise SystemExit('smoke or screen')
