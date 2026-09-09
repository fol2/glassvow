"""Strict offline reconstruction of the bounded planner compatibility gate."""
from __future__ import annotations
import copy, hashlib, itertools, json
from pathlib import Path

MODES=('baseline','active','off','producer_off','consumer_off')
CHECKS=('live_state_unchanged','second_query_unchanged','public_frame_retained','hidden_change_is_private','hidden_input_independent','same_public_determinization','intervention_flags_retained','legal_action','paid_play_succeeded','does_not_choose_known_fatal_source','fixed_two_samples','content_readonly','rule_switches_readonly')
KEYS=('aspect','vow','upgraded','pattern','modifiers','route')
PARAMETERS={'bank_mode':'current-plus-next','native_rollout':True,'rollout_samples':2,'rollout_steps':12,'leaf_terminal':False}


def require(ok,why):
 if not ok:raise ValueError(why)
def sha(b):return hashlib.sha256(b).hexdigest()
def frame(x):
 x=copy.deepcopy(x)
 for k in ('rng','seed','run_id'):x['run'].pop(k,None)
 x['combat']['queue']=[]
 x['combat']['draw'].sort(key=lambda c:json.dumps(c,sort_keys=True))
 return x

def independently_check(row):
 d=row['decision'];cmd=d['action'];pattern=row['pattern']
 return {
 'live_state_unchanged':row['before']==row['after_query'],
 'second_query_unchanged':row['permuted_before']==row['permuted_after'],
 'public_frame_retained':frame(row['before'])==frame(row['clone_before']),
 'hidden_change_is_private':frame(row['before'])==frame(row['permuted_before']),
 'hidden_input_independent':d==row['permuted_decision'],
 'intervention_flags_retained':row['flags']==row['clone_flags'],
 'legal_action':cmd in d['legal_candidates'],
 'paid_play_succeeded':cmd['t']!='playCard' or row['clone_after']['return'] is True,
 'does_not_choose_known_fatal_source':not(pattern==2 and cmd['t']=='playCard' and cmd.get('uid')==100),
 'fixed_two_samples':d['root_rollouts']==2*len(d['legal_candidates']),
 'content_readonly':row['content_before']==row['content_after'],
 'rule_switches_readonly':row['flags_before']==row['flags_after'],
 'same_public_determinization':row['clone_before']==row['clone_hidden']}


def analyze(root,source_binding):
 root=Path(root);rows={};failed=[];old_mismatches=0;raw_manifest=[]
 expected=set(itertools.product((0,1),(0,5),(False,True),(0,1,2),(False,True),('balanced','hand')))
 require({p.name for p in root.glob('*.jsonl')}=={m+'.jsonl' for m in MODES},'MODE_COVERAGE')
 for mode in MODES:
  p=root/(mode+'.jsonl');data=p.read_bytes();lines=[json.loads(x) for x in data.splitlines()]
  require(len(lines)==98,'ROW_COUNT:'+mode)
  h,t=lines[0],lines[-1]
  require(h['kind']=='header' and h['mode']==mode and h['params']==PARAMETERS,'HEADER')
  require(h['engine']=='4.7.2-stable (official)','ENGINE')
  ref=source_binding['runtime']['baseline' if mode=='baseline' else 'candidate']
  for field,path in [('content_sha256','content/full-content.json'),('combat_sha256','domain/rules/combat.gd')]:
   require(h[field]==ref[path]['sha256'],'RUNTIME_IDENTITY')
  require(t['kind']=='terminal' and t['cases']==96,'TERMINAL_COUNT')
  indexed={}
  for r in lines[1:-1]:
   require(r['kind']=='case' and r['mode']==mode and set(r['checks'])==set(CHECKS),'CASE_SHAPE')
   key=tuple(r[k] for k in KEYS);require(key not in indexed,'DUPLICATE_CASE');indexed[key]=r
   require(all(type(v) is bool for v in r['checks'].values()),'BOOLEAN_CHECKS')
   recomputed=independently_check(r)
   require(all(r['checks'][k]==v for k,v in recomputed.items()),'CHECK_RECONCILIATION')
   for k,v in r['checks'].items():
    if not v:failed.append({'mode':mode,'case':key,'check':k})
   old_mismatches+=int(r['flags']!=r['unadapted_flags'])
  require(set(indexed)==expected,'FULL_ASSIGNMENT')
  require(t['failed_checks']==sum(not v for r in lines[1:-1] for v in r['checks'].values()),'TERMINAL_FAILURE_COUNT')
  rows[mode]=indexed;raw_manifest.append({'path':p.name,'bytes':len(data),'sha256':sha(data)})
 # Mode/flag metadata is not part of the native game observation being compared.
 null_fields=('before','after_query','permuted_before','permuted_after','decision','permuted_decision','clone_before','clone_after','events')
 null_pairs=0
 for mode in MODES[1:]:
  for key,r in rows[mode].items():
   if mode!='off' and r['aspect']!=0:continue
   b=rows['baseline'][key];null_pairs+=1
   for field in null_fields:
    if r[field]!=b[field]:failed.append({'mode':mode,'case':key,'check':'BASELINE_NULL:'+field})
 require(old_mismatches>0,'NO_REGRESSION_WITNESS_FOR_RULE_SWITCH_ADAPTER')
 return {'status':'PLANNER_CURRENT_RUNTIME_COMPATIBILITY_PASS' if not failed else 'PLANNER_CURRENT_RUNTIME_COMPATIBILITY_FAIL',
 'constructed_cases':480,'checks_per_case':len(CHECKS),'baseline_null_pairs':null_pairs,'failed_checks':failed,
 'unadapted_clone_switch_mismatches':old_mismatches,'original_v25_studies_repeated':False,
 'parameters':PARAMETERS,'raw':raw_manifest,'scope':'Existing planner source plus explicit intervention-switch propagation. Finite legality, isolation, public-state and off/Dusk compatibility only.',
 'limits':['No optimality or whole-run performance claim.','No matched-cost planner value or package certificate yet.','Unchanged heuristic continuation and finite horizon may omit long-horizon setup value.','Acquisition adapter remains not admitted. No old outcomes are transported.'],
 'new_independent_samples':0,'packages_admitted':0,'p9_certified':False}

if __name__=='__main__':
 import sys
 print(json.dumps(analyze(sys.argv[1],json.loads(Path(sys.argv[2]).read_bytes())),indent=2))
