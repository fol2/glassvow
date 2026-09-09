"""Publish the scoped alias decision; preserve every prior terminal and count."""
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path('research/p9-six-route')
STUDY = ROOT / 'smolder-certificate-20260909/registered-identity'
RESULT_HASH = 'b074ed7f09b1b0506946ef2be34728abc8b8b351ff9d726dbbf7222d2ab62fd6'
NEXT = (
    'Do not run another native Smolder/Fervor confirmation: both exact role '
    'subsystems are explicitly registered in immutable #524. Use the already '
    'admitted Ash hand-size/Bloodfire directions as inherited identities, not new '
    'names: bind their exact supported source/content and isolate any required '
    'minimal current-product delta before its cheapest applicable guardrail. '
    'Do not restore the failed scalar substrate or import historical outcomes '
    'across changed dependencies. For additional slots, a complete non-equivalent '
    'package under current #421 authority must precede population work; check '
    'exact historical role registrations before inventing broader composition '
    'proofs. Keep Node O/E0/E1 terminals and all frozen cohorts sealed.'
)


def write(path, obj):
    path.write_text(json.dumps(obj, indent=2) + '\n')


def main(repo):
    repo = Path(repo)
    data = (repo / STUDY / 'execution-1/RESULTS.json').read_bytes()
    if hashlib.sha256(data).hexdigest() != RESULT_HASH:
        raise ValueError('RESULT_IDENTITY')
    result = json.loads(data)
    if result['equal_source_files'] != 51 or len(result['rows']) != 2:
        raise ValueError('RESULT_SCOPE')
    if result['rows'][0]['historical_heldout_edge_promoted'] is not True:
        raise ValueError('DO_NOT_ERASE_POSITIVE_SMOLDER_EDGE')
    if any(r['new_confirmation_authorised'] for r in result['rows']):
        raise ValueError('NO_POPULATION_PROMOTION')
    state_path = repo / ROOT / 'SESSION-STATE.json'
    before = json.loads(state_path.read_bytes())
    if before['p9_certified'] or before['packages_admitted'] != 0:
        raise ValueError('CURRENT_STATE_CHANGED')
    state = json.loads(json.dumps(before))
    state['status'] = 'P9_UNFINISHED_TWO_NATIVE_ROLE_ALIASES_RESOLVED'
    state['exact_next_action'] = NEXT
    state['native_registered_identity'] = {
        'status': 'SMOLDER_AND_FERVOR_ARE_REGISTERED_NATIVE_ROLE_SUBSYSTEMS',
        'source_head': '1695a2aafaa3601f73113252e13c25c1ab4d714f',
        'verified_evidence_head': '8d2fc01c3f6bb2c2edcd793c266cf63cb9ff804b',
        'result_sha256': RESULT_HASH,
        'equal_semantic_source_files': 51,
        'evidence': 'smolder-certificate-20260909/registered-identity/execution-1/RESULTS.json',
        'readback': 'smolder-certificate-20260909/registered-identity/execution-1/REMOTE-READBACK.json',
        'old_source': result['old_product_source'],
        'historical_evidence': result['historical_evidence'],
        'new_native_runs': 0, 'new_independent_samples': 0,
        'scope': 'Existential exact registered-role/subsystem witness in the identical native semantic frame. Not a universal quotient, renderer identity, population impossibility or new admission.'}
    changed = [k for k in before if before[k] != state.get(k)]
    if not set(changed) <= {'status', 'exact_next_action', 'native_registered_identity'}:
        raise ValueError('HISTORICAL_STATE_MUTATION')
    decision = {'status': state['status'], 'decisions': [
        'The original native #524 registry contains venomStrike->catalyst and empower->flurry, not only the later ToxicMist/Mistbound variant.',
        '51 exact command/query/state/content/economy/policy source files are identical. An exact old member is sufficient to reject new identity; full inventory enumeration is unnecessary for this rejection.',
        'The preserved formal-v1 restricted-algebra proof is complete in its own scope and remains insufficient for eligibility. Its omitted original registry member supplies the decisive counterexample.',
        'Smolder retains its historical positive held-out edge and failed complete package; Fervor retains its original exact findings. No old criterion is retroactively changed.',
        'No new native samples or population confirmation is justified by relabelling these same role subsystems. This is not a theorem that all future design or controller changes fail.'
        ], 'remaining_milestones': state['remaining_milestones'],
        'exact_next_action': NEXT, 'new_native_runs': 0, 'new_independent_samples': 0,
        'packages_admitted': 0, 'p9_certified': False,
        'review': 'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT',
        'review_checks': ['Exact original registration, not shared consumer matching',
                         'Complete selected semantic source inventory and bytes',
                         'No transfer of historical outcome counts',
                         'Positive edge and historical aggregate failure kept distinct',
                         'Excluded renderer/application scope explicit',
                         'Current state retains every other preexisting field'],
        'state_preservation': {'changed_existing_fields': changed, 'other_existing_fields_unchanged': True}}
    write(repo / STUDY / 'DECISION.json', decision)
    write(state_path, state)
    (repo / ROOT / 'SESSION-HANDOFF.md').write_text('''# P9 current handoff — exact old native role aliases resolved

Continue #421 on research/p9-six-route-local-20260905. Three viable, reachable,
genuinely distinct strategies per aspect remain the target. Main is unchanged
at 2ed6cdb0302ba3aab5845a18d862841165e8aaf7. No P9 PASS; 0/6 complete current
certificates. Owner permits author self-review, not invented independence.

## Completed; do not restart

formal-v1/execution-1 completed its original 23 tests and source-bound scoped
composition calculation. It remains a restricted-algebra result, not eligibility.

The decisive comparison is now registered-identity/execution-1: original #524
PACKAGES explicitly contains VenomStrike/Catalyst and Empower/Flurry. All 51
selected native semantic frame files match original source 0f005282 and current
main. The proof preserves all card parameters, public combat previews, targets,
costs, state/reset, RNG, rewards and native policy dependencies. It does not
claim renderer/application equality or an executed source/runtime oracle.

These two native role subsystems cannot become new distinct packages by names
or by restricting the already registered family. This existential witness closes
that question without an infinite search over every historical composition.
Smolder's old held-out edge was positive; its complete package failed. Those
are different facts. No universal population-failure claim or new threshold.

Both complete static packets were committed, cold-checked and replayed offline.
The identity result SHA256 is b074ed7f09b1b0506946ef2be34728abc8b8b351ff9d726dbbf7222d2ab62fd6.
Read registered-identity/DECISION.json and its execution-1/REMOTE-READBACK.json.
No native game or protected cohort was run; historical Python was parsed only.
All earlier negatives, positive evidence, source-scope results and raw gaps in
SESSION-STATE.json remain. Do not repeat reunion/census, v25, model fitting,
Hand support, bulk tuning, native fixtures/capacity or trace-purity studies.

## Exact next action

''' + NEXT + '''

## Remaining P9 work

Complete source-bound package certificates (three per aspect), admitted seven-
direction detector, corrected independent confirmation, unrestricted endpoint
retention and all guardrails; then minimum lifecycle, exact-head review under
current authority, one exact-product integration and #108 receipt. Do not ship
research scaffolding or call source/tests/commits a completion percentage.
''')
    (repo / ROOT / 'package-disposition-20260908/ROADMAP.md').write_text('''# P9 — current outcome roadmap

## Current decision

The unchanged native Smolder and Fervor role chains are explicit #524 package
components under the same 51-file semantic frame. Their new-identity claims
cannot progress by further samples or narrower labels. The direct registration
proof is in ../smolder-certificate-20260909/registered-identity/DECISION.json.
No complete current package certificate or new product candidate is admitted.

## Shortest valid path

1. Reuse eligible, already-admitted Hand/Bloodfire identities with exact dependency
   binding. Isolate any minimum current-product delta before costly validation;
   do not copy the failed historical scalar substrate or its outcomes.
2. Additional slots require an actually non-equivalent complete package under
   the current #421 authority. Perform original-registration lookup first; an
   existing exact member is a decisive rejection. No match is not a novelty proof.
3. For a surviving complete package, freeze its missing causal/null/subset,
   descriptor, competent-policy, peer-separation and real-economy evidence in
   one contract; run the cheapest valid falsifier first. Keep independent data
   distinct and stop that fixed branch at its frozen negative.
4. Three complete certificates per aspect -> seven-direction detector admission
   -> corrected untouched confirmation and unrestricted endpoint retention with
   every hard guardrail -> minimum lifecycle and exact-product/#108 delivery.

Existing research evidence is reused only where dependencies support it. No
v25 rerun, old-panel replay, frozen-model refit, third bulk scalar rescue, new
research-ticket chain or repeated recovery stage. All immutable scope limits
and raw-preservation gaps remain in SESSION-STATE.json. A different controller
or fixture cannot silently revive an old scientific terminal.
''')
    print(json.dumps({'status': state['status'], 'changed_existing_fields': changed,
                      'new_native_runs': 0, 'packages_admitted': 0}))


if __name__ == '__main__':
    main(sys.argv[1])
