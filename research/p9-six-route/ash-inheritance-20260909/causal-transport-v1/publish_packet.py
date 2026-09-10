"""Mechanical publication/capsule binding for already-completed evidence only."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path('research/p9-six-route')
STUDY = ROOT / 'ash-inheritance-20260909/causal-contract-v1'
TRANSPORT = ROOT / 'ash-inheritance-20260909/causal-transport-v1'
CAUSAL = ROOT / 'ash-inheritance-20260909/causal-value-v1'
PUBLICATION = TRANSPORT / 'publication-1'
MANIFEST = '79a23738fce726368bd6c3a1aabbd4d378016d6a2a16ef263376cb6494174e8e'


def require(ok, why):
    if not ok: raise ValueError(why)


def sha(b): return hashlib.sha256(b).hexdigest()
def blob(b): return hashlib.sha1(b'blob ' + str(len(b)).encode() + b'\0' + b).hexdigest()
def load(p): return json.loads(p.read_bytes())
def save(p, x): p.write_text(json.dumps(x, indent=2) + '\n')
def git(repo, *args): return subprocess.check_output(['git', '-C', str(repo), *args]).decode().strip()


def synchronize(repo):
    terminal = repo / CAUSAL / 'execution-1/TERMINAL.json'
    require(blob(terminal.read_bytes()) == 'b239c857882781e2745ae7398fa93ff33e11c240', 'TERMINAL_BINDING')
    t = load(terminal)
    require(t['status'] == 'BLOODFIRE_ADAPTIVE_VALUE_NOT_ESTABLISHED' and t['v0_skipped'] is True, 'NO_NEW_TERMINAL')
    require(sha((repo / STUDY / 'PACKET-MANIFEST.json').read_bytes()) == MANIFEST, 'ORIGINAL_PACKET')
    state_path = repo / ROOT / 'SESSION-STATE.json'
    state = load(state_path)
    state.update(status='P9_UNFINISHED_ADAPTIVE_BLOODFIRE_VALUE_NOT_ESTABLISHED',
                 no_active_research_processes=True, packages_admitted=0, p9_certified=False)
    state['source_utility_publication'] = {
        'path': str(STUDY.relative_to(ROOT)), 'manifest_sha256': MANIFEST,
        'original_files': 55, 'constructed_records': 1728,
        'raw_uncompressed_bytes': 39273762, 'native_replays_for_publication': 0,
        'readback_receipt': str((PUBLICATION/'REMOTE-READBACK.json').relative_to(ROOT)),
        'readback_status': 'Require the named successful receipt and exact published-head binding; this field is not itself proof.'}
    state['adaptive_bloodfire_value'] = {
        'terminal': str(terminal.relative_to(repo / ROOT)),
        'terminal_git_blob': blob(terminal.read_bytes()), 'status': t['status'],
        'wins_v5': t['stages']['5']['wins'], 'v0_opened': False,
        'scope': 'Fixed adaptive value not established; not universal futility or equivalence.'}
    next_action = ('Use the preserved source-utility operators to close the remaining Hand adaptive '
                   'intervention/query/clone and descriptor obligations before further population work. '
                   'Retain the closed Bloodfire adaptive claim and controller trials; do not rerun or '
                   'retune them. Full certificates still require competent-policy, peer, natural-economy '
                   'and independently assigned confirmation evidence under unchanged P9 acceptance.')
    state['exact_next_action'] = next_action
    save(state_path, state)
    handoff = '''# P9 current handoff — adaptive Bloodfire closed; source-utility packet restored

Continue #421 on `research/p9-six-route-local-20260905`. Product reference is
`2ed6cdb0302ba3aab5845a18d862841165e8aaf7`. Three complete strategies per aspect;
0/6 full current certificates. Author self-review is not independent evidence.

## Completed evidence, not work to repeat

The four-world adaptive study completed 512 outcomes/world at V5, 128 policies,
256 matched seed blocks. Worlds 00/01/10 each won298; 11 won302. Producer,
consumer and interaction estimates are0.0078125; all three frozen intervals
[-0.005859375,0.0234375] cross zero. Actual resource gates passed. The terminal
is BLOODFIRE_ADAPTIVE_VALUE_NOT_ESTABLISHED; V0 was not opened. The original2127-file
cold-readback and every outcome remain unchanged. Do not extend this sample,
claim no benefit or equivalence, change its primary metric, or tune a rescue.

The complete local source-utility packet is now reconstructed under
`ash-inheritance-20260909/causal-contract-v1/`:55 original files,1728 constructed
records and39,273,762 raw bytes. Publication uses complete preserved DAG nodes
and independently hash-bound missing file recipes; it does not claim the old
incomplete transport was complete. Verify the external receipt at
`ash-inheritance-20260909/causal-transport-v1/publication-1/REMOTE-READBACK.json`
and its exact published-head binding. Original local-only receipts stay immutable.
No engine replay or new independent sample is used for preservation.

Source correction: BloodRite loses3HP and grants2/3Energy, NOT draw. Preparation
and Surge draw are separate Hand sources. Source cost/utility, mediator payoff,
command eligibility, capped HP removal and overkill-based healing are distinct.
Finite fixed-command proof does not establish adaptive whole-run Hand causality,
validated descriptors, independent confirmation or package admission.

## Exact next action

''' + next_action + '''

No repeated recovery/reunion/census, v25/model fitting, old panels, alias studies,
controller/cache trials or source-utility matrices. Historical raw gaps in
SESSION-STATE remain unchanged. No product merge or #108 PASS.

Remaining: six complete certificates; seven-direction detector; corrected untouched
confirmation and unrestricted endpoint retention; hard guardrails; minimum lifecycle,
exact-head review, one selected product integration and exact-product #108 receipt.
'''
    (repo / ROOT / 'SESSION-HANDOFF.md').write_text(handoff)
    roadmap = '''# P9 current outcome roadmap

Full exact-current certificates:0/6. Current fixed adaptive Bloodfire value claim
is NOT_ESTABLISHED; the preserved negative is not universal nonviability.

1. Complete inherited Hand adaptive intervention/query/clone and descriptor proof;
   retain exact source utility, mediator, consumer, null and proper-subset boundaries.
   Reuse the now-preserved finite packet, not another set of chosen examples.
2. Complete eligible package competent-policy, peer, real-economy and independent
   confirmation evidence; fill three genuinely distinct strategies per aspect.
3. Admit the seven-direction detector, corrected untouched confirmation and
   unrestricted endpoint retention with all existing hard guardrails.
4. Deliver one selected minimal product/detector/lifecycle packet, exact-head
   review and exact merged-product #108 receipt. No premature promotion.

Do not improve a progress number by weakening a gate, renaming a closed family,
replaying exposed cohorts, tuning another controller or refitting frozen models.
Restoration, runtime qualification and a strong solver are not package admission.
'''
    (repo / ROOT / 'package-disposition-20260908/ROADMAP.md').write_text(roadmap)
    files = sorted(p for p in (repo / STUDY).rglob('*') if p.is_file() and '__pycache__' not in p.parts)
    files += [repo/ROOT/n for n in ('SESSION-HANDOFF.md','SESSION-STATE.json','package-disposition-20260908/ROADMAP.md')]
    files += [repo/TRANSPORT/n for n in ('restore_packet.py','test_restore.py','publish_packet.py',*(f'supplement-{i:02d}.b64' for i in range(4))) ]
    records = [{'path':str(p.relative_to(repo)), 'bytes':p.stat().st_size,
                'sha256':sha(p.read_bytes()), 'git_blob':blob(p.read_bytes())} for p in files]
    save(repo/PUBLICATION/'SYNC-MANIFEST.json', records)
    return records


def cold_check(original, cold, receipt):
    require(not receipt.exists(), 'RECEIPT_EXISTS')
    source = original/PUBLICATION/'SYNC-MANIFEST.json'
    require(source.read_bytes() == (cold/PUBLICATION/'SYNC-MANIFEST.json').read_bytes(), 'SYNC_MANIFEST')
    records = load(source)
    for r in records:
        rel=Path(r['path']); require(not rel.is_absolute() and '..' not in rel.parts, 'PATH')
        a=(original/rel).read_bytes(); b=(cold/rel).read_bytes()
        require(a == b and len(b)==r['bytes'] and sha(b)==r['sha256'], 'COLD_BYTES:'+str(rel))
        require(blob(b)==r['git_blob']==git(cold,'rev-parse','HEAD:'+str(rel)), 'REMOTE_GIT_BLOB:'+str(rel))
    native = load(cold/STUDY/'execution-1/TERMINAL.json')
    result = {'kind':'COMPLETE_ORIGINAL_SOURCE_UTILITY_REMOTE_PUBLICATION',
              'published_head':git(cold,'rev-parse','HEAD'), 'files':records,
              'original_packet_files':55,'all_bytes_equal':True,
              'packet_manifest_sha256':MANIFEST,'runtime_members':57,
              'raw_records':1728,'raw_uncompressed_bytes':39273762,
              'original_scientific_terminal':native['status'],
              'historical_local_receipts_unchanged':True,
              'transport_gap_repaired_by_exact_reconstruction':True,
              'new_native_runs':0,'new_independent_samples':0,'packages_admitted':0,'p9_certified':False}
    save(receipt,result)
    print(json.dumps({k:v for k,v in result.items() if k!='files'},indent=2))


if __name__=='__main__':
    import sys
    if sys.argv[1]=='sync': synchronize(Path(sys.argv[2]).resolve())
    elif sys.argv[1]=='cold': cold_check(*(Path(s).resolve() for s in sys.argv[2:]))
    else: raise SystemExit('sync REPO | cold ORIGINAL_REPO COLD_REPO RECEIPT')
