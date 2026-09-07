"""Execute the existing v26 Ash transfer question without content/policy tuning."""
from pathlib import Path
import sys,json,subprocess,fcntl
import study
R=Path(__file__).resolve().parent
CONTENT=R/'fuel_content/production2_demand3.json'
EXPECTED='3c7b2f9dba362d19128ef82ad559d3f26e54925371d823a665767032255eadaa'
ROUTES=['smolder','hand','ember','fervor','balanced']
def panel(n,seed):
    if study.sha(CONTENT)!=EXPECTED:raise ValueError('Changed catalogue')
    return [{'id':f'ash-{route}-v{vow}','content_path':str(CONTENT),'aspect':1,
             'vow':vow,'route':route,'random_build':route=='balanced','random_play':False,
             'runs':n,'seed0':seed,'params':{'native_rollout':True,'rollout_samples':2,
              'rollout_steps':12,'bank_mode':'current-plus-next','leaf_terminal':False}}
            for vow in (0,5) for route in ROUTES]
if __name__=='__main__':
    lock=(R/'transfer.lock').open('a')
    fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
    audit=R.parent/'snapshot/research/p9-six-route/v17/audit_study.py'
    for mode,n,seed,timeout in [('smoke',1,36000100,180),('screen',32,36010000,900)]:
        stage='ash_transfer_'+mode
        study.batch(stage,panel(n,seed),workers=4,timeout=timeout)
        subprocess.run([sys.executable,str(audit),str(R/'studies'/stage)],check=True,
          stdout=(R.parent/'logs'/(stage+'-audit.log')).open('w'),stderr=subprocess.STDOUT)
    print('TRANSFER_COMPLETE_AUDITED_NOT_P9',flush=True)
