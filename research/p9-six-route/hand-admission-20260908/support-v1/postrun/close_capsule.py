"""Refresh only the current task capsule after a validated support terminal."""
from __future__ import annotations
import hashlib
import json
from pathlib import Path
import sys


def main(repo, source_head):
    repo = Path(repo).resolve()
    root = repo / 'research/p9-six-route'
    study = root / 'hand-admission-20260908/support-v1'
    result_path = study / 'postrun/RESULTS.json'
    result = json.loads(result_path.read_bytes())
    assert result['kind'] == 'POST_CAPTURE_FULL_RAW_BINDING_AND_UNCHANGED_AGGREGATION'
    assert result['new_native_runs'] == 0 and result['new_independent_samples'] == 0
    assert result['packages_admitted'] == 0 and result['p9_certified'] is False
    status = result['scientific_status']
    assert status in ('HAND_NATURAL_SUPPORT_GATE_PASS_NOT_PACKAGE_ADMISSION',
                      'HAND_NATURAL_SUPPORT_GATE_FAIL_IN_FIXED_POLICY_FAMILY')
    state_path = root / 'SESSION-STATE.json'
    state = json.loads(state_path.read_bytes())
    assert state['candidate_sha256'] == '3c7b2f9dba362d19128ef82ad559d3f26e54925371d823a665767032255eadaa'
    assert state['descriptor_sha256'] == '2cfe1d8ff00d5ff695664c597be3a93e3960f39732fa049eac82b9397184bab7'
    assert state['packages_admitted'] == 0 and state['p9_certified'] is False
    gate_pass = status == 'HAND_NATURAL_SUPPORT_GATE_PASS_NOT_PACKAGE_ADMISSION'
    next_action = (
        'The fixed Hand natural-support screen passed at both vows. Do not repeat it. '
        'Complete the separately frozen independent Hand complementarity and peer/policy '
        'confirmation with actual signed controls, duration and ceiling guardrails. The '
        'recorded-prefix opportunity predicate is not counterfactual reoptimisation.'
        if gate_pass else
        'The fixed Hand/controller-family support screen is closed negative. Skip any '
        'stage forbidden by its terminal. Do not extend seeds, refit, change this sampler '
        'or replay Hand to rescue the label. Continue the already listed next eligible '
        'Smolder/Fervor package obligations; preserve the Hand evidence for scope-limited '
        'reuse. This does not establish universal Hand nonviability.')
    state['status'] = ('P9_UNFINISHED_HAND_NECESSARY_SUPPORT_PASSED' if gate_pass else
                       'P9_UNFINISHED_FIXED_HAND_SUPPORT_CANDIDATE_CLOSED_NEGATIVE')
    state['hand_support'] = {
        'status': status, 'evidenced_source_head': source_head,
        'protocol_path': 'hand-admission-20260908/support-v1/PROTOCOL.json',
        'terminal_path': 'hand-admission-20260908/support-v1/capture-1/TERMINAL.json',
        'audit_path': 'hand-admission-20260908/support-v1/postrun/RESULTS.json',
        'audit_sha256': hashlib.sha256(result_path.read_bytes()).hexdigest(),
        'last_completed_vow': result['last_completed_vow'],
        'stages': result['stage_counts'],
        'raw_streams_checked': result['full_raw_streams_hash_checked'],
        'review_kind': 'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT',
        'new_native_runs_in_postrun_audit': 0,
        'independent_confirmation': False,
        'scope': 'Fixed 128-configuration existing-controller family and four seeds per '
                 'gated stage. Necessary support only, not complete package certification.'}
    state['hand_causal_preflight'] = {
        'evidence_head': 'dadb74bff88a76bdc3b33d52c05d8c86a7045258',
        'receipt': 'hand-admission-20260908/native-1/EXECUTION.json',
        'status': 'HAND_PREFLIGHT_PASS_WITH_EXACT_LOCAL_REMOTE_BYTES',
        'scope': 'Already completed finite observer/component-intervention preflight; do not rerun.'}
    state['exact_next_action'] = next_action
    state['no_active_research_processes'] = True
    state_path.write_text(json.dumps(state, indent=2) + '\n')
    counts = '\n'.join(f"| V{v} | {r['rows']} | {r['active']} | {r['inactive']} | "
                       f"{r['ambiguous']} | {r['reachable']} |"
                       for v, r in result['stage_counts'].items())
    text = f'''# P9 current handoff — fixed Hand support has a verified terminal

Continue #421 on research/p9-six-route-local-20260905. Owner target remains
three viable, reachable, genuinely distinct strategies per aspect. **P9 is not
complete; 0/6 exact-current packages are formally admitted.** Source content,
core law, coupled Stun/Shatter, IDs/RNG/save contracts and acceptance are unchanged.
Author self-review is authorised, explicitly not independent confirmation.

## Actual frontier

Hand observer/component preflight and the six-package disposition are already
complete. The support study now has terminal **{status}**.
The post-capture audit binds every preserved seed child to its recorded config,
compressed and expanded raw identities, parent cell and unchanged frozen summary.
Read SESSION-STATE.json and the referenced postrun/RESULTS.json, not an older chat.

| Completed stage | Rows | Active policies | Inactive | Ambiguous | Reachable |
|---|---:|---:|---:|---:|---:|
{counts}

The predicate includes both actual positive source-by-payoff health interaction
and source removal blocking the recorded command prefix. postrun/RESULTS.json
keeps these channels separate. A blocked fixed script is not inability of a
reoptimised policy. Counts are configurations within one frozen family, not
independent people; support does not certify viability, C2 or endpoint retention.

## Exact next action

{next_action}

Reuse the existing package-disposition-20260908/ROADMAP.md; do not create another
roadmap or census. Complete only the remaining formal/causal/policy/economy claims
for eligible packages, then seven-direction detector, corrected untouched
confirmation and unrestricted retention under every hard guardrail, minimum
lifecycle, exact-product integration/review and #108 receipt. Do not treat the
balanced research controller as signed RandomBuild, or invent a new requirement
for six globally new primitives.

## Preservation and no-repeat boundary

The native support process has terminated before this update. All available raw
capture and per-chunk readbacks stay immutable in capture-1; this audit runs no
engine and adds no sample. No force push or product merge. The known original-arm
archive gap and missing old full validation events remain explicitly recorded in
SESSION-STATE.json; current support preservation does not repair those old gaps.

Do not replay reunion, v25, old 1024/2048 panels, the negative 672-row verifier,
Facet words/subwords, composition-v1, Hand 1032-row preflight, or this closed
support screen. Verify current remote/diff before writing and never compete with
an active writer. Historical #535/PR #538 are completed capability records, not
an instruction to reopen that work or a P9 approval. The source freeze and
scientific stopping rules remain untouched.
'''
    (root / 'SESSION-HANDOFF.md').write_text(text)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
