"""Generate only current P9 metadata from preserved, remotely verified terminals.

No new engine run, independence claim, old-verdict rewrite or candidate promotion.
"""
from __future__ import annotations
import hashlib,json
from pathlib import Path
import sys

ROLE='MINIMAL_NATIVE_ROLE_CONTRACT_CHECKED_NOT_ADMITTED'
EXPANSION='GUARDED_WITHIN_CARD_EXPANSION_EQUIVALENT_ON_ALL_FIXED_CONTEXTS'
SURVIVE='NATIVE_POLICY_CAPACITY_NOT_FALSIFIED_NOT_ADMISSION'
INSUFFICIENT='FIXED_NATIVE_POLICY_FAMILY_INSUFFICIENT_UPPER_BOUND'
MAIN='2ed6cdb0302ba3aab5845a18d862841165e8aaf7'
OLD='3c7b2f9dba362d19128ef82ad559d3f26e54925371d823a665767032255eadaa'

def require(ok,why):
    if not ok:raise ValueError(why)
def sha(b):return hashlib.sha256(b).hexdigest()
def load(p):return json.loads(p.read_bytes())
def save(p,v):p.write_text(json.dumps(v,indent=2)+'\n')
def checked_result(root,name,relative,receipt_name):
    receipt=load(root/receipt_name);data=(root/relative).read_bytes()
    path='research/p9-six-route/minimal-native-20260909/'+relative
    matches=[x for x in receipt['files'] if x['path']==path]
    require(len(matches)==1,'unique published identity:'+name)
    record=matches[0];require(len(data)==record['bytes'] and sha(data)==record['sha256'],'published bytes:'+name)
    require(hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()==record['git_blob'],'published blob:'+name)
    return json.loads(data),record

def decision(role,expansion,terminal):
    require(role['status']==ROLE and not role['failures'],'native role evidence')
    require(expansion['status']==EXPANSION and len(expansion['comparisons'])==208,'guarded expansion evidence')
    require(all(r['full_trace_equal'] for r in expansion['comparisons']),'complete expansion equality')
    require(terminal['status']=='FIXED_NATIVE_POLICY_CAPACITY_COMPLETE_NOT_ADMISSION','complete capacity')
    grids=terminal['grids'];require(set(grids)=={'duskblade-v5','ashwarden-v5','ashwarden-v0'},'exact conditional stages')
    require(grids['duskblade-v5']['status']==INSUFFICIENT,'Dusk fixed-family disposition')
    require(all(grids[g]['status']==SURVIVE for g in ('ashwarden-v5','ashwarden-v0')),'Smolder necessary predicates')
    for grid in grids.values():
        require(grid['rows']==512 and grid['policies']==128 and not grid['faults'],'complete fault-free grid')
        require(grid['packages_admitted']==0 and grid['p9_certified'] is False,'no forged admission')
    counts={g:{'status':r['status'],'potential_active':len(r['potential_active_upper_bound']),
        'reachable':len(r['reachable_upper_bound']),'potential_viable':len(r['potential_viable_upper_bound']),
        'outcomes':r['outcomes'],'rows':r['rows']} for g,r in grids.items()}
    return {'status':'NATIVE_ROLES_DEFINED_SMOLDER_WITNESS_CAPACITY_SURVIVES_DUSK_STOCK_SAMPLER_CLOSED',
      'native_role_status':role['status'],'native_role_counts':role['counts'],
      'effect_expansion_status':expansion['status'],'effect_expansion_comparisons':208,'capacity':counts,
      'scientific_decisions':[
        'The two minimal role chains are expressible in unchanged main; no new content or primitive is selected.',
        'Within-card guarded decomposition is proved for exact source and corroborated by all retained contexts; not three separately played cards.',
        'The specified Dusk native sampler cannot provide the intended witness set even under an opportunity upper bound; do not run its conditional V0 or extend this cohort.',
        'Smolder has enough conservative opportunities and winning opportunities in this family at both vows. This is not causal activation, exact inactivity, competent-policy certification or package admission.',
        'A valid next study must settle the remaining formal classification and use source/mediator/consumer contrasts, not another temporal-co-occurrence or damage example.'
      ],
      'next_action':'Prioritise the complete native Smolder package certificate against unchanged main. Finish the exact relevant closed/admitted-family classification, including ToxicMist/Catalyst and its shared background, without erasing target multiplicity, source hit/death guards or lifecycle. If that survives, freeze one unified independent causal/descriptor/policy/peer/economy confirmation contract using the retained source controls. For Dusk, retain stronger previously evidenced controllers as possible future witness suppliers; do not treat this weaker sampler result as nonviability or rerun v25. No new content mutation is selected by this decision.',
      'no_repeat':['the two closed bulk candidates','Hand support','v25','old 1024/2048/672 panels','this role/expansion/capacity packet'],
      'full_closed_family_quotient_established':False,'new_native_runs_in_closure':0,
      'new_independent_confirmation_samples':0,'packages_admitted':0,'p9_certified':False,
      'review':'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT'}

def main(repo):
    root=Path(repo).resolve()/'research/p9-six-route';r=root/'minimal-native-20260909'
    role,a=checked_result(r,'role','native-1/RESULTS.json','REMOTE-READBACK.json')
    expansion,b=checked_result(r,'expansion','expansion/native-1/RESULTS.json','expansion/REMOTE-READBACK.json')
    terminal,c=checked_result(r,'capacity','capacity/native-1/TERMINAL.json','capacity/REMOTE-READBACK.json')
    result=decision(role,expansion,terminal);result['input_files']=[a,b,c]
    state_path=root/'SESSION-STATE.json';state=load(state_path)
    require(state['candidate_sha256']==OLD and state['product_reference']==MAIN,'prior frozen identities')
    require(state['packages_admitted']==0 and not state['p9_certified'],'current admission state')
    state['minimal_native']={'reference_main':MAIN,'content_sha256':'a0d608a5142d2e3aab799cdf33d3163922b402c2aaf2a895e46e096399b56cf1',
      'role_freeze':'c88f7c8b47e57b058e8c71fd9151488808b5b5a4','expansion_freeze':'15523d086b1be513062965a3f8cc4d49d7de7b6c',
      'capacity_freeze':'47dd31532623dabebf21edba58df29bcb47de115','status':result['status'],
      'directory':'minimal-native-20260909','capacity':result['capacity'],
      'new_product_candidate_selected':False,'full_closed_family_quotient_established':False,
      'receipts':['minimal-native-20260909/REMOTE-READBACK.json','minimal-native-20260909/expansion/REMOTE-READBACK.json','minimal-native-20260909/capacity/REMOTE-READBACK.json']}
    state['status']='P9_UNFINISHED_NATIVE_SMOLDER_CAPACITY_READY_FOR_COMPLETE_PROOF'
    state['exact_next_action']=result['next_action'];state['no_active_research_processes']=True
    save(r/'DECISION.json',result);save(state_path,state)
    rows='\n'.join(f"| {g} | {x['potential_active']} | {x['reachable']} | {x['potential_viable']} | {x['status']} |" for g,x in result['capacity'].items())
    handoff=f'''# P9 current handoff — native role laws checked; Smolder capacity survives

Continue #421 on research/p9-six-route-local-20260905. Three viable, reachable,
genuinely distinct strategies per aspect remain the target. P9 is unfinished;
0/6 complete exact-current certificates. Owner author self-review is allowed,
not independent confirmation. Main remains {MAIN}.

## Completed decisions — do not repeat

Both failed bulk candidates and Hand's fixed-family support terminal stay closed.
The retained candidate_sha256 and descriptor_sha256 identify those old frozen
studies; they have NOT been overwritten with the unchanged-main reference.

minimal-native-20260909 contains full exact-main Fervor and Smolder role contracts,
component-intervention captures and a guarded within-card decomposition witness.
Full state, aliases, events, costs, expiry and native side effects are retained.
These are existing native operations, not new primitives or six new topologies.
Old one-bit extra-Chip and ToxicMist/Catalyst comparisons remain exactly scoped.
The complete closed/admitted quotient is still unproved; do not turn source
expressibility or finite arithmetic into admission.

The separate cheap native-policy upper-bound screen completed on all assigned
V5 contexts and conditional Ash V0. Dusk V0 was correctly not opened.

| Context | Potential active | Co-ownership/reached | Potential viable | Decision |
|---|---:|---:|---:|---|
{rows}

Every set counts configurations within one fixed family, not independent players.
Potential may include unrelated source, transfer or clipped payoff. Not-potential
is not certified inactivity. Native sampler insufficiency is not universal Dusk
nonviability and does not revoke stronger-controller evidence.

## Exact next action

{result['next_action']}

## Durable evidence and scope

All three captures, sources, configs/logs and readouts were committed and then
fetched into separate checkouts for byte comparison and offline reconstruction.
Their REMOTE-READBACK.json files bind the published bytes. No game runs during
readback or this capsule update. The role capture's local/hosted replay counts
once; expansion reuses old stock references; capacity uses its separate frozen
policies/seeds. No new independent package confirmation is claimed.

Historical raw gaps, old negative results and protected identities in
SESSION-STATE.json remain unchanged. No force push, new research branch, product
merge or #108 PASS. No research process is active after this metadata update.
Use the existing ROADMAP.md; do not start another recovery/census/document loop.
'''
    (root/'SESSION-HANDOFF.md').write_text(handoff)
    (root/'package-disposition-20260908/ROADMAP.md').write_text('''# P9 delivery path — current decisions, not accumulated run counts

Target: three fully certified strategies per aspect, then validated detector,
independent confirmation/retention and exact-product #108 evidence. 0/6 complete
exact-current certificates; this is not a revocation of historical Ash support.

## What is now finished

Reunion, six-route disposition, Hand preflight/support, both bulk-candidate
screens and their joint-substrate attribution are complete. Both bulk packets
and the exact Hand/controller support attempt remain closed. No third bulk tune.
The unchanged-main Fervor/Smolder role definitions, finite interventions and
within-card decomposition now have complete source/raw/readback. Native Dusk
sampling failed its necessary opportunity upper bounds; Ash Smolder survived
both vows. None of these facts alone is a package certificate.

## The critical path

1. Complete one native Smolder certificate, not another successful-example study.
   Resolve the exact relevant canonical/closed-family comparison. If distinct,
   bind one complete source/mediator/consumer/null/subset and held-out descriptor,
   policy/peer/economy contract. Reuse existing exact-main law evidence, but never
   copy changed-content outcomes, select favourable seeds, or turn a capacity
   upper bound into causal activation. Failure closes its precise claim.
2. For Dusk, do not spend again on the inadequate stock sampler or repeat v25.
   Use an already-evidenced competent representation only after exact source and
   scope binding. Complete missing package proofs for actual surviving designs;
   no off-route bans, forced decks or requirement for six globally new primitives.
3. Obtain three full certificates per aspect, preserving native/historical Ash
   directions only where dependency and independent evidence really carry.
   Then validate all seven detector directions and numerical contrasts.
4. Freeze and perform corrected untouched confirmation and unrestricted local
   optimisation/endpoint retention with signed controls and every hard guardrail.
   Different names, high win rates and protected archive occupancy do not pass.
5. Freeze admitted interfaces, implement the minimum claim/dependency lifecycle,
   integrate one selected minimal product packet, exact-head/exact-main gates,
   and #108 P9 receipt. Product/release authority and feel check stay separate.

The complete historical quotient and the first full certificate are still open.
No roadmap can guarantee that fixed labels survive. Progress is a closed
acceptance obligation or a decision excluding an exact path, not test counts.
''')
    print(json.dumps({k:v for k,v in result.items() if k!='input_files'},sort_keys=True))

if __name__=='__main__':main(sys.argv[1])
