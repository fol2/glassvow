"""Fixed 2x2 supply/payoff experiment; no selection from the concurrent PMF study."""
from pathlib import Path
from copy import deepcopy
import json,hashlib
R=Path(__file__).resolve().parent
REFERENCE='3c7b2f9dba362d19128ef82ad559d3f26e54925371d823a665767032255eadaa'
def build():
    raw=(R.parent/'study/fuel_content/production2_demand3.json').read_bytes()
    assert hashlib.sha256(raw).hexdigest()==REFERENCE
    x=json.loads(raw);folder=R/'content';folder.mkdir(exist_ok=True);out={}
    for supply in (0,1):
        for payoff in (0,1):
            c=deepcopy(x)
            if supply:
                for up in (False,True):
                    d=c['cards']['quakeblow']['up'] if up else c['cards']['quakeblow']
                    d['chip']=4 if up else 3
                    d['text']=f'Deal @{11 if up else 8}@ damage. Chip {4 if up else 3} extra facets.'
            if payoff:
                for up in (False,True):
                    d=c['cards']['resonantLance']['up'] if up else c['cards']['resonantLance']
                    d['effects'][0]['staggeredMult']=3
                    d['text']=f'Deal @{10 if up else 7}@ damage. Triple against a Shattered foe; otherwise double against a Vulnerable foe.'
            name=f'supply{supply}_payoff{payoff}'
            b=raw if supply==payoff==0 else (json.dumps(c,ensure_ascii=False,indent=2)+'\n').encode()
            p=folder/(name+'.json');p.write_bytes(b)
            out[name]={'path':str(p),'sha256':hashlib.sha256(b).hexdigest(),'supply':supply,'payoff':payoff}
    (folder/'manifest.json').write_text(json.dumps(out,indent=2)+'\n')
    return out
if __name__=='__main__':print(json.dumps(build(),indent=2))
