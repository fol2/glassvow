"""Finite inference counterexample, NOT a Glassvow experiment or new gate.

Separates route-specific causal payoff from necessity for aggregate success
when an adaptive policy has a functioning alternative. No old result is changed.
"""
from __future__ import annotations
import hashlib
import itertools
import json
from pathlib import Path
import sys
import unittest

METHOD = Path('docs/balance/p9-strategy-diversity-system.md')
METHOD_BLOB = 'd03f3985a843ce89c8ff7db679aa75b484a5206e'
ROOT = Path('research/p9-six-route')
BASE = ROOT/'ash-inheritance-20260909'
CLOSED = (
    BASE/'hand-value-v1/execution-1/TERMINAL.json',
    BASE/'hand-two-slope-v1/adaptive-value-v1/execution-1/TERMINAL.json',
)


def require(ok, why):
    if not ok: raise ValueError(why)


def blob(b): return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def sha(b): return hashlib.sha256(b).hexdigest()
def load(p): return json.loads(p.read_bytes())
def save(p, x): p.write_text(json.dumps(x, indent=2, sort_keys=True)+'\n')


def route(kind, source=True, mediator=True, consumer=True):
    """Two explicit, bounded toy transition laws with unequal numeric traces.

    Burst: two setup operations accumulate up to 2 units; consumption resets
    the reserve and delivers 6. Decay: setup supplies 3 units; three clock
    operations consume 3,2,1 and reset. The clocks are independently enabled
    consumers, not source effects. The typed public state exposes each guard.
    """
    require(kind in ('burst','decay'), 'KIND')
    require(all(type(x) is bool for x in (source,mediator,consumer)), 'MASK_TYPES')
    stock=0; trace=[]
    if kind=='burst':
        for _ in range(2):
            stock=min(2,stock+int(source)) if mediator else 0
            trace.append({'clock':False,'damage':0,'stock':stock})
        damage=6 if consumer and stock==2 else 0
        stock=0
        trace.append({'clock':False,'damage':damage,'stock':stock})
    else:
        stock=3 if source and mediator else 0
        trace.append({'clock':False,'damage':0,'stock':stock})
        for _ in range(3):
            damage=stock if consumer else 0
            stock=max(0,stock-1)
            trace.append({'clock':True,'damage':damage,'stock':stock})
    return {'trace':trace,'payoff':sum(x['damage'] for x in trace),'reset':stock==0}


def adaptive(a_mask, b_mask):
    """Choose from explicit public guards, before executing either route.

    No sampled future, observed terminal or private RNG is consulted. The toy
    transition laws and these guards are completely observable to its policy.
    """
    require(len(a_mask)==len(b_mask)==3 and
            all(type(x) is bool for x in (*a_mask,*b_mask)), 'PUBLIC_MASKS')
    chosen='burst' if all(a_mask) else 'decay' if all(b_mask) else None
    if chosen is None:return {'chosen':None,'win':0,'trace':[]}
    result=route(chosen,*(a_mask if chosen=='burst' else b_mask))
    return {'chosen':chosen,'win':int(result['payoff']==6),'trace':result['trace']}


def contrasts(y):
    require(set(y)=={'00','01','10','11'} and all(type(x) is int and x in (0,1) for x in y.values()), 'WORLD_VALUES')
    return [y['11']-y['01'],y['11']-y['10'],y['11']-y['10']-y['01']+y['00']]


def witness():
    masks=list(itertools.product((False,True),repeat=3))
    routes={k:{''.join(str(int(b)) for b in m):route(k,*m) for m in masks} for k in ('burst','decay')}
    for k,table in routes.items():
        require(table['111']['payoff']==6 and all(v['reset'] for v in table.values()), 'BOUNDED_FULL_CHAIN')
        require(all(v['payoff']==0 for m,v in table.items() if m!='111'), 'ALL_COMPONENT_PROPER_SUBSETS')
    project=lambda x:[(r['clock'],r['damage']) for r in x['trace']]
    require(project(routes['burst']['111'])!=project(routes['decay']['111']), 'NOT_JUST_RENAMED_TRACE')
    assignments=[]
    for ma,mb in itertools.product(routes['burst'],routes['decay']):
        a,b=routes['burst'][ma],routes['decay'][mb]
        result=adaptive(tuple(c=='1' for c in ma),tuple(c=='1' for c in mb))
        require(result['win']==int(ma=='111' or mb=='111'), 'FALLBACK_TRUTH_TABLE')
        assignments.append({'burst_mask':ma,'decay_mask':mb,**result})
    worlds={}
    for world in ('00','01','10','11'):
        # Source and consumer of the focal route are intervened on. Its mediator
        # is intact; the peer mechanism remains fully available in all worlds.
        a=route('burst',world[0]=='1',True,world[1]=='1')
        b=route('decay')
        worlds[world]={'focal_payoff':a['payoff'],**adaptive((world[0]=='1',True,world[1]=='1'),(True,True,True))}
    y={w:r['win'] for w,r in worlds.items()}
    require(contrasts(y)==[0,0,0], 'GLOBAL_WIN_CONTRASTS')
    require([worlds[w]['focal_payoff'] for w in ('00','01','10','11')]==[0,0,0,6], 'FOCAL_COMPLEMENTARITY')
    no_peer={w:adaptive((w[0]=='1',True,w[1]=='1'),(False,True,True))['win'] for w in worlds}
    require(contrasts(no_peer)==[1,1,1], 'ABSENT_PEER_CONTROL')
    return {'kind':'FINITE_COMPENSATION_COUNTEREXAMPLE','route_masks':routes,
        'complete_assignments':assignments,'assignments':len(assignments),
        'adaptive_worlds_with_peer':worlds,'global_win_contrasts':contrasts(y),
        'focal_payoff_contrasts':[6,6,6],'absent_peer_global_win_contrasts':contrasts(no_peer),
        'what_is_proved':'Global win necessity/interaction is not logically necessary for bounded route-specific causal payoff in an adaptive system with an alternative route.',
        'what_is_not_proved':['Neither toy route is certified against the Glassvow closed-family quotient, detector, economy, C2 or other P9 bars.',
            'This does not establish Hand, Bloodfire or any real-game candidate value, causal descriptor or independent validation.',
            'No claim is made that actual observed Hand negatives were caused by successful fallback rather than weak payoff or another reason.']}


def run(repo,out):
    require(not out.exists(),'NO_OVERWRITE')
    data=(repo/METHOD).read_bytes(); require(blob(data)==METHOD_BLOB,'CURRENT_METHOD_IDENTITY')
    text=data.decode()
    clauses=[
        'intervention on the mediator and consumer changes the intended payoff through the complete chain, while proper subsets and exact-null comparators do not reproduce it',
        'A package is **viable** when competent policies can exploit it under the frozen quality and guardrail contract.',
        'A later layer cannot rescue a failure in an earlier claim.',
        'C2 RandomBuild separation, aspect identity, the Vow-5 ceiling, deterministic RNG/replay, save/internal-ID compatibility, zero added stalls/errors, no material duration regression and content validity are constraints, not weighted objectives.',
    ]
    require(all(c in text for c in clauses),'AUTHORITY_CLAUSES')
    inputs=[]
    for path in CLOSED:
        b=(repo/path).read_bytes(); t=json.loads(b)
        require('NOT_ESTABLISHED' in t['status'] and t['packages_admitted']==0 and t['p9_certified'] is False,'CLOSED_STATUS')
        inputs.append({'path':str(path),'sha256':sha(b),'bytes':len(b),'status':t['status']})
    w=witness()
    decision={'kind':'PACKAGE_VERSUS_GLOBAL_WIN_INFERENCE_BOUNDARY',
      'status':'UNIVERSAL_GLOBAL_WIN_PROXY_IMPLICATION_REFUTED_NOT_A_NEW_ADMISSION_RULE',
      'authority':{'path':str(METHOD),'git_blob':METHOD_BLOB,'sha256':sha(data),'clauses':clauses},
      'closed_inputs_retained':inputs,'finite_assignments':w['assignments'],
      'inference_refuted':'Failure of positive adaptive global-win contrasts, by itself, establishes absence of route-specific causal payoff in every adaptive system.',
      'inference_retained':'Each existing fixed experiment failed its own preregistered conjunction; no reinterpretation can turn those terminals into PASS.',
      'future_contract_boundary':'A prospective different estimand must explicitly map each obligation to the active acceptance and identify selection/error control, independent policies/seeds, full null/subset/descriptor/economy/quality/guardrails. Changing an estimand is not delivery repair; this proof opens no population or closed-family retest.',
      'proof_obligations':{
         'formal_identity':'Current source and eligible historical family/quotient binding; not names, two toy traces or a shared primitive count.',
         'route_causality':'The intended bounded payoff, complete source/mediator/consumer chain and all applicable proper subsets/nulls, with full native effects retained.',
         'quality_and_distinctness':'Competent-policy real-economy performance, independently reproduced policy-sensitive functional descriptors, peer separation, C2 and hard guardrails.',
         'system':'Seven-direction detector, corrected untouched confirmation, unconstrained endpoint retention, minimum lifecycle and exact-product/#108 receipt.'},
      'new_admission_criterion':False,'frozen_results_modified':False,'new_native_runs':0,
      'new_independent_samples':0,'packages_admitted':0,'p9_certified':False,
      'review_kind':'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT'}
    out.mkdir(parents=True); save(out/'WITNESS.json',w); save(out/'DECISION.json',decision)
    save(out/'FILES.json',[{'path':p.name,'bytes':p.stat().st_size,'sha256':sha(p.read_bytes())} for p in sorted(out.iterdir()) if p.is_file()])
    print(json.dumps({'status':decision['status'],'assignments':w['assignments']},indent=2))


class Tests(unittest.TestCase):
    def test_complete_bounded_mask_table(self):
        w=witness();self.assertEqual(w['assignments'],64)
        for table in w['route_masks'].values():self.assertEqual(sum(x['payoff']>0 for x in table.values()),1)
    def test_numeric_trace_difference_not_labels(self):
        a,b=route('burst'),route('decay')
        self.assertEqual(a['payoff'],b['payoff']);self.assertNotEqual(a['trace'],b['trace'])
        self.assertNotEqual([r['damage'] for r in a['trace']],[r['damage'] for r in b['trace']])
    def test_actual_public_fallback(self):
        self.assertEqual(adaptive((False,True,True),(True,True,True))['chosen'],'decay')
        self.assertEqual(adaptive((True,True,True),(True,True,True))['chosen'],'burst')
    def test_all_component_removals_eliminate_local_payoff(self):
        for k in ('burst','decay'):
            for i in range(3):
                m=[True]*3;m[i]=False;self.assertEqual(route(k,*m)['payoff'],0)
    def test_aggregate_positive_when_alternative_absent(self):
        self.assertEqual(contrasts({'00':0,'01':0,'10':0,'11':1}),[1,1,1])
    def test_no_alternative_no_unearned_win(self):
        self.assertEqual(adaptive((False,True,True),(False,True,True))['win'],0)
    def test_reset_even_consumer_disabled(self):
        for k in ('burst','decay'):self.assertTrue(route(k,consumer=False)['reset'])
    def test_bad_masks_not_coerced(self):
        with self.assertRaisesRegex(ValueError,'MASK_TYPES'):route('burst',1)
    def test_invalid_outcome_or_missing_world_rejected(self):
        with self.assertRaisesRegex(ValueError,'WORLD_VALUES'):contrasts({'11':1})
        with self.assertRaisesRegex(ValueError,'WORLD_VALUES'):contrasts(dict.fromkeys(('00','01','10','11'),True))

if __name__=='__main__':
    if sys.argv[1:]==['--self-test']:unittest.main(argv=[sys.argv[0]],verbosity=2)
    else:run(*(Path(x).resolve() for x in sys.argv[1:]))
