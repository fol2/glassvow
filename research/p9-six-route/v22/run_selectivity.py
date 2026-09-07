"""Fresh all-assigned component-null matrix; not P9 certification."""
from pathlib import Path
from copy import deepcopy
import sys, json, hashlib
R = Path(__file__).resolve().parent
W = R / 'study'
sys.path.insert(0, str(W))
import study
EXPECTED = '3c7b2f9dba362d19128ef82ad559d3f26e54925371d823a665767032255eadaa'
TARGETS = {'venom_off':'venomStrike', 'catalyst_off':'catalyst', 'sight_off':'nightSight', 'phantom_off':'phantomBlades', 'flow_off':'pyreheart', 'nova_off':'novaflare'}

def recipes():
    p = W / 'fuel_content/production2_demand3.json'
    data = p.read_bytes()
    assert hashlib.sha256(data).hexdigest() == EXPECTED
    base = json.loads(data)
    folder = W / 'selectivity_content'
    folder.mkdir(exist_ok=True)
    out = {'control':str(p)}
    for arm, cid in TARGETS.items():
        x = deepcopy(base)
        c = x['cards'][cid]
        for up in [False, True]:
            d = c.setdefault('up', {}) if up else c
            if 'effects' not in d:
                d['effects'] = deepcopy(base['cards'][cid]['effects'])
            for fx in d['effects']:
                if arm == 'venom_off' and fx.get('id') == 'poison': fx['n'] = 0
                elif arm == 'catalyst_off' and fx.get('id') == 'catalyst': fx.update(n=1, bonus=0)
                elif arm == 'sight_off' and fx.get('id') == 'nightsight': fx['n'] = 0
                elif arm == 'flow_off' and fx.get('id') == 'emberflow': fx['n'] = 0
                elif arm in ['phantom_off', 'nova_off'] and fx.get('id') in ['phantom', 'emberNova']: fx.update(n=0, floor_per=0)
        path = folder / (arm+'.json')
        path.write_text(json.dumps(x, ensure_ascii=False, indent=2)+'\n')
        out[arm] = str(path)
    (folder/'manifest.json').write_text(json.dumps({k:{'path':p, 'sha256':study.sha(p)} for k,p in out.items()}, indent=2)+'\n')
    return out

def specs(n, seed):
    cs = recipes()
    out = []
    for v in [0,5]:
        for route in ['smolder','hand','ember','balanced']:
            for arm,path in cs.items():
                out.append({'id':f'{arm}-a1-{route}-v{v}', 'content_path':path, 'aspect':1, 'vow':v, 'route':route, 'random_build':route=='balanced', 'random_play':False, 'runs':n, 'seed0':seed, 'params':{'bank_mode':'current-plus-next','native_rollout':True,'rollout_samples':2,'rollout_steps':12,'leaf_terminal':False}})
    return out

if __name__ == '__main__':
    mode = sys.argv[1]
    if mode == 'recipes': print(json.dumps(recipes(), indent=2))
    elif mode == 'smoke': study.batch('selectivity_smoke', specs(1,32000100), workers=4, timeout=900)
    elif mode == 'screen': study.batch('selectivity_screen', specs(16,32010000), workers=4, timeout=900)
    elif mode == 'benchmark': study.batch('throughput_preflight', specs(1,32000000)[:4], workers=2, timeout=180)
    else: raise SystemExit('unknown mode')
