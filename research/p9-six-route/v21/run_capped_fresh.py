"""Four predeclared content arms. Native exploration, not P9 acceptance."""
from pathlib import Path
import sys
import study
ROOT=Path(__file__).resolve().parent

def specs(runs:int,seed:int):
    contents={}
    for production in (1,2):
        for mode in ('demand3','capped'):
            folder='fuel_content' if mode=='demand3' else 'capped_content'
            name=f'production{production}_{mode}'
            contents[name]=ROOT/folder/(name+'.json')
    out=[]
    for name,path in contents.items():
        for vow in (0,5):
            for route in ('smolder','hand','ember','balanced'):
                out.append({'id':f'{name}-{route}-v{vow}', 'content_path':str(path),
                    'aspect':1,'vow':vow,'route':route,'random_build':route=='balanced',
                    'random_play':False,'runs':runs,'seed0':seed,
                    'params':{'native_rollout':True,'rollout_samples':2,'rollout_steps':12,
                        'bank_mode':'current-plus-next','leaf_terminal':False}})
    return out
if __name__=='__main__':
    if sys.argv[1]=='smoke':study.batch('capped_smoke_r2',specs(1,31000100),workers=4,timeout=240)
    elif sys.argv[1]=='screen':study.batch('capped_screen_r2',specs(32,31010000),workers=4,timeout=1200)
    else:raise SystemExit('usage: run_capped_fresh.py smoke|screen')
