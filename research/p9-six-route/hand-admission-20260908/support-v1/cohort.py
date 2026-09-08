"""Fixed source-bound policy configurations. No outcome-adaptive selection."""
from __future__ import annotations
import hashlib,json,random
COUNT=128
ROOT=58080001
SEEDS=tuple(range(58080100,58080104))
CONTENT='3c7b2f9dba362d19128ef82ad559d3f26e54925371d823a665767032255eadaa'
ENGINE='8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e'

def identity(obj):return hashlib.sha256(json.dumps(obj,sort_keys=True,separators=(',',':')).encode()).hexdigest()
def policies():
    rng=random.Random(ROOT);out=[]
    for i in range(COUNT):
        p={'route':('hand','smolder','cycle','balanced')[i%4],
           'params':{'bank_mode':'current-plus-next','native_rollout':True,
                     'rollout_samples':2,'rollout_steps':12,'leaf_terminal':False,
                     'fit':round(rng.uniform(.75,1.25),6),'life':round(rng.uniform(2.,2.6),6),
                     'rest':rng.randint(65,75),'route_low':rng.randint(50,60),
                     'decline':round(rng.uniform(10.,14.),6),'shop_ratio':round(rng.uniform(.1,.16),6)}}
        out.append(dict(p,index=i,policy_id=identity(p)))
    assert len({p['policy_id'] for p in out})==COUNT
    return out

def configurations(vow,smoke=False):
    result=[]
    for p in policies()[:2] if smoke else policies():
        for observed in (False,True) if smoke else (True,):
            result.append({'id':f'p{p["index"]:03}-v{vow}-o{int(observed)}',
                'policy_index':p['index'],'policy_id':p['policy_id'],
                'route':p['route'],'params':p['params'],'aspect':1,'vow':vow,
                'hand_observer':observed,'causal_probe':False,
                'seed0':58080010 if smoke else SEEDS[0],'runs':1 if smoke else len(SEEDS)})
    return result
