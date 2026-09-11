"""Synchronize only current summaries after three verified, offline decisions."""
import hashlib
import json
from pathlib import Path
import sys

ROOT=Path('research/p9-six-route')
HERE=ROOT/'acceptance-scope-20260911'
OLD=ROOT/'ash-inheritance-20260909/nightsight-opportunity-v1'
NEXT=('Prepare one acceptance-mapped complete package contract, separating native bounded-payoff '
      'causality from competent-policy quality, peer separation and signed global guardrails. '
      'The exact linear/two-slope audit-policy value nominations remain closed. '
      'Do not start a source-only rerun, repeat the availability/census work, change a frozen '
      'criterion, or treat the finite inference counterexample as a real-game certificate. '
      'Any genuinely new context/estimand must have its own explicit scope, fixed independent '
      'inputs and scientific error/stop rules before observations; no population is opened here.')


def load(p):return json.loads(p.read_bytes())
def sha(b):return hashlib.sha256(b).hexdigest()
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def save(p,x):p.write_text(json.dumps(x,indent=2)+'\n')
def require(ok,why):
    if not ok:raise ValueError(why)


def main(repo,out):
    require(not out.exists(),'NO_OVERWRITE')
    scope=repo/HERE/'execution-1'
    s=load(scope/'DECISION.json')
    require(s['status']=='UNIVERSAL_GLOBAL_WIN_PROXY_IMPLICATION_REFUTED_NOT_A_NEW_ADMISSION_RULE'
        and not s['new_admission_criterion'] and not s['frozen_results_modified']
        and s['new_native_runs']==s['packages_admitted']==0 and s['p9_certified'] is False,'SCOPE')
    inputs={}
    for name,kind in [('availability-1','ARCHIVED_PROFILE_AVAILABILITY_COLD_READBACK'),
                      ('frontier-1','SOURCE_ONLY_FRONTIER_COLD_READBACK')]:
        folder=repo/OLD/name
        receipt=load(folder/'REMOTE-READBACK.json')
        require(receipt['kind']==kind and receipt['all_bytes_equal'] is True
                and receipt['source_proof_reproduced'] is True,'INPUT_READBACK:'+name)
        for r in load(folder/'FILES.json'):
            p=Path(r['path']);require(not p.is_absolute() and '..' not in p.parts,'PATH')
            b=(folder/p).read_bytes()
            require(len(b)==r['bytes'] and sha(b)==r['sha256'],'INPUT_BYTES:'+name+'/'+r['path'])
        result_name='RESULTS.json' if name=='availability-1' else 'DECISION.json'
        decision=load(folder/result_name)
        require(decision['status']==receipt['scientific_status'],'SCIENTIFIC_STATE')
        inputs[name]={'receipt':str((OLD/name/'REMOTE-READBACK.json').relative_to(ROOT)),
                     'receipt_sha256':sha((folder/'REMOTE-READBACK.json').read_bytes()),
                     'result':str((OLD/name/result_name).relative_to(ROOT)),
                     'result_sha256':sha((folder/result_name).read_bytes()),'status':decision['status']}
    old_state=load(repo/ROOT/'SESSION-STATE.json')
    state=dict(old_state)
    state.update(status='P9_UNFINISHED_AVAILABILITY_AND_INFERENCE_SCOPE_VERIFIED',
        exact_next_action=NEXT,packages_admitted=0,p9_certified=False,no_active_research_processes=True)
    state['availability_and_retry_scope']={'inputs':inputs,
        'inference_decision':'acceptance-scope-20260911/execution-1/DECISION.json',
        'current_closure':'acceptance-scope-20260911/closure-1/DECISION.json',
        'cold_readback':'acceptance-scope-20260911/closure-1/REMOTE-READBACK.json',
        'new_native_runs':0,'old_negative_reclassification':False,'new_population_opened':False}
    allowed={'status','exact_next_action','packages_admitted','p9_certified','no_active_research_processes','availability_and_retry_scope'}
    require(all(state[k]==v for k,v in old_state.items() if k not in allowed),'HISTORY_REWRITE')
    save(repo/ROOT/'SESSION-STATE.json',state)
    handoff='''# P9 current handoff — availability, retry pruning and inference scope complete

Continue #421 on `research/p9-six-route-local-20260905`.
Product reference: `2ed6cdb0302ba3aab5845a18d862841165e8aaf7`.
Target: three viable, reachable, genuinely distinct complete strategies per aspect.
**0/6 current certificates; no P9 PASS, product promotion or revised acceptance.**
Author self-review is not independent evidence.

## Completed this continuation — no native runs

The previous availability workflow had never started: its file-SHA update was
rejected. The existing availability.py has now run successfully. Its archived
profile has all reveal IDs but only aspect2 unlocked; Night Sight is absent from
the initial reward pool and starter. This is initial-profile evidence, not a claim
that the live darkWalker progression path can never make the card available.
First Spark is absent from reward tiers but appears once in both native starters.
The complete pool-plus-starter source inventory and cold receipts are under
`ash-inheritance-20260909/nightsight-opportunity-v1/availability-1/` and `frontier-1/`.

For identical content, source-ON/consumer-OFF semantics, policy, profile, assigned
initial states/seeds and readout, regrouping source interventions cannot change
world11 or world10. Both archived Hand nominations already fail that necessary
consumer contrast. The source-only retry class is conditionally pruned; changing
any identity premise falls outside the theorem, not automatically inside a new
permission. No source-only cohort should be launched to rescue these results.

`acceptance-scope-20260911/execution-1/` contains a finite inference counterexample:
complete focal source/mediator/consumer payoff can coexist with equal aggregate
win outcomes when an adaptive policy uses an alternative route. It proves only
that global-win necessity and route-payoff causality are not interchangeable.
Neither toy route is a Glassvow package. It does not explain the real Hand negative,
replace an old primary metric, amend acceptance, or admit any real strategy.

## Immutable prior results

Linear Hand: world00/01/10/11 wins289/295/316/322 per512; consumer6/512,
interval[-0.015625,0.0390625], interaction0. NOT_ESTABLISHED, V0 skipped.
Two-slope Hand: wins283/280/306/301 per512; consumer-5/512,
interval[-0.03125,0.009765625]. NOT_ESTABLISHED, V0 skipped.
Bloodfire value and all controller/acquisition/whole-candidate failures keep their
exact scope. No old raw, threshold, model, protected cohort or verdict is edited.
The completed source/query/clone gates, 55-file transport, all-trace censuses and
availability work are not waiting to be recovered or rerun. Older unrelated raw
gaps remain recorded in SESSION-STATE.json. BloodRite loses3HP then gains2/3Energy,
not draw. Preparation/Surge are alternative producers of one Hand family.

## Exact continuation

'''+NEXT+'''

## Remaining P9 milestones

A complete current package still requires eligible formal identity, native full-chain
and proper-subset/null causality, a validated descriptor, competent-policy and peer
separation on real economy paths, and independently assigned confirmation.
Then establish six-package coverage; admit the seven-direction detector; perform
corrected untouched confirmation and unrestricted endpoint retention with all
signed-control, ceiling, fault and duration guards; deliver minimum lifecycle,
exact-head review and one selected exact-product integration/#108 receipt.
No automatic scientific successor, new controller, or population start is hidden
in this closure. Use the full active issue for future acceptance mapping.
'''
    (repo/ROOT/'SESSION-HANDOFF.md').write_text(handoff)
    (repo/ROOT/'package-disposition-20260908/ROADMAP.md').write_text('''# P9 current outcome roadmap

0/6 complete current certificates. No P9 PASS or product promotion.

1. '''+NEXT+'''
2. Produce three complete viable/reachable/distinct packages per aspect. Alternative sources are not extra slots; certificates need all eligible identity, chain, subset/null, descriptor, policy/peer/economy and independent evidence.
3. Admit seven-direction detector, corrected untouched confirmation and unrestricted endpoint retention, with every hard guardrail intact.
4. Deliver minimum lifecycle, exact-head review and one selected exact-product/#108 receipt.

Completed and not to repeat: availability and starter binding, source-only consumer-contrast invariance, retained-data path analyses and the finite inference-scope counterexample. Old Hand/Bloodfire negatives, v25, frozen models and exposed cohorts remain closed in their precise scope.
''')
    out.mkdir(parents=True)
    save(out/'DECISION.json',{'kind':'CURRENT_AVAILABILITY_AND_INFERENCE_SCOPE_CLOSURE',
        'inputs':inputs,'scope_status':s['status'],'source_only_retries_opened':False,
        'new_native_runs':0,'new_independent_samples':0,'packages_admitted':0,
        'p9_certified':False,'old_results_preserved':True,'next_action':NEXT,
        'review_kind':'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT'})
    paths=[repo/HERE/n for n in ('scope.py','close.py')]
    paths+=[p for p in sorted(scope.iterdir()) if p.is_file()]
    paths+=[out/'DECISION.json']
    paths+=[repo/ROOT/n for n in ('SESSION-HANDOFF.md','SESSION-STATE.json','package-disposition-20260908/ROADMAP.md')]
    save(out/'FILES.json',[{'path':str(p.relative_to(repo)),'bytes':p.stat().st_size,
        'sha256':sha(p.read_bytes()),'git_blob':blob(p.read_bytes())} for p in paths])

if __name__=='__main__':main(*(Path(p).resolve() for p in sys.argv[1:]))
