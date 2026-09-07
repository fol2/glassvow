"""Freeze Fervor producer/consumer diagnostics without changing the live screen."""
from pathlib import Path
from copy import deepcopy
import hashlib,json,shutil
R=Path(__file__).resolve().parent;D=R/'specificity'
if D.exists():raise RuntimeError('Refusing to overwrite an existing study')
D.mkdir();shutil.copytree(R/'study/project',D/'project',ignore=shutil.ignore_patterns('.godot','__pycache__'))
shutil.copyfile(R/'study/study.py',D/'study.py')
raw=(R/'study/fuel_content/production2_demand3.json').read_bytes()
assert hashlib.sha256(raw).hexdigest()=='3c7b2f9dba362d19128ef82ad559d3f26e54925371d823a665767032255eadaa'
x=json.loads(raw);out={};(D/'content').mkdir()
for producer in [0,1]:
 for consumer in [0,1]:
  data=deepcopy(x)
  for up in [False,True]:
   e=data['cards']['empower']['up'] if up else data['cards']['empower']
   if not producer:
    for fx in e['effects']:
     if fx.get('id')=='str' and fx.get('who')=='self':fx['n']=0
   f=data['cards']['flurry']['up'] if up else data['cards']['flurry']
   if not consumer:
    for fx in f['effects']:
     if fx['kind']=='dmg':fx['n']*=fx.get('times',1);fx['times']=1
  label=f'p{producer}c{consumer}';path=D/'content'/f'{label}.json'
  payload=raw if producer and consumer else (json.dumps(data,ensure_ascii=False,indent=2)+'\n').encode()
  path.write_bytes(payload);out[label]={'path':str(path),'sha256':hashlib.sha256(payload).hexdigest(),'producer':producer,'consumer':consumer}
(D/'content/manifest.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps(out,indent=2))
