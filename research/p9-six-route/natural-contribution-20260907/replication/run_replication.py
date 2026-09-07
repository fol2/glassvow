"""Fixed validation cohort. Never tune content, policy, descriptor or N after peeking."""
from pathlib import Path
import json
import study
R=Path(__file__).resolve().parent
ROUTES={0:['facet','fervor','cycle','balanced'],1:['smolder','hand','cycle','balanced']}
def panel():
    content=R/'fuel_content/production2_demand3.json'
    assert study.sha(content)=='3c7b2f9dba362d19128ef82ad559d3f26e54925371d823a665767032255eadaa'
    specs=[]
    # Four predeclared 16-seed chunks per context; closed chunks are resumable checkpoints.
    for block in range(4):
        for aspect,routes in ROUTES.items():
            for vow in (0,5):
                for route in routes:
                    specs.append({'id':f'a{aspect}-{route}-v{vow}-b{block}',
                     'content_path':str(content),'aspect':aspect,'vow':vow,'route':route,
                     'random_build':route=='balanced','random_play':False,'runs':16,
                     'seed0':44010000+16*block,'causal_probe':True,
                     'params':{'bank_mode':'current-plus-next','native_rollout':True,
                       'rollout_samples':2,'rollout_steps':12,'leaf_terminal':False}})
    return specs
if __name__=='__main__':
    parity=json.loads((R/'studies/causal_smoke/PARITY.json').read_text())
    assert parity['equal_pairs']==18 and parity['all_complete']
    model=R.parent/'replication/FROZEN-DESCRIPTOR.json'
    assert study.sha(model)=='2cfe1d8ff00d5ff695664c597be3a93e3960f39732fa049eac82b9397184bab7'
    previous=json.loads((R/'studies/causal_screen/freeze.json').read_text())
    current=study.bound_observer(panel())
    assert current==previous['observer'],'No simulation or observation change from training cohort'
    study.batch('causal_replication',panel(),workers=4,timeout=1200)
