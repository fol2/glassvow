"""Finish exact serialized-readout verification and current capsule; no engine.

The original READOUT error is retained. Native Python integer dictionary keys
are compared through the same lossless JSON wire representation as the writer.
No statistic, threshold, input or scientific terminal is changed.
"""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
import control as c

ROOT=Path('research/p9-six-route')
HERE=ROOT/'ash-inheritance-20260909/hand-two-slope-v1'
CONTROL=HERE/'control-v1'
OUT=CONTROL/'closure-1'
PASS='SIGNED_CONTROL_NECESSARY_SCREEN_PASS_NOT_P9'


def wire(value): return (json.dumps(value,indent=2)+'\n').encode()
def load(p): return json.loads(p.read_bytes())
def save(p,v): p.write_bytes(wire(v))
def sha(b): return hashlib.sha256(b).hexdigest()
def blob(b): return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def git(p,*a): return subprocess.check_output(['git','-C',str(p),*a]).decode().strip()
def require(ok,why):
    if not ok: raise ValueError(why)


def path(value):
    p=Path(value)
    require(value and not p.is_absolute() and '..' not in p.parts and p.as_posix()==value and '\\' not in value,'PATH')
    return p


def verify_wire(actual,saved):
    require(wire(actual)==saved,'EXACT_SERIALIZED_READOUT')
    return actual!=json.loads(saved)


def checked_capture(repo,cold,relative):
    a=repo/relative;b=cold/relative
    data=(a/'FILES.json').read_bytes();require(data==(b/'FILES.json').read_bytes(),'MANIFEST')
    entries=json.loads(data);names={r['path'] for r in entries}
    require(len(names)==len(entries),'DUPLICATE_PATH')
    actual={p.relative_to(b).as_posix() for p in b.rglob('*') if p.is_file()}
    require(actual==names|{'FILES.json'},'FULL_CAPTURE')
    for r in entries:
        rel=path(r['path']);raw=(b/rel).read_bytes()
        require(raw==(a/rel).read_bytes() and len(raw)==r['bytes'] and sha(raw)==r['sha256'],'COLD_BYTES:'+str(rel))
        require(blob(raw)==git(cold,'rev-parse','HEAD:'+str(relative/rel)),'GIT_BLOB:'+str(rel))
    return entries


def run(repo,cold,out):
    require(not out.exists(),'OUTPUT_EXISTS');require(git(repo,'rev-parse','HEAD')==git(cold,'rev-parse','HEAD'),'CHECKOUT_HEAD')
    require(blob((repo/CONTROL/'control.py').read_bytes())=='116e429989aedf7d7607ce7036b75df97b0f61fd','CONTROL_IDENTITY')
    require(blob((repo/CONTROL/'PROTOCOL.json').read_bytes())=='c33a0cde306eed3e8ee9ba68288db49cc6e1538d','PROTOCOL_IDENTITY')
    entries=checked_capture(repo,cold,CONTROL/'execution-2')
    capture=cold/CONTROL/'execution-2';_,reader=c.dependencies(cold)
    result=reader.analyze(capture/'raw',load(capture/'RESOLVED-PROTOCOL.json'))
    key_conversion=verify_wire(result,(capture/'RESULTS.json').read_bytes())
    terminal=load(capture/'TERMINAL.json')
    require(terminal['status']==result['status'] and terminal['rows']==result['rows']==1024 and 'failure' not in terminal,'TERMINAL')
    query=load(cold/HERE/'native-v1/query-repair-1/execution-1/REMOTE-READBACK.json')
    require(query['all_bytes_equal'] and query['readout_reproduced'] and query['scientific_status']=='COHERENT_HAND_QUERY_AND_OFF_MASK_QUALIFIED_NOT_CERTIFICATE','QUERY_PREREQUISITE')
    out.mkdir(parents=True)
    receipt={'kind':'ISOLATED_HAND_SIGNED_CONTROL_SERIALIZED_COLD_READBACK','input_head':git(cold,'rev-parse','HEAD'),
        'capture_files':len(entries)+1,'all_bytes_equal':True,'original_json_bytes_reproduced':True,
        'python_integer_key_difference_observed':key_conversion,'scientific_status':result['status'],
        'old_readback_failure_run':34540101853,'old_failure':'READOUT: Python integer-key mapping versus JSON string-key mapping',
        'old_raw_protocol_and_terminal_unchanged':True,'new_native_runs':0,'packages_admitted':0,'p9_certified':False}
    save(out/'CAPTURE-READBACK.json',receipt)
    summary=[{k:g[k] for k in ('aspect','vow','baseline_wins','candidate_wins','difference','baseline_faults','gates')} for g in result['grids']]
    decision={'kind':'ISOLATED_HAND_QUERY_AND_SIGNED_CONTROL_FRONTIER','status':result['status'],'grids':summary,
        'candidate_identity':load(capture/'RESOLVED-PROTOCOL.json')['content_sha256']['candidate'],
        'query_qualification':query,'signed_control_capture':receipt,
        'decision':'The selected isolated-Hand candidate passes this fixed necessary signed-control screen; full package value and all remaining acceptance remain unproved.' if result['status']==PASS else 'The selected candidate fails this fixed signed-control screen; no extension or parameter rescue.',
        'review_kind':'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT','new_native_runs':0,'packages_admitted':0,'p9_certified':False}
    save(out/'DECISION.json',decision)
    statepath=repo/ROOT/'SESSION-STATE.json';state=load(statepath)
    next_action=('For this exact qualified two-slope Hand candidate, freeze the missing adaptive group-source/payoff value and descriptor/policy/peer/economy confirmation contract. Reuse the coherent archived controller and correct n-plus-floor OFF mask. Do not retune the controller or rerun old Hand/Bloodfire cohorts. This signed screen alone opens no population.' if result['status']==PASS else 'Close this exact isolated-Hand candidate screen without changing its seeds, limits or controller. Select only an eligible source-bound alternative under active authority; do not reopen this terminal.')
    state.update(status='P9_UNFINISHED_ISOLATED_HAND_QUERY_AND_CONTROL_COMPLETE',packages_admitted=0,p9_certified=False,no_active_research_processes=True,exact_next_action=next_action)
    state['hand_two_slope_frontier']={'status':result['status'],'decision':str((OUT/'DECISION.json').relative_to(ROOT)),
        'readback':str((OUT/'CAPTURE-READBACK.json').relative_to(ROOT)),'grids':summary,'candidate_content_sha256':decision['candidate_identity'],'full_certificate':False}
    save(statepath,state)
    handoff='''# P9 handoff — coherent two-slope Hand query and signed-control decision complete

Continue #421 on `research/p9-six-route-local-20260905`.
Main remains `2ed6cdb0302ba3aab5845a18d862841165e8aaf7`.
Target: three complete viable/reachable/distinct strategies per aspect. **0/6**.
Author self-review is not independent evidence. No product promotion or P9 PASS.

## Current exact candidate and completed evidence

The selected inherited Hand law is `n*max(0,q-4)+2*min(q,4)`, n6/7 base/upgraded,
with existing minimum Bloodfire background. Sources, rarity, pools, Core/Art and
unrelated product rules are not retuned. OFF zeros both n and floor_per.
Native-v1's original query terminal remains INCONCLUSIVE. Its q4 projection and
supposed legacy-query mutation were contradicted by the complete inherited scorer:
the fixture's existing deck forecast is3; the added bottom-layer patch double-counted
a normalization. `query-repair-1` uses the exact archived coherent legacy-query
runtime without changing controller weights/search, reuses280 ON records and adds
only280 previously missing OFF records. Its18-file cold-readback is complete.
This explicit false-oracle correction does not rewrite the original raw or verdict.

The signed shipping RandomBuild arm2 screen has1024 fixed outcomes,128 paired
seeds73760100..73760227 per grid. No research planner/acquisition adapter is installed.
The original pre-outcome NONCARD_CONTENT_DELTA failure remains in control-v1/execution-1.
The predicate was corrected to bind the already-selected exact inherited Bloodfire
status. Candidate, seeds and scientific criteria were unchanged for execution-2.
The later readback fault was Python integer-key versus JSON string-key comparison;
the unchanged original reader now reproduces the exact stored JSON bytes. No game
was replayed for either delivery correction. See control-v1/closure-1/DECISION.json
and CAPTURE-READBACK.json. Guards are necessary, not a certificate or full C2.

'''+result['status']+'\n'+json.dumps(summary,indent=2)+'''

## Immutable earlier scope

Original Hand adaptive-value and Bloodfire adaptive-value claims remain NOT_ESTABLISHED;
no old outcome, model, threshold, controller or cohort is rescued. Source-utility55-file
packet, Hand clone/dispatch qualification and full factual source census are preserved.
BloodRite loses3HP and grants2/3Energy, not draw. Preparation/Surge are alternative
sources of one Hand family. Other historical raw gaps remain in SESSION-STATE.

## Exact next action

'''+next_action+'''

Remaining: full package causality, descriptor, competent-policy/peer/natural-economy
and independent confirmation; three strategies per aspect; seven-direction detector;
corrected untouched confirmation and unrestricted endpoint retention; all guardrails;
minimal lifecycle, exact-head review, one selected product integration and #108 receipt.
Do not rerun the source/query matrices, this control screen, v25, old models or panels.
'''
    (repo/ROOT/'SESSION-HANDOFF.md').write_text(handoff)
    (repo/ROOT/'package-disposition-20260908/ROADMAP.md').write_text('# P9 current outcome roadmap\n\n0/6 complete current certificates.\n\n1. '+next_action+'\n2. Complete three strategies per aspect; alternative producers do not create extra slots.\n3. Admit detector, corrected independent confirmation, unrestricted endpoint retention and all hard guardrails.\n4. Deliver one minimal product/detector/lifecycle packet and exact-product #108 receipt.\n\nCompleted query/native/control work is reused, never rerun merely to recover or synchronize it.\n')
    paths=[repo/CONTROL/n for n in ('finish_control.py','test_finish_control.py')]+list(out.iterdir())
    paths += [repo/ROOT/n for n in ('SESSION-HANDOFF.md','SESSION-STATE.json','package-disposition-20260908/ROADMAP.md')]
    save(out/'FILES.json',[{'path':str(p.relative_to(repo)),'bytes':p.stat().st_size,'sha256':sha(p.read_bytes()),'git_blob':blob(p.read_bytes())} for p in paths])


def verify(repo,cold,receipt):
    require(not receipt.exists(),'RECEIPT_EXISTS')
    data=(repo/OUT/'FILES.json').read_bytes();require(data==(cold/OUT/'FILES.json').read_bytes(),'CLOSURE_MANIFEST')
    records=json.loads(data)
    for r in records:
        rel=path(r['path']);b=(cold/rel).read_bytes()
        require(b==(repo/rel).read_bytes() and len(b)==r['bytes'] and sha(b)==r['sha256'] and blob(b)==r['git_blob']==git(cold,'rev-parse','HEAD:'+str(rel)),'CLOSURE_BYTES:'+str(rel))
    save(receipt,{'kind':'ISOLATED_HAND_COMPLETE_CLOSURE_COLD_READBACK','published_head':git(cold,'rev-parse','HEAD'),
        'files':records,'all_bytes_equal':True,'new_native_runs':0,'packages_admitted':0,'p9_certified':False})


if __name__=='__main__':
    mode,*a=sys.argv[1:];args=[Path(p).resolve() for p in a]
    if mode=='run':run(*args)
    elif mode=='verify':verify(*args)
    else:raise SystemExit('run ORIGINAL COLD OUTPUT | verify ORIGINAL COLD RECEIPT')
