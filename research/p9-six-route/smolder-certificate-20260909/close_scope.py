"""Refresh the single current capsule from completed evidence; no new outcomes."""
from __future__ import annotations
import hashlib, json, sys
from pathlib import Path

ROOT = Path('research/p9-six-route')
STUDY = ROOT/'smolder-certificate-20260909'
NEXT = ('Do not rerun source extraction, role fixtures, capacity, retained-trace attribution, or pure-source witness variants. '
        'The exact named historical Catalyst-extension relation and public-preview counterexample are complete. '
        'Construct the missing complete current-source package transition comparison against the exact relevant closed/admitted contracts '
        'and their permitted shared-background compositions, including preview, acquisition and lifecycle; the old and current background cannot be assumed identical. '
        'Return one checkable full-scope equivalence/decomposition or non-equivalence disposition, not another local example. '
        'Only an eligible complete formal disposition opens one unified mixed-background causal/null/subset/descriptor/policy/peer/economy confirmation contract. '
        'Use actual source interventions with normal Ashen Core background, not a requirement for naturally pure VenomStrike stock. '
        'No fixed model refit, v25 replay, third bulk tune, protected-cohort use or product mutation is selected.')


def require(ok, reason):
    if not ok: raise ValueError(reason)

def load(repo, path):
    return json.loads((repo/path).read_bytes())

def digest(repo, path):
    b=(repo/path).read_bytes()
    return {'path':str(path), 'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()}

def evidence_decision(source, trace, frame):
    require(source['status']=='EXACT_MISTBOUND_EXTENSION_AND_SHARED_NATIVE_KERNEL_SEPARATED','SOURCE_TERMINAL')
    require(frame['status']=='UNQUALIFIED_COMMON_BACKGROUND_EQUIVALENCE_REFUTED','FRAME_TERMINAL')
    require(source['disposition']['complete_formal_package_admission']=='NOT_ESTABLISHED','UNEXPECTED_FORMAL_ADMISSION')
    require(trace['kind']=='RETAINED_TRACE_SOURCE_ATTRIBUTION_NOT_CERTIFICATION','TRACE_KIND')
    require([g['vow'] for g in trace['grids']]==[5,0],'VOW_RECTANGLE')
    grids=[]
    for g in trace['grids']:
        require(g['rows']==512 and g['policies']==128,'RECTANGLE')
        require(g['packages_admitted']==0 and g['p9_certified'] is False,'NO_ADMISSION')
        require(g['new_native_runs']==g['new_independent_samples']==0,'REUSE_ONLY')
        grids.append({'vow':g['vow'],'rows':g['rows'],'policies':g['policies'],
          'old_potential':len(g['old_potential_policies']),
          'source_attributed_possible':len(g['source_attributed_possible_policies']),
          'winning_possible':len(g['winning_possible_policies']),
          'clean_direct_policies':len(g['clean_direct_stock_witness_policies']),
          'clean_direct_witnesses':g['direct_witnesses'],'capacity_verdict':g['status']})
    return {'status':'SOURCE_SCOPE_DECIDED_FULL_PACKAGE_CERTIFICATE_STILL_UNRESOLVED',
      'grids':grids,
      'decisions_gained':[
        'Historical Mistbound is an added guarded consumption/multiplier operation over an exactly shared Catalyst kernel, not the same registered mediator as native poison.',
        'Shared consumer code and ten identical runtime functions do not prove a whole public-background bridge: ordinary Leech has different native and historical preview return shapes even with all historical tags absent.',
        'The completed retained Ash rectangles support 71/88 possible source-lineage configurations and zero frozen clean-direct stock witnesses; possibility and clean absence are not causal activity or inactivity.',
        'Keep historical results, both failed bulk candidates and Hand support closed with their own scope. No historical outcome is newly carried as current evidence.'
      ],
      'cannot_promote':['Complete canonical comparison versus relevant closed/admitted compositions remains unproved.',
        'No HP counterfactual, proper-subset, peer separation or independent full-package confirmation is supplied by this audit.'],
      'open_new_population_confirmation':False,'new_native_runs':0,'new_independent_samples':0,
      'packages_admitted':0,'p9_certified':False,'review':'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT',
      'exact_next_action':NEXT}


def main(repo):
    repo=Path(repo)
    source_path=STUDY/'derived-2/SOURCE-RELATION.json'
    trace_path=STUDY/'derived-2/trace/RESULTS.json'
    frame_path=STUDY/'frame-1/RESULTS.json'
    decision=evidence_decision(load(repo,source_path),load(repo,trace_path),load(repo,frame_path))
    decision['evidence']=[digest(repo,p) for p in [source_path,trace_path,frame_path,STUDY/'derived-2/REMOTE-READBACK.json']]
    destination=repo/STUDY/'DECISION.json';require(not destination.exists(),'DECISION_EXISTS')
    destination.write_text(json.dumps(decision,indent=2)+'\n')
    state=load(repo,ROOT/'SESSION-STATE.json')
    require(state['product_reference']=='2ed6cdb0302ba3aab5845a18d862841165e8aaf7','PRODUCT_REFERENCE')
    require(state['packages_admitted']==0 and state['p9_certified'] is False,'CURRENT_ADMISSION_CHANGED')
    state['status']='P9_UNFINISHED_SMOLDER_SOURCE_SCOPE_DECIDED_FULL_CANONICAL_PROOF_MISSING'
    state['smolder_source_scope']={'decision':'smolder-certificate-20260909/DECISION.json',
      'source_input_head':'75c2111ec132338fb5c743c6056add8482a62019',
      'verified_derived_head':'d9cfa926a81a47f56e78acb6dd075936c9f45550',
      'derived_readback':'smolder-certificate-20260909/derived-2/REMOTE-READBACK.json',
      'grids':decision['grids'],'full_closed_family_quotient_established':False,
      'old_background_bridge':'REFUTED_BY_PUBLIC_PREVIEW_RETURN_SHAPE',
      'new_native_runs':0,'new_independent_samples':0}
    state['exact_next_action']=NEXT
    (repo/ROOT/'SESSION-STATE.json').write_text(json.dumps(state,indent=2)+'\n')
    handoff='''# P9 current handoff — source-scope decisions complete; full certificate still missing

Continue #421 on research/p9-six-route-local-20260905. Target remains three
viable, reachable, genuinely distinct strategies per aspect. P9 is unfinished:
0/6 complete exact-current certificates. Author self-review is allowed, never
independent confirmation. Product main remains 2ed6cdb0302ba3aab5845a18d862841165e8aaf7.

## Completed; do not restart

The prior reunion, six-route disposition, v25, frozen validation, command-chain
negative, Hand support, both bulk-candidate negatives, native role fixtures and
capacity studies remain unchanged. Historical raw gaps are still explicit in
SESSION-STATE.json; new successful preservation does not repair those gaps.

smolder-certificate-20260909 now contains the exact historical/native Catalyst
kernel relation, ten equal full runtime bodies, complete 1,024-row retained Ash
source-lineage analysis and a source-level public-preview counterexample.
The historical Leech preview returns a hit dictionary even without Bloodfire;
current native preview returns null for that ordinary card. Omitted historical
tags do not establish equality of the complete observation/background interface.
Do not copy historical aggregate support or policy outcomes on that assumption.

| Vow | Old potential | Source-lineage possible | Winning possible | Clean-direct witnesses |
|---|---:|---:|---:|---:|
| 5 | 72 | 71 | 29 | 0 |
| 0 | 88 | 88 | 43 | 0 |

All sets are configurations in one fixed family, not independent players.
Possible is an upper bound; zero clean-direct witnesses is not inactivity or
zero causal effect. Normal Ashen Core supplies background poison. Do not relax
the old purity definition or run variants to manufacture witnesses. Direct
mixed-background interventions, once formally eligible, answer the actual claim.

## Exact next action

'''+NEXT+'''

## Preservation and scope

All emitted evidence is on this branch with exact sources, logs and raw input
identities. derived-1 preserves the sparse-checkout delivery failure; derived-2
preserves the repaired analysis and separate-checkout byte comparison/offline
reconstruction. frame-1 contains the additional source counterexample. The final
publication workflow records a separate cold-readback receipt for current files.
No archived code or game was executed by these analyses. No P9 PASS, model
refit, protected seed, product merge or new content candidate is implied.

Use the existing ROADMAP.md. Do not start another recovery/census/roadmap loop.
'''
    (repo/ROOT/'SESSION-HANDOFF.md').write_text(handoff)
    road=repo/ROOT/'package-disposition-20260908/ROADMAP.md'
    text=road.read_text()
    marker='## The critical path\n'
    require(text.count(marker)==1,'ROADMAP_SECTION')
    addition='''## Current source-scope decision

The exact historical Catalyst-extension relation and retained Ash source-lineage
audit are now complete. A Leech public-preview counterexample refutes an
unqualified whole-background bridge even with all historical tags absent.
The 71/88 possible lineages and zero pure-source witnesses do not admit a package.
Do not repeat these audits or tune witness purity. The next acceptance-changing
work remains one complete current-source canonical comparison with explicit
background, preview, acquisition and composition obligations. Only its eligible
terminal may open the single unified mixed-background confirmation contract.

'''
    require('## Current source-scope decision' not in text,'ROADMAP_ALREADY_UPDATED')
    road.write_text(text.replace(marker,addition+marker))
    print(json.dumps({'decision':decision['status'],'grids':decision['grids'],'new_native_runs':0,'p9_certified':False},sort_keys=True))

if __name__=='__main__':main(*sys.argv[1:])
