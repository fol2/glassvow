"""Startup-versus-peak reallocation, not a universal damage buff."""
from pathlib import Path
import json,hashlib
ROOT=Path(__file__).resolve().parent
EXPECTED={1:'ab4b8a3f6d5d4cbf87b9a8f7e92560246b00503ff2d1e584c834066a78681d6a',2:'3c7b2f9dba362d19128ef82ad559d3f26e54925371d823a665767032255eadaa'}
def build():
 folder=ROOT/'capped_content';folder.mkdir(exist_ok=True);out={}
 for production in [1,2]:
  p=ROOT/'fuel_content'/f'production{production}_demand3.json';raw=p.read_bytes();assert hashlib.sha256(raw).hexdigest()==EXPECTED[production]
  x=json.loads(raw)
  for upgraded in [False,True]:
   c=x['cards']['novaflare']['up'] if upgraded else x['cards']['novaflare']
   c['effects'][0].update(n=0,reserve=2,floor_per=8+int(upgraded),consumeEmbers=2)
   c['text']=f'Spend up to 2 Embers. Deal @{8+int(upgraded)}@ damage per Ember spent.'
  name=f'production{production}_capped';p=folder/f'{name}.json';p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
  out[name]={'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'production':production}
 (folder/'manifest.json').write_text(json.dumps(out,indent=2)+'\n');return out
if __name__=='__main__':print(json.dumps(build(),indent=2))
