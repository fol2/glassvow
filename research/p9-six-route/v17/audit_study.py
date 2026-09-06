"""Read-only independent reconciliation and paired exploratory summaries."""
from pathlib import Path
import collections, hashlib, json, math, sys

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def wilson(w,n):
 z=1.959963984540054;p=w/n;d=1+z*z/n
 m=(p+z*z/(2*n))/d;h=z*math.sqrt(p*(1-p)/n+z*z/(4*n*n))/d
 return [m-h,m+h]
def audit(folder):
 folder=Path(folder);f=json.loads((folder/'freeze.json').read_text());seen=set();cells=[];raw={}
 for s in f['specs']:
  k=s['id'];assert k not in seen;seen.add(k)
  r=json.loads((folder/(k+'.receipt.json')).read_text())
  assert r['spec']==s and r['observer']==f['observer'] and r['complete'] and r['exit_code']==0
  for suffix,field in [('.ndjson','output_sha256'),('.log','log_sha256'),('.json','config_sha256')]:assert sha(folder/(k+suffix))==r[field],(k,field)
  assert json.loads((folder/(k+'.json')).read_text())==s
  assert r['content_sha256']==f['observer']['content_files'][s['content_path']]
  data=[json.loads(l) for l in (folder/(k+'.ndjson')).read_text().splitlines()];m=data[0];rows=data[1:]
  assert m['config']==s and m['content_sha256']==r['content_sha256']
  assert m['policy_sha256']==f['observer']['sources']['lab_policy.gd'] and m['driver_sha256']==f['observer']['sources']['lab_runner.gd']
  assert m['engine']['status']=='stable' and m['engine']['major']==4 and m['engine']['minor']==7 and m['engine']['patch']==2
  assert [x['seed'] for x in rows]==list(range(s['seed0'],s['seed0']+s['runs']))
  for x in rows:
   assert x['kind']=='row' and x['result'] in ['win','loss','stall','error']
   assert all(x[t]==s[t] for t in ['aspect','vow','route','random_build','random_play'])
   if x['result']=='win':assert x['act']==3 and x['hp']>0 and x['fights'][-1]['kind']=='boss' and x['fights'][-1]['result']=='win'
   mk=x['mechanism'];assert sum(v for k2,v in mk.items() if k2.startswith('actual_hp_removed:'))==mk.get('actual_hp_removed_total',0)
  log=(folder/(k+'.log')).read_text()
  assert not any('ERROR' in l or l.startswith(('LAB_','Error:')) for l in log.splitlines())
  co=collections.Counter(x['result'] for x in rows);assert dict(co)==r['counts'] and len(rows)==r['n']
  plays=collections.Counter();mk=collections.Counter();acq=collections.Counter();offers=collections.Counter()
  for x in rows:
   mk.update(x['mechanism']);plays.update(x['played']);acq.update({c:1 for c,n in x['picked'].items() if n});offers.update({c:1 for c,n in x['offered'].items() if n})
  total=mk.get('actual_hp_removed_total',0)
  cell={'id':k,'n':len(rows),'wins':co['win'],'counts':dict(co),'rate':co['win']/len(rows),'nominal_wilson95':wilson(co['win'],len(rows)), 'seconds':r['seconds'],
   'acquired_runs':dict(acq),'offered_runs':dict(offers),'played_total':dict(plays),'mechanism_total':dict(mk),
   'actual_hp_source_fraction':{key.split(':',1)[1]:v/total for key,v in mk.items() if key.startswith('actual_hp_removed:')} if total else {},
   'poison_fraction':mk.get('poison_hp_removed',0)/max(1,total)}
  cells.append(cell);raw[k]=rows
 co=sum((collections.Counter(c['counts']) for c in cells),collections.Counter())
 return {'status':'RAW_RECONCILED_EXPLORATION_NOT_P9','freeze_sha256':sha(folder/'freeze.json'),'cells':cells,'rows':sum(c['n'] for c in cells),'counts':dict(co)},raw

def paired(a,b):
 assert [r['seed'] for r in a]==[r['seed'] for r in b]
 ds=[int(y['result']=='win')-int(x['result']=='win') for x,y in zip(a,b)];n=len(ds)
 up=ds.count(1);down=ds.count(-1);disc=up+down
 p=min(1.,2*sum(math.comb(disc,k) for k in range(min(up,down)+1))/2**disc) if disc else 1.
 m=sum(ds)/n;v=sum((x-m)**2 for x in ds)/(n-1) if n>1 else 0
 return {'n':n,'net_win_change':m,'improved':up,'worsened':down,'nominal_normal95':[max(-1,m-1.96*math.sqrt(v/n)),min(1,m+1.96*math.sqrt(v/n))],'unadjusted_exact_discordance_p':p}
if __name__=='__main__':
 p=Path(sys.argv[1]);report,raw=audit(p)
 contrasts={}
 for k in raw:
  if k.startswith('control-'):
   suffix=k[len('control-'):]
   for arm in ['lighter_finisher','lighter_ashfall','both']:
    key=arm+'-'+suffix
    if key in raw:contrasts[key]=paired(raw[k],raw[key])
 report['paired_diagnostics']=contrasts
 report['limitations']=['Nominal exploration; selection/multiplicity not controlled for P9 confirmation.','Same assigned seed index is a pair, not identical downstream RNG.','Source-attributed HP is descriptive, not isolated mechanism causality.','No signed C2, detector, retention or integration claim.']
 (p/'audit.json').write_text(json.dumps(report,indent=2)+'\n')
 print('AUDIT',report['rows'],report['counts'],'cells',len(report['cells']))
 for c in report['cells']:print(c['id'],f"{c['wins']}/{c['n']}",round(c['rate'],3))
