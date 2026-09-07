"""Persist compact primary outcomes from closed native captures, without early selection."""
from pathlib import Path
import collections, hashlib, json,sys

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(folder):
 folder=Path(folder);f=json.loads((folder/'freeze.json').read_text());cells=[]
 for s in f['specs']:
  k=s['id'];p=folder/(k+'.receipt.json')
  if not p.exists():continue
  r=json.loads(p.read_text())
  if not r['complete'] or r['spec']!=s or r['observer']!=f['observer']:raise ValueError(k+' incomplete/mismatched')
  for suffix,key in [('.ndjson','output_sha256'),('.json','config_sha256'),('.log','log_sha256')]:
   if sha(folder/(k+suffix))!=r[key]:raise ValueError(k+' changed bytes')
  data=[json.loads(x) for x in (folder/(k+'.ndjson')).read_text().splitlines()];rows=data[1:]
  if [x['seed'] for x in rows]!=list(range(s['seed0'],s['seed0']+s['runs'])):raise ValueError(k+' cohort differs')
  if data[0]['config']!=s:raise ValueError(k+' config differs')
  mk=collections.Counter();acq=collections.Counter();played=collections.Counter()
  for row in rows:
   mk.update(row['mechanism']);played.update(row['played']);acq.update(c for c,n in row['picked'].items() if n)
  cells.append({'id':k,'n':len(rows),'seed0':s['seed0'],'outcomes':''.join({'win':'W','loss':'L','stall':'S','error':'E'}[x['result']] for x in rows),'output_sha256':r['output_sha256'],'log_sha256':r['log_sha256'],'seconds':round(r['seconds'],4),'content_sha256':r['content_sha256'],'health':[mk.get('actual_hp_removed:novaflare',0),mk.get('poison_hp_removed',0),mk.get('actual_hp_removed_total',0)],'pyreheart_nova_acquired':[acq['pyreheart'],acq['novaflare']],'pyreheart_nova_plays':[played['pyreheart'],played['novaflare']]})
 return {'status':'CLOSED_CAPTURE_CORE_NOT_P9','assigned_cells':len(f['specs']),'closed_cells':len(cells),'rows':sum(x['n'] for x in cells),'freeze_sha256':sha(folder/'freeze.json'),'native_source_sha256':hashlib.sha256(json.dumps(f['observer'],sort_keys=True).encode()).hexdigest(),'health_columns':['nova_actual_health_removed','poison_actual_health_removed','total_actual_health_removed'],'scope':'Lossless primary outcome strings plus specified aggregates. Full raw rows/receipts/logs are in the separate checkpoint. Not a complete-stage or P9 verdict unless all assigned cells exist; no partial candidate selection.','cells':cells}
if __name__=='__main__':
 p=Path(sys.argv[1]);r=read(p);(p/'closed_core.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r,indent=2))
