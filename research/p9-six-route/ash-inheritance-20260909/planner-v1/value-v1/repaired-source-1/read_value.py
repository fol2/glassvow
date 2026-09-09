"""Read the one nominated combat-controller comparison, not a P9 certificate."""
from __future__ import annotations
import json,math,random
from pathlib import Path


def require(ok,why):
 if not ok:raise ValueError(why)

def compare(a,b,first,count,seeds):
 expected={(i,s) for i in range(first,first+count) for s in seeds}
 x={(r['index'],r['seed']):r for r in a};y={(r['index'],r['seed']):r for r in b}
 require(len(x)==len(a)==len(y)==len(b)==len(expected) and set(x)==set(y)==expected,'EXACT_PAIRED_RECTANGLE')
 delta=[]
 for i in range(first,first+count):
  for s in seeds:
   require(x[i,s]['policy']==y[i,s]['policy'],'SAME_CONFIGURATION')
   require(x[i,s]['row']['outcome'] in ('win','loss') and y[i,s]['row']['outcome'] in ('win','loss'),'NO_FAULT_AS_LOSS')
  delta.append(sum(int(y[i,s]['row']['outcome']=='win')-int(x[i,s]['row']['outcome']=='win') for s in seeds)/len(seeds))
 rng=random.Random(421);boot=sorted(sum(delta[rng.randrange(count)] for _ in range(count))/count for _ in range(5000))
 baseline=sum(r['row']['outcome']=='win' for r in a);planner=sum(r['row']['outcome']=='win' for r in b)
 interval=[boot[int(.025*4999)],boot[int(.975*4999)]]
 gates={'fixed_mean_gain_at_least_five_points':20*(planner-baseline)>=len(expected),'paired_configuration_lower_bound_positive':interval[0]>0}
 return {'first':first,'configurations':count,'rows_per_method':len(expected),'stock_wins':baseline,'planner_wins':planner,'point_difference':(planner-baseline)/len(expected),'configuration_bootstrap_interval':interval,'gates':gates,'pass':all(gates.values()),'scope':'Conditional on four fixed seeds; configurations are not assumed independent seeds. No package or population-generalisation certificate.'}


def validate_extra(rows,method):
 for row in rows:
  require(row['method']==method and row['faults']==[],'CONTROLLER_FAULT')
  require(row['run_usec']>=0 and row['query_usec']>=0,'COST_MEASUREMENT')
  if method=='stock':require(row['query_count']==row['root_rollouts']==0 and not row['decisions'],'STOCK_DISPATCH_CHANGED')
  else:
   require(row['query_count']==len(row['decisions']),'QUERY_COVERAGE')
   require(row['root_rollouts']==sum(d['root_rollouts'] for d in row['decisions']),'ROLLOUT_COUNT')
   require(all(d['readonly'] is True and d['root_rollouts']>=2 and d['root_rollouts']%2==0 for d in row['decisions']),'QUERY_ISOLATION')


def read_stage(folder,p,vow,first,count,reader):
 folder=Path(folder);rows=[];receipts=[]
 for i in range(first,first+count,p['policies_per_cell']):
  cfg={'root':p['policy_root'],'first':i,'count':p['policies_per_cell'],'seeds':p['seeds'],'vow':vow,'integration':False}
  stem=f'v{vow}-{i:03d}'
  q=json.loads((folder/(stem+'.RECEIPT.json')).read_bytes());require(q['status']=='COMPLETE','INCOMPLETE_CELL')
  batch=reader.outcome_records(folder/(stem+'.outcomes.jsonl.xz'),cfg,p)
  validate_extra(batch,p['method']);rows.extend(batch);receipts.append(q)
 return rows,{'process_cpu_seconds':sum(r['cpu']['user']+r['cpu']['system'] for r in receipts),'process_elapsed_seconds':sum(r['cpu']['elapsed'] for r in receipts),'queries':sum(r['query_count'] for r in rows),'root_rollouts':sum(r['root_rollouts'] for r in rows),'measured_run_seconds':sum(r['run_usec'] for r in rows)/1e6,'measured_query_seconds':sum(r['query_usec'] for r in rows)/1e6}
