"""Synchronise the completed planner frontier from verified terminal evidence.
No native process, policy, cohort, timing or scientific criterion is changed.
"""
from __future__ import annotations
import copy,hashlib,json,math,sys
from pathlib import Path

ROOT=Path('research/p9-six-route')
PLANNER=ROOT/'ash-inheritance-20260909/planner-v1'
STUDY=PLANNER/'resource-requalification-v1'
STATES={
 'OPTIMIZED_PLANNER_VALUE_AND_PAIR_SUPPORT_PASS_NOT_CERTIFICATE',
 'FIXED_OPTIMIZED_PLANNER_PAIR_SUPPORT_NOT_ESTABLISHED',
 'FIXED_OPTIMIZED_PLANNER_VALUE_NOT_ESTABLISHED',
 'IMPLEMENTATION_RESOURCE_REQUALIFICATION_FAIL','INCONCLUSIVE'}
PHASES=('value-screen','reserved-configuration-check')


def require(ok,why):
    if not ok:raise ValueError(why)
def encoded(x):return (json.dumps(x,indent=2)+'\n').encode()
def sha(b):return hashlib.sha256(b).hexdigest()
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()

def summarize(t,rb,old,contract):
    status=t['status'];require(status in STATES,'UNKNOWN_TERMINAL')
    require(t.get('packages_admitted')==0 and t.get('p9_certified') is False,'ADMISSION_NOT_JUSTIFIED')
    require(old['status']=='INCONCLUSIVE' and old['failure']=="ValueError('MATCHED_RESOURCE_CEILING')",'OLD_TERMINAL_NOT_PRESERVED')
    require(t['old_terminal_unchanged'] is True,'OLD_TERMINAL_CHANGED')
    require(rb['all_bytes_equal'] is True and rb['old_terminal_unchanged'] is True,'NO_VERIFIED_CAPTURE')
    require(rb['scientific_status']==status and rb['reproduced_stages']==list(t['stages']),'READBACK_TERMINAL_BINDING')
    require(rb['old_v5_replays_counted_as_independent'] is False,'FALSE_INDEPENDENCE')
    require(contract['unchanged_inputs']['cpu_seconds_per_method_per_vow']==3600,'RESOURCE_LIMIT_CHANGED')
    details={};total_replay_rows=0;new_v0_rows=0
    for vow,s in t['stages'].items():
        require(vow in ('5','0'),'UNASSIGNED_VOW')
        costs={'stock':0.0,'planner':0.0};blocks={}
        for phase in PHASES:
            if phase not in s:continue
            v=s[phase];count=32 if phase==PHASES[0] else 96;n=count*4
            require(v['configurations']==count and v['rows_per_method']==n,'FIXED_BLOCK_SHAPE')
            require(0<=v['stock_wins']<=n and 0<=v['planner_wins']<=n,'INVALID_WINS')
            require(v['point_difference']==(v['planner_wins']-v['stock_wins'])/n,'WIN_DIFFERENCE')
            for m in costs:
                c=v['costs'][m]['process_cpu_seconds']
                require(math.isfinite(c) and c>=0,'INVALID_COST');costs[m]+=c
            require(v['resource_ceiling_met']==all(c<=3600 for c in costs.values()),'CUMULATIVE_RESOURCE')
            require(v['pass']==all(v['gates'].values()),'VALUE_GATE_BINDING')
            blocks[phase]={'rows_per_method':n,'stock_wins':v['stock_wins'],'planner_wins':v['planner_wins'],
                'point_difference':v['point_difference'],'conditional_configuration_interval':v['configuration_bootstrap_interval'],
                'value_pass':v['pass'],'resource_ceiling_met':v['resource_ceiling_met']}
            if vow=='5':total_replay_rows+=2*n
            else:new_v0_rows+=2*n
        resource=len(blocks)==2 and all(b['resource_ceiling_met'] for b in blocks.values())
        value=len(blocks)==2 and all(b['value_pass'] for b in blocks.values())
        detail={'fixed_blocks':blocks,'actual_cpu_seconds':costs,'complete_resource_qualified':resource,'complete_value_pass':value,
            'support_observed':'support' in s,'support_pass':s.get('support_pass',False)}
        if 'support' in s:
            require(resource and value,'SUPPORT_WITHOUT_PREREQUISITES')
            require(s['support_pass']==s['support']['planner']['pass'],'SUPPORT_BINDING')
            detail['support']={m:{k:v for k,v in s['support'][m].items() if k in ('packages','gates','pass','outcomes','cross_active','counterfactual_checks','incremental_hp_policies')}
                               for m in ('stock','planner')}
        details[vow]=detail
    if '0' in details:require(details['5']['support_pass'] is True,'V0_WITHOUT_V5')
    if status=='OPTIMIZED_PLANNER_VALUE_AND_PAIR_SUPPORT_PASS_NOT_CERTIFICATE':
        require(set(details)=={'5','0'} and all(d['support_pass'] for d in details.values()),'INCOMPLETE_PASS')
        next_action=('Use the now-qualified exact planner only within its bound public-state and resource contract. '
          'Freeze the missing complete producer/mediator/consumer/subset, descriptor, peer-separation and independently assigned confirmation evidence for the inherited Ash packages together. '
          'No further controller tuning or repeat support study. Other slots still require complete eligible non-equivalent packages before new population work.')
    elif status=='FIXED_OPTIMIZED_PLANNER_PAIR_SUPPORT_NOT_ESTABLISHED':
        require(any(d['support_observed'] and not d['support_pass'] for d in details.values()),'MISSING_SUPPORT_FAILURE')
        next_action=('Keep the exact optimized-controller support branch closed. Use all retained acquisition/action/source traces to identify the concrete remaining support or competence boundary, without new native rows, root changes or parameter tuning. '
          'Only a different, source-bound acceptance obligation or eligible package can justify subsequent research; neither high wins nor a faster controller overrides the closed support failure.')
    elif status=='IMPLEMENTATION_RESOURCE_REQUALIFICATION_FAIL':
        require(any(not b['resource_ceiling_met'] for d in details.values() for b in d['fixed_blocks'].values()),'MISSING_RESOURCE_FAILURE')
        next_action=('Preserve the failed full-workload resource requalification and all positive same-decision evidence. '
          'Do not rerun the same cohort, extrapolate microbenchmark speed, increase3600, or aggregate blocked support. '
          'A further implementation change must first identify and eliminate a measured remaining cost with exact semantic proof; absent that evidence, change the eligible research design rather than repeat performance trials.')
    elif status=='INCONCLUSIVE':
        next_action='Inspect only the exact retained delivery failure and complete available outputs. No outcome, resource or support PASS is inferred; do not replay complete cells or alter scientific rules.'
    else:
        next_action='Preserve the fixed optimized planner value negative. No second policy/root/weight choice from these observations; use only a separately supported missing acceptance obligation or eligible package.'
    return {'kind':'COMPLETE_CURRENT_PLANNER_FRONTIER','status':status,'stages':details,
        'old_value_terminal_preserved':True,'whole_vow_resource_limit_seconds':3600,
        'same_assignment_v5_replay_rows':total_replay_rows,'newly_opened_v0_outcome_rows':new_v0_rows,
        'independent_package_confirmation_samples':0,'capture_files_verified':rb['files'],
        'v5_cells_reconciled':rb['original_v5_cells_reconciled'],'next_action':next_action,
        'limits':['Configuration intervals are conditional on four common seeds, not independent seed confirmation.',
                  'Hand necessary activation remains distinct from complete producer causality.',
                  'Bloodfire stock/consumer clones do not establish an adaptive whole-run producer intervention.',
                  'A complete controller value/support test still does not certify packages, the detector, retention or P9.'],
        'new_native_runs_in_closure':0,'packages_admitted':0,'p9_certified':False,
        'review':'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT'}

def updated_state(state,decision):
    require(state['packages_admitted']==0 and state['p9_certified'] is False,'UNEXPECTED_CURRENT_ADMISSION')
    old=copy.deepcopy(state);new=copy.deepcopy(state)
    new['status']='P9_UNFINISHED_'+decision['status']
    new['exact_next_action']=decision['next_action']
    new['planner_frontier_20260910']=decision
    allowed={'status','exact_next_action','planner_frontier_20260910'}
    require(all(new[k]==v for k,v in old.items() if k not in allowed),'HISTORICAL_STATE_CHANGED')
    return new

def close(repo):
    repo=Path(repo).resolve();root=repo/STUDY;out=root/'closure-1';require(not out.exists(),'CLOSURE_EXISTS')
    names={'terminal':STUDY/'execution-1/TERMINAL.json','readback':STUDY/'execution-1/REMOTE-READBACK.json',
           'old':PLANNER/'value-v1/execution-2/TERMINAL.json','contract':STUDY/'PROTOCOL.json',
           'cache':PLANNER/'continuation-integer-v1/execution-1/RESULTS.json',
           'profile':PLANNER/'profile-v1/execution-1/RESULTS.json'}
    inputs={};records=[]
    for name,path in names.items():
        data=(repo/path).read_bytes();inputs[name]=json.loads(data)
        records.append({'path':str(path),'bytes':len(data),'sha256':sha(data),'git_blob':blob(data)})
    require(sha((repo/names['old']).read_bytes())==inputs['terminal']['old_terminal_sha256'],'OLD_TERMINAL_BYTES')
    require(sha((repo/names['cache']).read_bytes())==inputs['contract']['cache_result_sha256'],'CACHE_ENTRY_BYTES')
    require(inputs['cache']['status']=='EXACT_CONTINUATION_CACHE_SPEEDUP_ESTABLISHED','CACHE_ENTRY')
    decision=summarize(inputs['terminal'],inputs['readback'],inputs['old'],inputs['contract'])
    decision['source_inputs']=records
    decision['microbenchmark_cpu_ratios']=inputs['cache']['memo_reference_cpu_ratios']
    decision['profile_scope']=inputs['profile']['scope']
    decision['measured_root_time_fractions']=inputs['profile']['root_time_fractions']
    state_path=repo/ROOT/'SESSION-STATE.json';old_state=state_path.read_bytes();state=json.loads(old_state)
    new_state=updated_state(state,decision);out.mkdir()
    (out/'DECISION.json').write_bytes(encoded(decision));(out/'INPUTS.json').write_bytes(encoded(records))
    (out/'STATE-PRESERVATION.json').write_bytes(encoded({'old_state_sha256':sha(old_state),
       'historical_fields_preserved':True,'changed_current_fields':['status','exact_next_action','planner_frontier_20260910']}))
    state_path.write_bytes(encoded(new_state))
    paragraphs=['# P9 current handoff — complete planner frontier, no repeated recovery',
      'Continue #421 on research/p9-six-route-local-20260905. Main remains 2ed6cdb0302ba3aab5845a18d862841165e8aaf7. Three complete viable/reachable/distinct packages per aspect; still0/6. Author review is explicitly non-independent.',
      '## Closed and preserved',
      'Minimum Bloodfire preflight and signed RandomBuild screen passed. Shipping pair support and the acquisition-only adapter retain their exact negatives. Original planner V5 value showed46->344 wins/512 but used4015.74 CPU seconds against3600: its INCONCLUSIVE terminal is unchanged. No historical outcomes are refitted or renamed.',
      'Profile of the predetermined old eight-run cell identified greedy continuation as the main cost. Root memo and continuation memo without integer refinement did not meet their speed claim. The safe integer/continuation refinement passed exact-output, mutation and alternating timing checks. These are delivery facts, not packages.',
      '## Current complete outcome',f'`{decision["status"]}`. Read resource-requalification-v1/closure-1/DECISION.json for exact per-vow value, total CPU and support. The complete native capture and subsequent cold byte readback are in resource-requalification-v1/execution-1. No microbenchmark ratio is substituted for the whole-workload cost.',
      'All reported V5 replays retain their original trajectory identities and count as zero new independent samples. Only stages actually opened by the fixed gates are reported. No scientific negative, protected identity or parameter was reset.',
      '## Exact next action',decision['next_action'],
      'Do not repeat recovery/reunion/census, v25, frozen models, aliases, Hand bulk support, failed bulk candidates, minimum preflight/signed screen, acquisition-v1, complete planner value/compatibility/cache/profile work. The historical raw gaps and source-scope limits remain in SESSION-STATE.json.',
      '## Remaining P9 milestones',
      'Six full exact-current package certificates; seven-direction detector; corrected independent confirmation and unrestricted endpoint retention; all hard guardrails; minimum lifecycle, exact-head review under current authority, one selected exact-product integration and #108 receipt. A fast solver or green runner is not a P9 PASS. No research process is started by this closure.']
    (repo/ROOT/'SESSION-HANDOFF.md').write_text('\n\n'.join(paragraphs)+'\n')
    roadmap=repo/ROOT/'package-disposition-20260908/ROADMAP.md'
    roadmap.write_text('# P9 current outcome roadmap\n\nCurrent exact terminal: `'+decision['status']+'`. Full certificates:0/6.\n\n'+decision['next_action']+'\n\n'
      '1. Complete the first inherited Ash certificate with actual complete-chain, descriptor, competent-policy, peer and real-economy evidence; reuse only unchanged qualified dependencies.\n'
      '2. Fill three independently validated strategies per aspect. Check exact registered/closed identities before proposing additional complete mechanisms; do not revive failed labels or substrates.\n'
      '3. Admit seven-direction detector, corrected untouched confirmation and unrestricted endpoint retention with every existing hard guardrail.\n'
      '4. Integrate only one selected minimal product/detector/lifecycle packet, review exact head, and post the merged-product P9 receipt to #108.\n\n'
      'Detailed completed decisions and immutable evidence identities remain in SESSION-STATE.json and each frozen terminal. No new native execution, independent sample, cost relaxation or admission is created by this roadmap.\n')
    print(json.dumps({'status':decision['status'],'stages':list(decision['stages']),'new_native_runs':0,'packages_admitted':0},indent=2))

if __name__=='__main__':close(sys.argv[1])
