"""Declared additive-card/reallocation study. Preserve input order and all negative arms."""
from pathlib import Path
from copy import deepcopy
import json,hashlib
R=Path(__file__).resolve().parent

def emit(name,x):
 p=R/'content'/f'{name}.json';p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n');return {'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
def tier(x,cid,r):
 for p in ['common','uncommon','rare']:x['cardPools'][p]=[c for c in x['cardPools'][p] if c!=cid]
 x['cardPools'][r].append(cid);x['cards'][cid]['rarity']=r

def build():
 x=json.loads((R/'content/fixed.json').read_text())
 tier(x,'nightSight','rare');x['relics']['ashenCore']['startSmolder']=1
 for fx in x['arts']['ashfall']['effects']:
  if fx.get('id')=='poison':fx['n']=3
 for up in [False,True]:
  def c(cid):return x['cards'][cid]['up'] if up else x['cards'][cid]
  n,g=(1,17) if up else (0,14)
  c('momentum')['effects']=[{'kind':'special','id':'momentum','n':n,'grow':g},{'kind':'draw','n':1}]
  c('momentum')['text']=f'Deal @{n}@ damage. Each play, this card gains +{g} damage this combat. Draw 1 card.'
  c('flurry')['effects']=[{'kind':'dmg','n':int(up),'times':5}]
  c('flurry')['text']=f'Deal @{int(up)}@ damage 5 times.'
  for cid,sid,unit in [('phantomBlades','phantom','card in your hand'),('novaflare','emberNova','Ember in your lantern')]:
   c(cid)['effects']=[{'kind':'special','id':sid,'n':8+int(up),'reserve':4}]
   c(cid)['text']=f'Deal @{8+int(up)}@ damage for each {unit} above 4.'
 tier(x,'phantomBlades','common');tier(x,'resonantLance','uncommon')
 out={'control':emit('control',x)}
 assert out['control']['sha256']=='35a0e20202b6a6031773d6252eddd3daa0709bd04e9aa47bea8f8c77e880d922'
 for label,per in [('placebo',0),('banklight',3)]:
  y=deepcopy(x)
  y['cards']['banklight']={'type':'skill','rarity':'uncommon','cost':1,'target':'self','vfx':'ward','effects':[{'kind':'special','id':'heldEmberWard','n':2,'per':per,'reserve':4}],'up':{'effects':[{'kind':'special','id':'heldEmberWard','n':3,'per':per+int(per>0),'reserve':4}],'text':'Gain 3 Ward plus %d per held Ember above 4.'%(per+int(per>0))},'name':'Banked Light','text':'Gain 2 Ward plus %d per held Ember above 4.'%per}
  y['cardPools']['uncommon'].append('banklight');out[label]=emit(label,y)
 y=deepcopy(x)
 for up in [False,True]:
  c=y['cards']['venomStrike']['up'] if up else y['cards']['venomStrike']
  for fx in c['effects']:
   if fx.get('id')=='poison':fx['n']=2+int(up)
  c['text']=f'Deal @{6 if up else 4}@ damage. Apply {3 if up else 2} Smolder.'
  c=y['cards']['catalyst']['up'] if up else y['cards']['catalyst']
  for fx in c['effects']:
   if fx.get('id')=='catalyst':fx['n']=2+int(up);fx['bonus']=4+2*int(up)
  c['text']=f'If the target has Smolder, multiply it by {3 if up else 2}, then add {6 if up else 4}. Kindle.'
 out['affine']=emit('affine',y)
 (R/'CONTENT_MANIFEST.json').write_text(json.dumps(out,indent=2)+'\n');print(out);return out
if __name__=='__main__':build()
