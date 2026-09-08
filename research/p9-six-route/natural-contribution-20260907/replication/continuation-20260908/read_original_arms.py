"""Reconcile the fixed original-arm screen; diagnostic, not signed C2 admission."""
from pathlib import Path
import json,collections,hashlib
import numpy as np
from scipy.stats import beta
R=Path(__file__).resolve().parent;W=R/'original-arms';F=W/'screen'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def interval(w,n):return [0. if w==0 else float(beta.ppf(.025,w,n-w+1)),1. if w==n else float(beta.ppf(.975,w+1,n-w))]
def main():
 freeze=json.loads((F/'freeze.json').read_text());P=json.loads((W/'PROTOCOL.json').read_text())
 assert len(freeze['specs'])==32
 primary=[];groups={};total=collections.Counter()
 for s in freeze['specs']:
  name=s['id'];p=F/(name+'.receipt.json');r=json.loads(p.read_text())
  assert r['complete'] and r['spec']==s and r['observer']==freeze['observer']
  assert r['exit_code']==0 and r['exception'] is None and not r['diagnostics'] and r['bindings'] and r['assigned'] and r['valid_wins']
  for ext,key in (('.ndjson','output_sha256'),('.json','config_sha256'),('.log','log_sha256')):assert sha(F/(name+ext))==r[key]
  data=[json.loads(x) for x in (F/(name+'.ndjson')).read_text().splitlines()];m,rows=data[0],data[1:]
  assert m['config']==s and m['sources']==P['sources'] and m['content_sha256']==P['catalogues'][s['catalogue']]
  assert [x['seed'] for x in rows]==list(range(45010000,45010064))
  assert all(x['policy']==m['policy'] for x in rows)
  counts=collections.Counter(x['outcome'] for x in rows);assert dict(counts)==r['counts'];total.update(counts)
  wins=counts['win'];outcomes=''.join({'win':'W','loss':'L','stall':'S','error':'E'}[x['outcome']] for x in rows)
  cell={'id':name,'catalogue':s['catalogue'],'aspect':s['aspect'],'vow':s['vow'],'arm':s['arm'],'n':64,'wins':wins,'rate':wins/64,
    'nominal_ci95':interval(wins,64),'counts':dict(counts),'outcomes_seed_order':outcomes,
    'raw_sha256':r['output_sha256'],'receipt_sha256':sha(p),'native_seconds':r['seconds']}
  primary.append(cell);groups[(s['catalogue'],s['aspect'],s['vow'],s['arm'])]=np.asarray([x['outcome']=='win' for x in rows],dtype=float)
 rng=np.random.default_rng(45019999);ix=rng.integers(0,64,size=(10000,64));pairs=[]
 for aspect in ('duskblade','ashwarden'):
  for v in (0,5):
   for arm in (1,2,3,4):
    d=groups[('candidate',aspect,v,arm)]-groups[('original',aspect,v,arm)]
    pairs.append({'aspect':aspect,'vow':v,'arm':arm,'candidate_minus_original':float(d.mean()),
      'nominal_seed_bootstrap95':np.quantile(d[ix].mean(axis=1),[.025,.975]).tolist()})
 out={'status':'ORIGINAL_ARM_DEFINITIONS_DIAGNOSTIC_COMPLETE_NOT_P9','rows':2048,'cells':primary,'counts':dict(total),
  'catalogues':P['catalogues'],'protocol_sha256':sha(W/'PROTOCOL.json'),'freeze_sha256':sha(F/'freeze.json'),
  'seeds':[45010000,45010063],'smoke_rows':32,'original_domain_parity_pairs':16,'metadata_replayed_pairs':8,
  'paired_catalogue_gaps':pairs,'limits':['Uses original signed arm definitions but diagnostic seeds; not a signed Phase A/C2 receipt.',
    'Original planned policy may not exploit optional research mechanics; it does not replace stronger research-controller evidence.',
    'Nominal bootstrap intervals are descriptive, not multiplicity-adjusted package admission.',
    'No content/policy adaptation, held-out predictor refit, optimisation, package or detector admission.']}
 (W/'RESULTS.json').write_text(json.dumps(out,indent=2)+'\n')
 compact={'status':out['status'],'rows':2048,'seeds':out['seeds'],'catalogues':P['catalogues'],
  'protocol_sha256':out['protocol_sha256'],'freeze_sha256':out['freeze_sha256'],'columns':['id','wins','outcomes_seed_order','raw_sha256','receipt_sha256'],
  'cells':[[c[k] for k in ('id','wins','outcomes_seed_order','raw_sha256','receipt_sha256')] for c in primary]}
 (W/'PRIMARY.json').write_text(json.dumps(compact,separators=(',',':'))+'\n')
 print('ORIGINAL_SCREEN',dict(total))
 for cat in ('original','candidate'):
  for a in ('duskblade','ashwarden'):
   for v in (0,5):print(cat,a,v,[int(groups[(cat,a,v,k)].sum()) for k in (1,2,3,4)])
if __name__=='__main__':main()
