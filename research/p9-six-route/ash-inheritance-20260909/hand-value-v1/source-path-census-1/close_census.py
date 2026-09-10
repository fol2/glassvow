"""Close the completed source-path diagnosis; no scientific terminal changes."""
import hashlib
import json
from pathlib import Path
import sys

ROOT=Path('research/p9-six-route')
HERE=ROOT/'ash-inheritance-20260909/hand-value-v1/source-path-census-1'
NEXT=('Keep hand-value-v1 and Bloodfire adaptive-value terminals closed. Do not extend their samples, '
      'replace their win estimand, or nominate another controller. The next design screen is the already-authored '
      'Hand two-slope consumer in source-package-audit-20260908/candidate.patch and observer.patch, considered '
      'ONLY as an isolated inherited-family improvement: native Preparation/Surge, rarity/pools, Core/Art, '
      'Bloodfire and other cards stay unchanged. First bind the exact eligible closure scope, full native '
      'payoff envelope and matched public-query/intervention contract at zero rows. The old coefficient-zero '
      'Hand mask cannot simply be reused: floor_per remains a payoff. Reject the design if this complete '
      'contract cannot be supplied; do not add a parameter grid. No new native cohort is opened by this diagnosis.')


def require(ok,why):
    if not ok:raise ValueError(why)


def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def sha(b):return hashlib.sha256(b).hexdigest()
def load(p):return json.loads(p.read_bytes())
def save(p,v):p.write_text(json.dumps(v,indent=2)+'\n')


def decision(r):
    require(r['immutable_primary_terminal']=='HAND_ADAPTIVE_GROUP_VALUE_NOT_ESTABLISHED','TERMINAL')
    require(r['runs_read']==2048 and set(r['worlds'])=={'00','01','10','11'},'COVERAGE')
    require(all(x['runs']==512 for x in r['worlds'].values()),'WORLD_COVERAGE')
    require(r['observed_source_off_draw_leaks']==r['observed_source_off_provenance_leaks']==0,'SOURCE_LEAK')
    for w in ('00','01'):
        t=r['worlds'][w]['totals']
        require(t['direct_source_draws']==t['either_source_path_plays']==0,'OFF_WORLD')
    t=r['worlds']['11']['totals']
    require(0<=t['either_source_path_plays']<=t['phantom_plays'] and t['phantom_plays']>0,'FRACTION')
    overlap=t['retained_source_plays']+t['source_access_plays']-t['either_source_path_plays']
    require(0<=overlap<=min(t['retained_source_plays'],t['source_access_plays']),'UNION')
    return {'status':'CURRENT_HAND_VALUE_BRANCH_CLOSED_WITH_FULL_SOURCE_CENSUS',
        'commands_read':sum(v['totals']['commands'] for v in r['worlds'].values()),
        'runs_read':2048,'all_on_phantom_plays':t['phantom_plays'],
        'all_on_either_source_path_plays':t['either_source_path_plays'],
        'all_on_either_source_fraction':t['either_source_path_plays']/t['phantom_plays'],
        'all_on_source_path_overlap':overlap,'paired_responses':r['paired_responses'],
        'decision':'Do not treat this negative as an unfinished tool/recovery problem. The checked source suppression did not leak, both specified source pathways were counted, and the fixed primary still failed. Stop this value nomination, not the entire Hand family or P9 programme.',
        'interpretation_limit':'Sparse factual source linkage is a design diagnostic, not a causal attribution of every lost win. Zero average win interaction is neither no individual response nor equivalence.',
        'next_action':NEXT,'candidate_selected_or_admitted':False,
        'new_native_runs':0,'new_independent_samples':0,'packages_admitted':0,'p9_certified':False,
        'review_kind':'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT'}


def run(repo):
    root=repo/HERE;out=root/'closure-1';require(not out.exists(),'OUTPUT_EXISTS')
    for name,want in [('execution-1/RESULTS.json','f494a07ee6ae1a519aefeb8f91a7a2ce5e4cadc8'),
                      ('execution-1/REMOTE-READBACK.json','eba2ca517f01bfb3c0cf91f066afda8ebfad96f7')]:
        require(blob((root/name).read_bytes())==want,'INPUT:'+name)
    receipt=load(root/'execution-1/REMOTE-READBACK.json')
    require(receipt['all_bytes_equal'] is True and receipt['full_census_reproduced'] is True,'READBACK')
    for r in receipt['files']:
        p=Path(r['path']);require(not p.is_absolute() and '..' not in p.parts,'PATH')
        b=(root/p).read_bytes();require(len(b)==r['bytes'] and sha(b)==r['sha256'] and blob(b)==r['git_blob'],'BYTES')
    d=decision(load(root/'execution-1/RESULTS.json'));out.mkdir()
    d['evidence_head']='9daa2221faf38498d6ede31fa97bede6b72f7164'
    d['original_primary_unchanged']=True
    save(out/'DECISION.json',d)
    state_path=repo/ROOT/'SESSION-STATE.json';state=load(state_path)
    state.update(status='P9_UNFINISHED_HAND_VALUE_AND_SOURCE_DIAGNOSIS_CLOSED',exact_next_action=NEXT,
                 packages_admitted=0,p9_certified=False,no_active_research_processes=True)
    state['hand_value_source_census']={'decision':str((HERE/'closure-1/DECISION.json').relative_to(ROOT)),
        'readback':str((HERE/'execution-1/REMOTE-READBACK.json').relative_to(ROOT)),
        'source_off_leaks':0,'complete_runs':2048,'new_native_runs':0,'descriptor_admitted':False}
    save(state_path,state)
    hp=repo/ROOT/'SESSION-HANDOFF.md'
    text=hp.read_text();marker='## Exact continuation\n\n'
    require(text.count(marker)==1,'HANDOFF_MARKER')
    prefix=text.split(marker)[0]
    hp.write_text(prefix+'## Completed full source-path diagnosis\n\n'
      +'All2048 retained runs /820147 commands were read; source-off worlds had zero direct-source draws or provenance leaks. '
      +'In11,1973 Phantom plays include168 with either specified source path (158 retained-other,60 consumer-access,50 overlap). '
      +'This is factual provenance, not a counterfactual descriptor or a certificate. Paired win responses: source44 favourable/17 adverse; '
      +'consumer19/13; interaction15/15. No outcomes, intervals, cohorts or stopping rules were changed. '
      +'Read `ash-inheritance-20260909/hand-value-v1/source-path-census-1/closure-1/DECISION.json` and its input cold-readback.\n\n'
      +marker+NEXT+'\n\nRemaining: full package causality/descriptor/policy/peer/economy/independent evidence; '
      +'three distinct complete strategies per aspect; seven-direction detector; corrected confirmation and unrestricted retention; '
      +'all hard guardrails; minimum lifecycle, exact-head review, one selected product integration and #108 receipt. '
      +'Author review is not independent. No native or population work is launched by this closure.\n')
    road=repo/ROOT/'package-disposition-20260908/ROADMAP.md'
    road.write_text('# P9 current outcome roadmap\n\n0/6 complete current certificates. Hand and Bloodfire fixed adaptive-value claims are closed, not waiting for recovery.\n\n'
      +'1. '+NEXT+'\n'
      +'2. Only after an eligible complete package contract and its cheapest falsifying controls pass, complete policy/peer/economy and independently assigned confirmation. Existing source/observer evidence carries only unchanged dependencies.\n'
      +'3. Cover three viable/reachable/distinct packages per aspect; admit the seven-direction detector, corrected confirmation and unrestricted endpoint retention with all guardrails.\n'
      +'4. Deliver minimum lifecycle, exact-head review, one product integration and the exact-product #108 receipt.\n\n'
      +'No controller microtuning, repeated old matrices/cohorts, refitting of the frozen model, renamed old families or unqualified proxy admission.\n')
    paths=[root/'close_census.py',root/'test_close_census.py',out/'DECISION.json',state_path,hp,road]
    save(out/'FILES.json',[{'path':str(p.relative_to(repo)),'bytes':p.stat().st_size,'sha256':sha(p.read_bytes()),'git_blob':blob(p.read_bytes())} for p in paths])


if __name__=='__main__':run(Path(sys.argv[1]).resolve())
