"""Recreate the published two-factor question with bound, explicit content bytes."""
from pathlib import Path
from copy import deepcopy
import json,hashlib
ROOT=Path(__file__).resolve().parent
BASIS='2dfbaa570767552f09f87bbe395ecb30df69c3b7f61e5d98490e7a28dcd91539'
def build():
 raw=(ROOT/'ramp/content/smooth_consumer_hard_ward.json').read_bytes()
 assert hashlib.sha256(raw).hexdigest()==BASIS
 original=json.loads(raw);out={};folder=ROOT/'fuel_content';folder.mkdir(exist_ok=True)
 for production in [1,2]:
  for demand in [0,3]:
   x=deepcopy(original);name=f'production{production}_demand{demand}'
   if production==2:
    x['cards']['pyreheart']['effects'][0]['n']=2
    x['cards']['pyreheart']['up']['effects']=[{'kind':'status','who':'self','id':'emberflow','n':3}]
    x['cards']['pyreheart']['text']='At the start of each turn, gain 2 Embers.'
    x['cards']['pyreheart']['up']['text']='At the start of each turn, gain 3 Embers.'
   if demand:
    for upgraded in [False,True]:
     c=x['cards']['novaflare']['up'] if upgraded else x['cards']['novaflare']
     c['effects'][0]['consumeEmbers']=3
     c['text']+=' Spend up to 3 Embers before dealing damage based on the original bank.'
   data=raw if production==1 and demand==0 else (json.dumps(x,ensure_ascii=False,indent=2)+'\n').encode()
   p=folder/f'{name}.json';p.write_bytes(data)
   out[name]={'path':str(p),'sha256':hashlib.sha256(data).hexdigest(),'production':production,'demand':demand}
 (folder/'manifest.json').write_text(json.dumps(out,indent=2)+'\n');return out
if __name__=='__main__':print(json.dumps(build(),indent=2))
