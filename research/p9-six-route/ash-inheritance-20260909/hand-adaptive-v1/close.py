"""Synchronize only verified scoped Hand evidence; no engine or admission."""
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT=Path('research/p9-six-route')
HERE=ROOT/'ash-inheritance-20260909/hand-adaptive-v1'
OUTPUT=HERE/'descriptor-1'


def require(ok,why):
    if not ok:raise ValueError(why)


def load(p):return json.loads(p.read_bytes())
def save(p,v):p.write_text(json.dumps(v,indent=2)+'\n')
def sha(b):return hashlib.sha256(b).hexdigest()
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def git(repo,*a):return subprocess.check_output(['git','-C',str(repo),*a]).decode().strip()


def sync(repo):
    qual=load(repo/HERE/'reader-repair-1/execution-1/RESULTS.json')
    proof=load(repo/HERE/'reader-repair-1/execution-1/REMOTE-READBACK.json')
    descriptor=load(repo/OUTPUT/'RESULTS.json')
    require(proof['readout_reproduced'] and proof['all_bytes_equal'] and proof['qualification']==qual,'QUALIFIED_INPUT')
    require(qual['status']=='HAND_ADAPTIVE_QUERY_CLONE_QUALIFIED_NOT_CERTIFICATE','QUALIFICATION')
    require(descriptor['retained_native_runs']==512 and descriptor['new_native_runs']==0,'DESCRIPTOR_SCOPE')
    state=load(repo/ROOT/'SESSION-STATE.json')
    state.update(status='P9_UNFINISHED_HAND_INTERFACE_AND_REALIZED_PROVENANCE_CHECKED',packages_admitted=0,p9_certified=False)
    state['hand_adaptive_interface']={'path':str(HERE.relative_to(ROOT)),
        'qualified':qual,'qualification_readback':str((HERE/'reader-repair-1/execution-1/REMOTE-READBACK.json').relative_to(ROOT)),
        'original_capture_terminal':'INCONCLUSIVE: reader expected front-pop; immutable native source requires back-pop',
        'native_replay_for_reader_repair':False,'default_on_original_queries_and_states_equal':True}
    state['hand_realized_descriptor_fields']={'result':descriptor,
        'output':str((OUTPUT/'RESULTS.json').relative_to(ROOT)),
        'readback':str((OUTPUT/'REMOTE-READBACK.json').relative_to(ROOT)),
        'admitted_descriptor':False,'frozen_model_refit':False}
    next_action=('Bind the complete prospective Hand package causal-value and descriptor-validation contract '
      'using the qualified general-instance masks and provenance extractor. Include adaptive source/payoff subsets, '
      'source-enabled consumer access, background draw, actual HP/utility and competent-policy/peer/real-economy '
      'and independent-confirmation obligations before any new population. Natural provenance is factual history, '
      'not counterfactual marginal value. Do not reopen Bloodfire value, controller tuning or frozen models.')
    state['exact_next_action']=next_action
    save(repo/ROOT/'SESSION-STATE.json',state)
    text='''# P9 current handoff — Hand intervention interface and realised fields checked

Continue #421 on `research/p9-six-route-local-20260905`. Product reference remains
`2ed6cdb0302ba3aab5845a18d862841165e8aaf7`. Target is three complete strategies
per aspect. 0/6 full current certificates; no P9 PASS or product promotion.
Author self-review is explicitly non-independent.

## Completed; do not repeat

The adaptive Bloodfire study is closed NOT_ESTABLISHED: V5 worlds00/01/10 won298/512,
world11 won302/512; frozen intervals cross zero, resources passed, V0 skipped.
All2127 files are remotely preserved. This is not equivalence or universal futility.
All previous controller/acquisition/resource negatives retain their precise scope.

The old local source-utility packet is fully restored and remotely preserved:
55 exact original files,1728 constructed records,39,273,762 raw bytes. The external
receipt is `ash-inheritance-20260909/causal-transport-v1/publication-1/REMOTE-READBACK.json`.
No replay was used to fill that transport gap. Historical other raw gaps remain.
BloodRite is lose3HP then gain2/3Energy, NOT draw.

Hand's three effect-view masks now apply by card ID, not fixed fixture UID, and
survive both the public forecast clone and exact observer clone.384 mask cases,
48 all-on full query/state/event references and48 negatives per clone path are
preserved under `ash-inheritance-20260909/hand-adaptive-v1`. The first reader used
front-pop instead of native back-pop; `reader-repair-1` changes only that decoder
expectation and reuses every raw byte. No native replay, new policy or new content.
The repaired result and its cold-readback are complete. Finite qualification is
not an independent source/runtime oracle or a whole-population certificate.

`descriptor-1` extracts actual retained direct-source hand instances, separates
Exhaust/relic/ordinary draw and source-drawn consumer access. Its finite validation
uses the preserved384 cases and96 factorial contrasts; source-null32 contrasts
remain zero, and384 UID-renaming checks hold. Every assigned aware-arm run from
the old joint study is read (512), not a selected successful subgroup. This is a
factual provenance field extractor, NOT a counterfactual effect, validated predictor,
new classifier fit, complete descriptor admission or fresh confirmation cohort.

## Exact continuation

'''+next_action+'''

Do not replay v25, source-utility matrices, old cohorts, the Hand clone gate, controller
or cache trials. Do not manufacture new strategy slots from Preparation/Surge, which
are alternative producers in one family. The failed joint policy is an audit instrument,
not an admitted controller. No population stage is opened by this closure.

Remaining: full exact-current package causality/descriptor/policy/peer/economy and
independent proof; three strategies per aspect; seven-direction detector; corrected
confirmation and unrestricted endpoint retention; every hard guardrail; minimum
lifecycle, exact-head review, one selected product integration and #108 receipt.
'''
    (repo/ROOT/'SESSION-HANDOFF.md').write_text(text)
    (repo/ROOT/'package-disposition-20260908/ROADMAP.md').write_text('''# P9 current outcome roadmap

Full exact-current certificates:0/6. Bloodfire fixed adaptive value is closed
NOT_ESTABLISHED. The55-file historical packet is fully remotely preserved.
Hand general-instance intervention/clones and factual provenance extraction are
checked, but are not a package or a validated predictive descriptor.

1. Complete a prospective Hand package contract and the genuinely missing adaptive
   value/descriptor/policy/peer/economy/independent proof. Reuse qualified interfaces.
2. Fill three viable/reachable/distinct complete strategies per aspect. Alternative
   producers in one family do not create new slots; old negatives remain closed.
3. Admit the seven-direction detector, corrected independent confirmation and
   unrestricted endpoint retention under every unchanged hard guardrail.
4. Deliver one selected product/detector/lifecycle packet, exact-head review,
   exact-product integration and the #108 receipt. No early promotion.

No more recovery loops, repeated native gate, controller microtuning or model refit.
''')
    paths=[repo/HERE/n for n in ('descriptor.py','close.py')]
    paths += [p for p in sorted((repo/OUTPUT).iterdir()) if p.is_file() and p.name not in ('SYNC-MANIFEST.json','REMOTE-READBACK.json')]
    paths += [repo/ROOT/n for n in ('SESSION-HANDOFF.md','SESSION-STATE.json','package-disposition-20260908/ROADMAP.md')]
    save(repo/OUTPUT/'SYNC-MANIFEST.json',[{'path':str(p.relative_to(repo)),'bytes':p.stat().st_size,'sha256':sha(p.read_bytes()),'git_blob':blob(p.read_bytes())} for p in paths])


def cold(original,remote,receipt):
    require(not receipt.exists(),'RECEIPT_EXISTS')
    data=(original/OUTPUT/'SYNC-MANIFEST.json').read_bytes()
    require(data==(remote/OUTPUT/'SYNC-MANIFEST.json').read_bytes(),'MANIFEST_EQUALITY')
    files=json.loads(data)
    for r in files:
        p=Path(r['path']);require(not p.is_absolute() and '..' not in p.parts,'PATH')
        a=(original/p).read_bytes();b=(remote/p).read_bytes()
        require(a==b and len(b)==r['bytes'] and sha(b)==r['sha256'],'COLD_BYTES:'+str(p))
        require(blob(b)==r['git_blob']==git(remote,'rev-parse','HEAD:'+str(p)),'GIT_BLOB:'+str(p))
    with tempfile.TemporaryDirectory(prefix='hand-descriptor-readback-') as d:
        out=Path(d)/'reproduced'
        subprocess.run([sys.executable,str(remote/HERE/'descriptor.py'),str(remote),str(out)],check=True,stdout=subprocess.DEVNULL)
        for name in ('RESULTS.json','FIELDS.jsonl','RUN-COVERAGE.json','INPUTS.json'):
            require((out/name).read_bytes()==(remote/OUTPUT/name).read_bytes(),'EXACT_REPRODUCTION:'+name)
    save(receipt,{'kind':'HAND_FIELDS_AND_CURRENT_CAPSULE_COLD_READBACK','published_head':git(remote,'rev-parse','HEAD'),
                  'files':files,'all_bytes_equal':True,'full_512_run_readout_reproduced':True,
                  'frozen_model_refit':False,'new_native_runs':0,'packages_admitted':0,'p9_certified':False})


if __name__=='__main__':
    if sys.argv[1]=='sync':sync(Path(sys.argv[2]).resolve())
    elif sys.argv[1]=='cold':cold(*(Path(p).resolve() for p in sys.argv[2:]))
    else:raise SystemExit('sync REPO | cold ORIGINAL_REPO COLD_REPO RECEIPT')
