"""Close the two tested catalogue paths. No new simulation or acceptance rule.

This reads immutable results and their remote receipts, then updates ONLY current
capsule/roadmap fields. It cannot alter a historical protocol, result or source.
"""
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import sys

FAIL = 'SIGNED_CONTROL_NECESSARY_SCREEN_FAIL'
OLD = '3c7b2f9dba362d19128ef82ad559d3f26e54925371d823a665767032255eadaa'
RESTORED = '91fd5de56727df42fdcb539b61e7cc7a32e77f3f85dbbe13baef3513e7003cfb'
BINDINGS = {
 'guardrail-confirmation-20260909/native-1/RESULTS.json': 'c3653360280ca5444d5b5e5c2183e14d7cc34a9c',
 'candidate-failure-20260909/native-1/RESULTS.json': 'bf62b583f67f51339432afe3ffb1a203dd08c540',
 'candidate-failure-20260909/REMOTE-READBACK.json': 'b13581d6dfdcbee77f99b2d6fca18a5edb26882a',
 'native-foundation-20260909/native-1/RESULTS.json': 'be70514cd3c0754ebbf4f83316a742a65c29a588',
 'native-foundation-20260909/REMOTE-READBACK.json': 'f0a23cdfd367fddade284e2f0897c75ff5a50b85',
}
NEXT = ('Do not run another whole-catalogue scalar/rollback trial. The tested bulk '
        'candidate and its one native-Ash restoration are closed. The next owned '
        'deliverable is one source-complete, minimal Smolder/Fervor package contract '
        'against unchanged main: exact producer, mediator, consumer, reset, costs, '
        'target/instance identity, real acquisition path and relevant closed/admitted '
        'family comparison, with an executable distinguishing or decomposition '
        'witness. A new candidate may be nominated only from a surviving contract, '
        'not from changing a number to cross these exposed screens. Reuse unchanged '
        'source-law facts; do not transfer old outcomes or reopen Hand. Then freeze '
        'its cheapest decisive controls before any larger population/confirmation '
        'work. This is research design still to be completed, not a new package PASS '
        'or a renewed quota/reviewer checkpoint.')


def require(ok, why):
    if not ok: raise ValueError(why)


def blob(data):
    return hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, indent=2)+'\n')


def screen(result):
    require(result['status'] == FAIL and result['rows'] == 1024, 'COMPLETE_NEGATIVE')
    require(result['p9_certified'] is False and result['packages_admitted'] == 0, 'NO_PROMOTION')
    keys = [(r['aspect'], r['vow']) for r in result['grids']]
    require(len(keys) == 4 and set(keys) == {('duskblade',0),('duskblade',5),('ashwarden',0),('ashwarden',5)}, 'GRID')
    bad=[]
    for r in result['grids']:
        n,b,c=r['n'],r['baseline_wins'],r['candidate_wins']
        require(n == 128 and all(type(v) is int and 0<=v<=n for v in (b,c)), 'COUNTS')
        expected={'candidate_random_build_at_most_half':2*c<=n,
                  'absolute_random_build_movement_at_most_tenth':10*abs(c-b)<=n,
                  'candidate_fault_free':True}
        require(r['gates']==expected and r['baseline_faults']==0, 'GUARD_RECOMPUTATION')
        require(r['difference']==(c-b)/n, 'DIFFERENCE')
        if not all(expected.values()):
            bad.append({'aspect':r['aspect'],'vow':r['vow'],'n':n,
                        'baseline_wins':b,'candidate_wins':c,'difference':(c-b)/n,
                        'failed_gates':[k for k,v in expected.items() if not v]})
    require(bad, 'NEGATIVE_NEEDS_FAILURE')
    return bad


def main(repo):
    root=Path(repo).resolve()/'research/p9-six-route'
    data={}; inputs=[]
    for name,expected in BINDINGS.items():
        raw=(root/name).read_bytes();require(blob(raw)==expected,'IMMUTABLE_INPUT:'+name)
        data[name]=json.loads(raw)
        inputs.append({'path':name,'bytes':len(raw),'git_blob':expected,
                       'sha256':hashlib.sha256(raw).hexdigest()})
    old=data['guardrail-confirmation-20260909/native-1/RESULTS.json']
    new=data['native-foundation-20260909/native-1/RESULTS.json']
    diag=data['candidate-failure-20260909/native-1/RESULTS.json']
    old_bad,new_bad=screen(old),screen(new)
    require([diag['cells'][k]['wins'] for k in ('00','01','10','11')]==[29,10,30,10], 'FACTORS')
    require(diag['old_outcomes_reused']==256 and diag['new_diagnostic_outcomes']==256, 'REUSE')
    require(diag['original_screen_status']==FAIL and diag['new_independent_confirmation_samples']==0, 'DIAGNOSTIC_SCOPE')
    for name,count in [('candidate-failure-20260909/REMOTE-READBACK.json',29),('native-foundation-20260909/REMOTE-READBACK.json',53)]:
        require(data[name]['files_matched']==count, 'REMOTE_RECEIPT')
    decision={'status':'TESTED_BULK_CANDIDATE_AND_SINGLE_RESTORATION_CLOSED',
      'frozen_failed_candidates':[{'content_sha256':OLD,'failed_grids':old_bad},
                                  {'content_sha256':RESTORED,'failed_grids':new_bad}],
      'causal_diagnostic':{'joint_substrate_effect_in_baseline_net_wins':-19,
         'joint_substrate_effect_in_candidate_net_wins':-20,'factor_interaction_net_wins':-1,
         'scope':'Original exposed Ash V0 assignment only; no individual Core-vs-Art attribution or population theorem.'},
      'new_raw_this_continuation':{'diagnostic_outcomes':256,'disjoint_control_outcomes':1024,
         'independent_package_confirmations':0},
      'candidate_selected_for_further_population_certification':None,
      'next_action':NEXT,'inputs':inputs,'historical_hand_claims_revoked':False,
      'hand_fixed_support_failure_unchanged':True,'universal_nonviability_proved':False,
      'rounding_or_pooled_samples_used_to_rescue_failure':False,
      'native_runs_in_this_closure':0,'packages_admitted':0,'p9_certified':False,
      'review':'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT'}
    folder=root/'candidate-decision-20260909';folder.mkdir(exist_ok=True)
    write(folder/'DECISION.json',decision)
    state_path=root/'SESSION-STATE.json';state=json.loads(state_path.read_bytes());before=deepcopy(state)
    require(state['candidate_sha256']==OLD and state['packages_admitted']==0 and not state['p9_certified'], 'CURRENT_CAPSULE_BINDING')
    state['status']='P9_UNFINISHED_BULK_AND_NATIVE_RESTORATION_SCREEN_PATHS_CLOSED'
    state['exact_next_action']=NEXT
    state['no_active_research_processes']=True
    state['latest_candidate_decision']={'path':'candidate-decision-20260909/DECISION.json',
      'sha256':hashlib.sha256((folder/'DECISION.json').read_bytes()).hexdigest(),
      'frozen_failed_candidates':decision['frozen_failed_candidates'],
      'current_promotion_candidate':None,'hand_support_reopened':False,
      'input_content_field_scope':'candidate_sha256 still binds historical studies; it is NOT an active promotion claim.'}
    for key in ('candidate_sha256','descriptor_sha256','validation','original_arms','hand_support','review','packages_admitted','p9_certified'):
        require(state[key]==before[key], 'HISTORICAL_FIELD_MUTATION:'+key)
    write(state_path,state)
    handoff=root/'SESSION-HANDOFF.md'
    # Keep earlier handoff text as history, but put the latest single frontier first.
    oldtext=handoff.read_text()
    prefix=('## Latest authoritative frontier — two candidate paths are closed\n\n'
      'The original signed-control screen and the one native-Ash restoration both '
      'failed their frozen point-scale gate. All 29 diagnostic and 53 restoration '
      'files were cold-read and the original readouts reconstructed. The two new '
      'diagnostic corners gave 10/128 and 30/128; the independent restoration '
      'Ash V0 comparison gave 15/128 baseline vs 28/128 restored candidate. '
      '13/128 exceeds 0.1; do not round, pool with diagnostic seeds, retry, or extend.\n\n'
      +NEXT+'\n\n'
      'Read candidate-decision-20260909/DECISION.json. P9 remains incomplete, '
      '0/6 exact-current certificates. Tools/remote storage are functioning; the '
      'remaining work is a new source-complete design decision, not recovery or '
      'permission renewal. Neither failure establishes universal impossibility.\n\n')
    marker='## Latest authoritative frontier — two candidate paths are closed\n'
    require(marker not in oldtext, 'ALREADY_CLOSED_DO_NOT_REPEAT')
    handoff.write_text('# P9 current frontier\n\n'+prefix+'---\n\n'+oldtext)
    roadmap=root/'package-disposition-20260908/ROADMAP.md';text=roadmap.read_text()
    require('## 9 September 2026: executed candidate-path decisions' not in text, 'ROADMAP_ALREADY_UPDATED')
    roadmap.write_text('# Current P9 delivery path\n\n## 9 September 2026: executed candidate-path decisions\n\n'
      'Hand preflight/support, source disposition, whole-candidate signed controls, '
      'the missing-only two-corner causal diagnosis and ONE restoration alternative '
      'are complete. Hand V0 and both catalogue screens are closed negatives. '
      'Do not continue the obsolete Hand-first population route below.\n\n'+NEXT+'\n\n'
      'The still-required delivery milestones remain: complete three packages per '
      'aspect; seven-direction detector; corrected independent confirmation and '
      'unrestricted endpoint retention with every guardrail; minimal lifecycle '
      'and exact-product integration/#108 receipt. Earlier local/finite passes '
      'are reusable only with correct scope and identity, not admission by accumulation.\n\n'
      '---\n\n## Earlier disposition (retained scope, superseded execution order)\n\n'+text)


if __name__=='__main__':main(sys.argv[1])
