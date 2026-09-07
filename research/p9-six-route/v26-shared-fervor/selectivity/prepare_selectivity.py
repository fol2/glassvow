"""Same-catalogue 2x2 native Fervor component intervention; no executions."""
from pathlib import Path
from copy import deepcopy
import hashlib,json,shutil
R=Path(__file__).resolve().parent
W=R/'selectivity';P=W/'project'
if W.exists():raise RuntimeError('Do not overwrite an existing experiment')
W.mkdir();(W/'content').mkdir()
raw=(R/'study/fuel_content/production2_demand3.json').read_bytes()
assert hashlib.sha256(raw).hexdigest()=='3c7b2f9dba362d19128ef82ad559d3f26e54925371d823a665767032255eadaa'
base=json.loads(raw);manifest={}
for producer in (0,1):
 for consumer in (0,1):
  x=deepcopy(base)
  for up in (False,True):
   if not producer:
    d=x['cards']['empower']['up'] if up else x['cards']['empower']
    for fx in d['effects']:
     if fx.get('kind')=='status' and fx.get('who')=='self' and fx.get('id')=='str':fx['n']=0
   if not consumer:
    d=x['cards']['flurry']['up'] if up else x['cards']['flurry']
    for fx in d['effects']:
     if fx.get('kind')=='dmg':fx['n']*=fx.get('times',1);fx['times']=1
  b=raw if producer and consumer else (json.dumps(x,ensure_ascii=False,indent=2)+'\n').encode()
  label=f'p{producer}c{consumer}';path=W/'content'/(label+'.json');path.write_bytes(b)
  manifest[label]={'path':str(path),'sha256':hashlib.sha256(b).hexdigest(),'producer':producer,'consumer':consumer}
(W/'content/manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
shutil.copytree(R/'study/project',P,ignore=shutil.ignore_patterns('.godot','__pycache__'))
shutil.copyfile(R/'study/study.py',W/'study.py')
print('SELECTIVITY_PREPARED_ONLY',len(manifest))
