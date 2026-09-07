"""Separate Dusk component-response matrix on the same frozen content."""
from pathlib import Path
from copy import deepcopy
import sys,json,hashlib
R=Path(__file__).resolve().parent;W=R/'study';sys.path.insert(0,str(W));import study
BASE_HASH='3c7b2f9dba362d19128ef82ad559d3f26e54925371d823a665767032255eadaa'
def recipes():
 p=W/'fuel_content/production2_demand3.json';raw=p.read_bytes();assert study.sha(p)==BASE_HASH
 base=json.loads(raw);folder=W/'dusk_selectivity_content';folder.mkdir(exist_ok=True);out={'control':str(p)}
 for arm in ['facet_supply_off','echo_off','fervor_off','multihit_off','sight_off','growth_off']:
  x=deepcopy(base)
  cids={'facet_supply_off':['chisel','quakeblow'],'echo_off':['resonantLance'],'fervor_off':['empower'],'multihit_off':['flurry'],'sight_off':['nightSight'],'growth_off':['momentum']}[arm]
  for cid in cids:
   c=x['cards'][cid]
   for up in [False,True]:
    d=c.setdefault('up',{}) if up else c
    if 'effects' not in d:d['effects']=deepcopy(base['cards'][cid]['effects'])
    if arm=='facet_supply_off':d['chip']=0
    for fx in d['effects']:
     if arm=='echo_off' and fx.get('id')=='shatterEcho':fx.clear();fx.update(kind='dmg',n=10 if up else 7)
     elif arm=='fervor_off' and fx.get('id')=='str':fx['n']=0
     elif arm=='sight_off' and fx.get('id')=='nightsight':fx['n']=0
     elif arm=='multihit_off' and fx.get('kind')=='dmg':fx['n']*=fx.get('times',1);fx['times']=1
     elif arm=='growth_off' and fx.get('id')=='momentum':fx['grow']=0
  path=folder/(arm+'.json');path.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n');out[arm]=str(path)
 (folder/'manifest.json').write_text(json.dumps({k:{'path':p,'sha256':study.sha(p)} for k,p in out.items()},indent=2)+'\n')
 return out

def specs(n,seed):
 out=[]
 contents=recipes()
 for v in [0,5]:
  for route in ['facet','fervor','cycle','balanced']:
   for arm,p in contents.items():
    out.append({'id':f'{arm}-a0-{route}-v{v}','content_path':p,'aspect':0,'vow':v,'route':route,'random_build':route=='balanced','random_play':False,'runs':n,'seed0':seed,'params':{'bank_mode':'current-plus-next','native_rollout':True,'rollout_samples':2,'rollout_steps':12,'leaf_terminal':False}})
 return out
if __name__=='__main__':
 import audit_study
 if sys.argv[1]=='recipes':print(json.dumps(recipes(),indent=2));raise SystemExit(0)
 mode=sys.argv[1];n,seed=(1,32100100) if mode=='smoke' else (16,32110000)
 name='dusk_selectivity_'+mode
 study.batch(name,specs(n,seed),workers=4,timeout=900)
 report,_=audit_study.audit(W/'studies'/name);study.write(W/'studies'/name/'audit.json',report)
 print('AUDIT_OK',report['rows'],report['counts'],flush=True)
