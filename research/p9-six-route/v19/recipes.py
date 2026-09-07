"""Same pool and stock-eight anchor, two predeclared payoff shapes. Not P9 admission."""
from pathlib import Path
from copy import deepcopy
import hashlib,json
R=Path(__file__).resolve().parent
REFERENCE='93dc29ba950935323b73ee0b8e03ef4d7ba5df16fbc4d7fab0f3b7f5138debf8'
def build():
 raw=(R.parent/'content/banklight.json').read_bytes();assert hashlib.sha256(raw).hexdigest()==REFERENCE
 base=json.loads(raw);out={};(R/'content').mkdir(exist_ok=True)
 for consumer in [False,True]:
  for defence in [False,True]:
   label=('smooth' if consumer else 'hard')+'_consumer_'+('smooth' if defence else 'hard')+'_ward'
   x=deepcopy(base)
   if consumer:
    for cid,unit in [('phantomBlades','card in your hand'),('novaflare','held Ember')]:
     for up in [False,True]:
      c=x['cards'][cid]['up'] if up else x['cards'][cid]
      fx=c['effects'][0];fx['n']=6+int(up);fx['floor_per']=2
      c['text']=f'Deal @2@ damage per {unit} up to 4, then @{6+int(up)}@ per unit above 4.'
   if defence:
    for up in [False,True]:
     c=x['cards']['banklight']['up'] if up else x['cards']['banklight']
     fx=c['effects'][0];fx.update(n=7 if up else 2,per=2,reserve=2)
     c['text']=f'Gain {7 if up else 2} Ward plus 2 per held Ember above 2.'
   path=R/'content'/f'{label}.json'
   data=raw if not consumer and not defence else (json.dumps(x,ensure_ascii=False,indent=2)+'\n').encode()
   path.write_bytes(data);out[label]={'path':str(path),'sha256':hashlib.sha256(data).hexdigest(),'smooth_consumer':consumer,'smooth_ward':defence}
 (R/'CONTENT_MANIFEST.json').write_text(json.dumps(out,indent=2)+'\n');return out
if __name__=='__main__':print(json.dumps(build(),indent=2))
