"""Close the completed controller experiment; retain partial claims and negatives.
No engine or empirical cohort is run, and no admission criterion is amended.
"""
from __future__ import annotations
import copy
import hashlib
import json
from pathlib import Path
import sys
import unittest
import compare_value

REL=Path('research/p9-six-route/ash-inheritance-20260909/acquisition-v1')
INPUT_BLOBS={
    'execution-2/TERMINAL.json':'e393fcceaf7334bb8732d65abd7270beec52ef21',
    'execution-2/REMOTE-READBACK.json':'1b069bd5a01e10702a0d14ddb0d50ccb7d159366',
    'execution-2/qualification/RESULTS.json':'8f2affe93d997a2cf644cd3944baf743ebd69eeb',
    'repair-1/DIAGNOSIS.json':'1bbcaf7161e25469bc721d8f413199117e7860e6'}
NEXT=('Do not repeat or retune acquisition-v1. Source-bind the already evidenced public-state '
      'planning controller from the preserved v25 source only, without executing its closed studies '
      'or using their held-out outcomes for tuning. Establish compatibility with the exact minimum '
      'Bloodfire runtime and keep signed RandomBuild unchanged. A separate controller capability '
      'contract and decisive matched-cost value test are prerequisites to using it; no replacement '
      'controller, weight, cohort or product change is selected by this failed adapter. Complete '
      'causal/descriptor/viability and independent evidence is still required before package admission.')


def require(ok,why):
    if not ok:raise ValueError(why)


def encoded(x):return (json.dumps(x,indent=2)+'\n').encode()


def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()


def verdict(t,r,q):
    require(t['status']=='FIXED_ACQUISITION_ADAPTER_NOT_ADMITTED','UNEXPECTED_TERMINAL')
    require(list(t['stages'])==['5'] and t['v0_skipped'] is True,'STAGE_BOUNDARY')
    require(r['all_bytes_equal'] is True and r['reproduced_stages']==['5'] and r['scientific_status']==t['status'],'UNVERIFIED_CAPTURE')
    require(q['status']=='ACQUISITION_CAPABILITY_AND_NULL_PASS','UNQUALIFIED_INTERFACE')
    c=t['stages']['5'];failed=[k for k,v in c['gates'].items() if not v]
    require(failed==['win_point_not_worse'] and not c['pass'],'UNEXPECTED_GATE_SET')
    p=compare_value.probability(c['gained_policies'],c['lost_policies'])
    require(p==c['one_sided_exact_sign_p'],'EXACT_SIGN_TEST')
    require((c['activation_new']-c['activation_old'])/128==c['paired_activation_difference'],'ACTIVATION_RECONCILIATION')
    sw,aw=c['stock_outcomes']['win'],c['aware_outcomes']['win']
    require(sum(c['stock_outcomes'].values())==sum(c['aware_outcomes'].values())==512,'PAIRED_COVERAGE')
    require((aw-sw)/512==c['win_difference'],'WIN_RECONCILIATION')
    return {'status':'ACQUISITION_EXPERIMENT_CLOSED_WITH_SCOPED_POSITIVE_SUPPORT_AND_VALUE_FAILURE',
      'controller_value_admitted':False,'qualified_public_acquisition_interface':True,
      'both_inherited_packages_have_v5_support_in_aware_arm':c['gates']['inherited_pair_support'],
      'other_vow_support_observed':False,'both_vow_pair_certificate':False,
      'point_win_difference':c['win_difference'],'stock_wins':sw,'aware_wins':aw,
      'paired_configuration_bootstrap_interval':c['policy_cluster_bootstrap_interval'],
      'activation_old':c['activation_old'],'activation_new':c['activation_new'],
      'gained_configurations':c['gained_policies'],'lost_configurations':c['lost_policies'],
      'exact_one_sided_sign_p':p,'stock_support':c['stock_support'],'aware_support':c['aware_support'],
      'failed_fixed_gates':failed,'v0_skipped':True,'comparison_outcomes':1024,
      'qualified_query_cases':q['query_checks'],'complete_capture_files_cold_checked':r['files'],
      'interpretation':['The nominated acquisition adapter changes observed activation under the matched fixed assignment; this does not identify every cause of previous losses.',
        'Two fewer wins fail the frozen point-win criterion. The reported interval crosses zero: no statistically established universal harm is claimed.',
        'Passing the separate noninferiority criterion cannot override the failed point criterion.',
        'Neither the original fixed-family support failure nor earlier product negatives are replaced.',
        'V5 pair support is retained as scoped positive evidence, not a current full certificate or permission to continue the skipped V0 stage.'],
      'next_action':NEXT,'new_native_runs_in_closure':0,'new_independent_samples':0,
      'packages_admitted':0,'p9_certified':False,'review_kind':'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT'}


def close(repo):
    repo=Path(repo);root=repo/REL;out=root/'closure-1'
    require(not out.exists(),'OUTPUT_EXISTS')
    inputs={};identities={}
    for rel,want in INPUT_BLOBS.items():
        b=(root/rel).read_bytes();require(blob(b)==want,'INPUT_BLOB:'+rel)
        inputs[rel]=json.loads(b);identities[rel]={'git_blob':want,'sha256':hashlib.sha256(b).hexdigest(),'bytes':len(b)}
    t=inputs['execution-2/TERMINAL.json'];r=inputs['execution-2/REMOTE-READBACK.json'];q=inputs['execution-2/qualification/RESULTS.json']
    decision=verdict(t,r,q)
    old=json.loads((root/'PROTOCOL.json').read_bytes());new=json.loads((root/'repaired-source-1/PROTOCOL.json').read_bytes())
    check=copy.deepcopy(new);check['own_sha256']['capability.gd']=old['own_sha256']['capability.gd']
    require(check==old,'NON_ORACLE_CONTRACT_CHANGE')
    require(inputs['repair-1/DIAGNOSIS.json']['old_populations_run']==0,'OLD_POPULATION_EXPOSURE')
    for name,want in old['own_sha256'].items():
        if name=='capability.gd':continue
        a=(root/name).read_bytes();b=(root/'repaired-source-1'/name).read_bytes()
        require(a==b and hashlib.sha256(b).hexdigest()==want,'CONTROLLER_OR_ANALYSIS_CHANGED:'+name)
    p=repo/'research/p9-six-route/SESSION-STATE.json';state=json.loads(p.read_bytes());before=copy.deepcopy(state)
    require(state['packages_admitted']==0 and not state['p9_certified'],'UNEXPECTED_ADMISSION_CHANGE')
    state['status']='P9_UNFINISHED_QUALIFIED_ACQUISITION_V5_SUPPORT_POSITIVE_VALUE_FAIL'
    state['exact_next_action']=NEXT
    state['bloodfire_acquisition_controller']={
       'source_head':t['source_head'],'status':t['status'],'vow5_comparison':t['stages']['5'],
       'v0_skipped':True,'controller_qualified':True,'controller_value_admitted':False,
       'complete_raw_remote_verified':True,'readback':'ash-inheritance-20260909/acquisition-v1/execution-2/REMOTE-READBACK.json',
       'decision':'ash-inheritance-20260909/acquisition-v1/closure-1/DECISION.json',
       'old_expected_weight_oracle_failure_preserved':True,'old_controller_population_rows':0,
       'new_full_package_certificates':0}
    changed=[k for k,v in before.items() if state.get(k)!=v]
    require(set(changed)<={'status','exact_next_action'},'HISTORICAL_STATE_OVERWRITE')
    out.mkdir();(out/'DECISION.json').write_bytes(encoded(decision));(out/'INPUTS.json').write_bytes(encoded(identities))
    (out/'STATE-PRESERVATION.json').write_bytes(encoded({'changed_existing_keys':changed,'all_other_existing_values_identical':True}))
    p.write_bytes(encoded(state))
    handoff='''# P9 current handoff — qualified acquisition improves support, value test closed

Continue #421 on research/p9-six-route-local-20260905. Product main remains
2ed6cdb0302ba3aab5845a18d862841165e8aaf7. Target: three complete viable, reachable,
functionally distinct packages per aspect. Still 0/6 full current certificates;
no P9 PASS or product promotion. Author self-review is not independent evidence.

## Closed decisions; do not replay

Minimum Bloodfire preflight and its 1,024-row signed RandomBuild screen passed.
Signed grids: Dusk V0 31/128->31/128, V5 7->7; Ash V0 25->27, V5 4->4.
The screen's integer-key JSON readback defect was repaired without game replay.

pair-v1 completed 512 V5 runs: Bloodfire active15/inactive113/reachable19/
exclusive9 and Hand35/93/36/29; Bloodfire<32 closed that fixed family, V0 skipped.
All 249 consumer clone rectangles passed their full factual/state/null checks.
The 146-file cold capture and full-row bottleneck audit are already complete.

acquisition-v1 tested ONE historically grounded acquisition-only adapter, no
fitted values. Query qualification first failed30 of9851 cases because its oracle
read raw policy floats while the scorer uses float(str(value)). The old capture
has zero population rows. Only three oracle casts were corrected; controller,
cohort and criteria stayed identical; exact equality was not relaxed. The new
9851-case qualification, four signed RandomBuild and eight observer pairs passed.

The full fresh V5 stock/aware comparison completed1024 outcomes. Bloodfire active
11->42 (33 gained,2 lost); exact paired sign p1.8364517018198967e-08. Aware V5
support passes: Bloodfire42/86/45/21, Hand37/91/38/16 (active/inactive/reachable/
exclusive). This is scoped support, not full Hand causality, viability or P9.

The adapter nevertheless FAILS its frozen point-win criterion: stock55/512,
aware53/512. The paired configuration interval[-.01953125,.01171875] crosses
zero; do not claim proven population harm, nor use that interval to override the
fixed negative. Controller admission remains false; V0 was NOT run. No more
weights, partner formulas or policy roots are selected by this result.

All292 corrected-experiment files were cold-read and the complete V5 result
reconstructed; original qualification/correction records remain separately
preserved. See acquisition-v1/closure-1/DECISION.json and execution-2/REMOTE-READBACK.json.

## Exact continuation

'''+NEXT+'''

Do not repeat recovery/reunion/census, v25, frozen models, aliases, native capacity,
Hand bulk support, either bulk-content negative, minimum preflight, signed screen,
pair-v1 or acquisition-v1. Do not reinstate historical failed substrates. Earlier
positive evidence and raw-preservation gaps in SESSION-STATE.json remain explicit.

## Remaining product-critical claims

First complete source-bound viable package certificates with actual causal,
policy/economy/descriptor and independently assigned confirmation evidence.
Hand/Bloodfire retain inherited directions but neither gets full current admission
from this work. Additional slots need genuinely different eligible packages.
Then seven-direction detector, corrected independent confirmation, unrestricted
endpoint retention and every hard guardrail; only then minimal lifecycle and one
exact-product integration/#108 receipt. No native process remains running.
'''
    (repo/'research/p9-six-route/SESSION-HANDOFF.md').write_text(handoff)
    roadmap='''# P9 — current outcome roadmap

## Evidence-led frontier

Minimum Bloodfire source/null preflight and signed controls PASS. The initial
shipping-family pair support FAIL remains. One acquisition-only adapter now
passes source/null capability and supplies both inherited packages' V5 support,
but FAILS its own point-win criterion (55->53 wins/512). V0 skipped. These partial
claims are retained separately; full current certificates remain0/6. Detailed
identities and immutable limits are in the current capsule and acquisition-v1/closure-1.

## Critical path, not another sampler loop

1. Bind the already evidenced public-state planner source, without rerunning v25
   or fitting to its held-out evidence. Qualify only the necessary current-runtime
   interface and bounded decision capability before any new matched-cost value
   test. Do not tune the failed acquisition adapter or invent a new policy root
   merely to improve support. A different controller is not yet selected/qualified.
2. For surviving inherited identities, complete the exact current causal/subset/
   null, descriptor, competent-policy, peer and real-economy certificate under one
   preregistered confirmation contract. Avoid serial success demonstrations.
   No source-equivalence or old directional admission transports population data
   across changed content/controller dependencies. Additional slots require a
   complete eligible mechanism; original #524 membership prevents relabels.
3. Three full certificates per aspect -> seven-direction detector -> corrected
   untouched confirmation and unrestricted endpoint retention with all hard
   guardrails. A successful acquisition pattern or archive cell is not viability.
4. Freeze one minimal product/detector/lifecycle packet; exact-head review under
   current owner authority, relevant gates, governed integration and exact merged
   #108 receipt. Keep research scaffolding and online policy machinery out of game.

Do not rerun closed panels, source extraction, record reconciliation, failed
content/candidate/controller branches or frozen-model fitting. Every new expense
needs an unmet acceptance claim and an evidenced changed prerequisite. Preserve
all positive/negative evidence; do not lower thresholds to turn near misses green.
No percentage of completion is inferred from rows, test counts or commits.
'''
    (repo/'research/p9-six-route/package-disposition-20260908/ROADMAP.md').write_text(roadmap)
    print(json.dumps(decision,indent=2))


class Tests(unittest.TestCase):
    def test_point_negative_remains_negative_when_interval_crosses_zero(self):
        c={'gates':{'activation':True,'win_point_not_worse':False,'win_noninferiority_lower_bound':True},'pass':False,
           'gained_policies':33,'lost_policies':2,'one_sided_exact_sign_p':compare_value.probability(33,2),
           'activation_new':42,'activation_old':11,'paired_activation_difference':31/128,
           'stock_outcomes':{'win':55,'loss':457},'aware_outcomes':{'win':53,'loss':459},
           'win_difference':-2/512,'policy_cluster_bootstrap_interval':[-.02,.02],'stock_support':{},'aware_support':{}}
        c['gates']['inherited_pair_support']=True
        t={'status':'FIXED_ACQUISITION_ADAPTER_NOT_ADMITTED','stages':{'5':c},'v0_skipped':True}
        r={'all_bytes_equal':True,'reproduced_stages':['5'],'scientific_status':t['status'],'files':292}
        q={'status':'ACQUISITION_CAPABILITY_AND_NULL_PASS','query_checks':9851}
        d=verdict(t,r,q)
        self.assertFalse(d['controller_value_admitted']);self.assertTrue(d['both_inherited_packages_have_v5_support_in_aware_arm'])
        q['status']='FAIL'
        with self.assertRaisesRegex(ValueError,'UNQUALIFIED'):verdict(t,r,q)
    def test_unverified_data_is_not_success(self):
        t={'status':'FIXED_ACQUISITION_ADAPTER_NOT_ADMITTED','stages':{'5':{}},'v0_skipped':True}
        with self.assertRaisesRegex(ValueError,'UNVERIFIED'):verdict(t,{'all_bytes_equal':False},{})
    def test_incomplete_never_becomes_scientific_failure(self):
        with self.assertRaisesRegex(ValueError,'UNEXPECTED_TERMINAL'):verdict({'status':'INCONCLUSIVE'},{},{})
    def test_no_stage_extension(self):
        t={'status':'FIXED_ACQUISITION_ADAPTER_NOT_ADMITTED','stages':{'5':{},'0':{}},'v0_skipped':False}
        with self.assertRaisesRegex(ValueError,'STAGE_BOUNDARY'):verdict(t,{}, {})

if __name__=='__main__':
    if sys.argv[1:] == ['--self-test']:unittest.main(argv=[sys.argv[0]],verbosity=2)
    else:close(*sys.argv[1:])
