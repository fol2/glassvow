"""Source-derived query correction; only missing coherent-runtime OFF rows run.

The old fixed native-v1 terminal stays INCONCLUSIVE. Its q=4 draft projection
and supposed legacy-query mutant are contradicted by the full inherited source.
This correction does not change content, weights, search or population outcomes.
"""
from __future__ import annotations
import hashlib
import importlib.util
import json
import lzma
from pathlib import Path
import subprocess
import sys
import tarfile

BASE = Path('research/p9-six-route/ash-inheritance-20260909/hand-two-slope-v1/native-v1')
ROLES = ('reference', 'linear', 'candidate', 'legacy-mask', 'legacy-query')
CONTEXTS = ('plain', 'block', 'weak-vulnerable', 'lethal', 'fatal-thorns', 'shatter', 'no-energy')
ENGINE = '8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e'


def require(ok, reason):
    if not ok: raise ValueError(reason)


def sha(b): return hashlib.sha256(b).hexdigest()
def blob(b): return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def load(p): return json.loads(p.read_bytes())
def save(p, v): p.write_text(json.dumps(v, indent=2)+'\n')


def raw(q, upgraded, nonlinear, on=True):
    require(type(q) is int and q >= 0 and type(upgraded) is bool and type(on) is bool, 'RAW_TYPES')
    if not on: return 0
    n = (7 if upgraded else 6) if nonlinear else (4 if upgraded else 3)
    return n*max(0,q-4)+2*min(q,4) if nonlinear else n*q


def draft(r, nonlinear):
    # Source-bound fixture: only Phantom and Defend in deck. Thus draw/sight/str
    # features are zero, and the unchanged clamped forecast is exactly 3.
    return raw(3, r['up'], nonlinear, r['active']) - 2


def keys(active):
    return {f'{a}:{v}:{str(u).lower()}:{q}:{x}:{str(on).lower()}'
            for a in (0,1) for v in (0,5) for u in (False,True)
            for q in (0,4,5,6,9) for x in CONTEXTS for on in active}


def rows(p, active):
    raw_bytes = lzma.decompress(p.read_bytes()) if p.suffix == '.xz' else p.read_bytes()
    lines = raw_bytes.splitlines()
    require(all(x.strip() for x in lines), 'EMPTY_RECORD')
    data = [json.loads(x) for x in lines]
    expected = keys(active)
    require(data.pop() == {'kind':'terminal','cases':len(expected)}, 'ROW_TERMINAL')
    indexed = {r['key']:r for r in data}
    require(len(indexed)==len(data)==len(expected) and set(indexed)==expected, 'COVERAGE')
    return indexed


def binding(capture):
    for r in load(capture/'FILES.json'):
        p = Path(r['path']); require(not p.is_absolute() and '..' not in p.parts, 'PATH')
        b=(capture/p).read_bytes()
        require(len(b)==r['bytes'] and sha(b)==r['sha256'], 'OLD_BYTES:'+str(p))
    require(load(capture/'REMOTE-READBACK.json')['all_bytes_equal'] is True, 'OLD_READBACK')
    require(load(capture/'TERMINAL.json')['failure']=="ValueError('QUERY_PROJECTION:reference:0:0:false:0:plain:true')", 'OLD_TERMINAL')
    manifest=load(capture/'SOURCE-MANIFEST.json')
    with tarfile.open(capture/'runtime-source.tar.xz','r:xz') as tf:
        source={}
        for name in ('legacy_policy.gd','policy_v8.gd','greedy_stock.gd','gate_delta.gd'):
            data=tf.extractfile('legacy-query/'+name).read();rec=manifest['legacy-query'][name]
            require(len(data)==rec['bytes'] and sha(data)==rec['sha256'],'SOURCE:'+name)
            require(rec==manifest['reference'][name], 'UNCHANGED_QUERY_AND_FIXTURE:'+name)
            source[name]=data.decode()
        require('"phantom":n*4.0' in source['legacy_policy.gd'], 'BASELINE_TERM')
        require('value+=n*(maxf(0,hand-float(fx.get("reserve",0)))-4)+anticipated_strength' in source['policy_v8.gd'], 'INHERITED_REPLACEMENT')
        require('clampf(3.0+float(f.sight)*0.7+5.0*float(f.draw)/size,2,7)' in source['policy_v8.gd'], 'FORECAST_LAW')
        require('value+=float(fx.floor_per)*minf(q,float(fx.get("reserve",0)))' in source['greedy_stock.gd'], 'FLOOR_TERM')
        require('g.run.player.deck.clear()' in source['gate_delta.gd'] and '&"defend"' in source['gate_delta.gd'], 'FIXTURE_DECK')
    return manifest, {'native_terminal_unchanged':True, 'coherent_runtime_role':'legacy-query',
        'scope':'Original role label was not a real query mutant; its complete inherited controller already evaluates the selected law.',
        'source':{n:manifest['legacy-query'][n] for n in source},
        'fixture_forecast':3, 'original_projection_forecast':4,
        'weights_and_parameters_unchanged':True}


def basic(r, nonlinear):
    a,v,u,q,x,on=(r[k] for k in ('aspect','vow','up','q','context','active'))
    require(r['key']==f'{a}:{v}:{str(u).lower()}:{q}:{x}:{str(on).lower()}', 'KEY')
    require(type(u) is bool and type(on) is bool and type(q) is int, 'CASE_TYPES')
    require(r['readonly'] is True and r['catalogue_unchanged'] is True, 'QUERY_MUTATION')
    require(r['flags']==r['exact_flags']==r['public_flags']==[True,True,on], 'FLAGS')
    require(r['after']==r['exact_after'] and r['events']==r['exact_events'], 'EXACT_CLONE')
    require(r['return'] is (x!='no-energy'), 'LEGALITY')
    require(r['expected_raw']==raw(q,u,nonlinear,on), 'DECLARED_RAW')
    effect={'kind':'special','id':'phantom','n':((7 if u else 6) if nonlinear else (4 if u else 3)) if on else 0}
    if nonlinear: effect.update(reserve=4,floor_per=2 if on else 0)
    require(r['data']['effects']==[effect] and r['data']['cost']==1, 'RESOLVED_EFFECT')
    require(r['actual_raw']==r['expected_raw'], 'ACTUAL_RAW')
    require(r['after']==r['expanded_after'] and r['events']==r['expanded_events'], 'NATIVE_ENVELOPE')
    if r['expected_raw']>0: require(r['score']==r['expanded_score'], 'POSITIVE_RAW_SCORE')
    require(r['draft']==draft(r,nonlinear), 'FULL_INHERITED_DRAFT')
    # Preserve, and explain, the original mismatched q4 projection. Do not edit it.
    require(r['expanded_draft']==raw(4,u,nonlinear,on)-2, 'ORIGINAL_Q4_PROJECTION')


def check(capture, new_off=None):
    data={role:rows(capture/(role+'.jsonl.xz'),(True,) if role in ('reference','legacy-query') else (False,) if role=='legacy-mask' else (False,True)) for role in ROLES}
    for role in ('reference','linear','legacy-query'):
        for r in data[role].values(): basic(r,role=='legacy-query')
    for key,r in data['reference'].items(): require(r==data['linear'][key],'LINEAR_DEFAULT_PARITY')
    query_faults=mask_faults=0
    for key,r in data['candidate'].items():
        if r['active']:
            expected=12-4*(7 if r['up'] else 6)
            require(r['draft']==expected and r['draft']!=draft(r,True),'ACTUAL_BAD_QUERY_NOT_DETECTED')
            require(r['after']==r['expanded_after'] and r['events']==r['expanded_events'],'QUERY_MUTANT_ALTERS_GAME')
            query_faults+=1
    for r in data['legacy-mask'].values():
        if r['q']==4 and r['context']=='plain':
            require(r['actual_raw']==8 and r['expected_raw']==0 and r['after']!=r['expanded_after'],'OFF_MASK_MUTANT')
            mask_faults+=1
    require(query_faults==280 and mask_faults==8,'MUTANT_COVERAGE')
    qualified_off=0
    if new_off is not None:
        for r in rows(new_off,(False,)).values(): basic(r,True);qualified_off+=1
        require(qualified_off==280,'MISSING_OFF')
    return {'status':'COHERENT_HAND_QUERY_AND_OFF_MASK_QUALIFIED_NOT_CERTIFICATE' if new_off else 'SOURCE_BOUND_QUERY_REPAIR_PREFLIGHT',
        'original_terminal_retained':'INCONCLUSIVE: original q4 projection and named query mutant were wrong for the complete inherited dispatch',
        'old_records_read':sum(map(len,data.values())), 'reused_correct_candidate_on_cases':280,
        'new_correct_candidate_off_cases':qualified_off, 'default_on_reference_pairs':280,
        'existing_query_patch_faults_detected':query_faults, 'existing_off_mask_faults_detected':mask_faults,
        'query_weights_search_and_runtime_controller_changed':False,
        'original_q4_projection_values_unchanged':True,
        'limits':['Correction explicitly changes the false test oracle/role interpretation, not the old verdict or native game law.',
                  'Both sides of the coherent candidate are now bound to the unchanged legacy-query runtime; ON is reused and only missing OFF is observed.',
                  'The forecast3 assertion is fixture-scoped, not a claim that every deck should forecast3.',
                  'Raw-zero legacy score omission remains unqualified. Native default parity does not establish optimal play.',
                  'No population, signed controls, descriptor admission, peer/economy or independent confirmation added.'],
        'review_kind':'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT','new_population_outcomes':0,'new_independent_samples':0,'packages_admitted':0,'p9_certified':False}


def module(path):
    spec=importlib.util.spec_from_file_location('preserved_native_delivery',path)
    mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod);return mod


def run(repo,engine,out,work):
    require(not out.exists() and not work.exists(),'NO_RERUN');out.mkdir(parents=True);work.mkdir(parents=True)
    root=repo/BASE;original=root/'execution-1';m=module(root/'qualify.py')
    require(blob((root/'qualify.py').read_bytes())=='b9981f0a400c3c2741384404b8bdfd4ef26eed8d','DELIVERY_SOURCE')
    head=m.git(repo,'rev-parse','HEAD')
    terminal={'status':'INCONCLUSIVE','source_head':head,'new_population_outcomes':0,'packages_admitted':0,'p9_certified':False}
    try:
        require(sha(engine.read_bytes())==ENGINE,'ENGINE')
        manifest,source_proof=binding(original);save(out/'SOURCE-PROOF.json',source_proof)
        save(out/'PREFLIGHT.json',check(original))
        project=work/'coherent';project.mkdir()
        with tarfile.open(original/'runtime-source.tar.xz','r:xz') as tf:
            for rel,record in manifest['legacy-query'].items():
                p=Path(rel);require(not p.is_absolute() and '..' not in p.parts,'ARCHIVE_PATH')
                entry=tf.getmember('legacy-query/'+rel);require(entry.isfile(),'ARCHIVE_TYPE')
                data=tf.extractfile(entry).read();require(len(data)==record['bytes'] and sha(data)==record['sha256'],'RUNTIME_BYTES')
                dest=project/p;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(data)
        save(out/'RUNTIME-IDENTITY.json',{'parent_capture_manifest_sha256':sha((original/'FILES.json').read_bytes()),
            'runtime_members':manifest['legacy-query'],'unchanged_from_archived_role':'legacy-query',
            'gate_mode':'legacy-mask means only OFF case selection, not a different runtime implementation'})
        head=m.publish(repo,out,head,'research(p9): freeze coherent original query runtime before only missing OFF cases')
        m.command([str(engine),'--headless','--path',str(project),'--import'],project,out,'import')
        m.command([str(engine),'--headless','--path',str(project),'-s','res://gate_delta.gd','--','legacy-mask',str(out/'off.jsonl'),str(out/'off.traces.jsonl')],project,out,'off-native')
        result=check(original,out/'off.jsonl');save(out/'RESULTS.json',result);terminal.update(result)
    except Exception as exc:terminal['failure']=repr(exc)
    finally:
        for p in out.glob('*.jsonl'):
            p.with_suffix(p.suffix+'.xz').write_bytes(lzma.compress(p.read_bytes()));p.unlink()
        save(out/'TERMINAL.json',terminal)
        save(out/'FILES.json',[{'path':p.name,'bytes':p.stat().st_size,'sha256':sha(p.read_bytes())} for p in sorted(out.iterdir()) if p.is_file() and p.name!='FILES.json'])
        m.publish(repo,out,head,'research(p9): preserve coherent query correction and only missing OFF capture')
        print(json.dumps(terminal,indent=2))
    return 3 if terminal['status']=='INCONCLUSIVE' else 0


def verify(repo,original,cold,receipt):
    require(not receipt.exists(),'RECEIPT_EXISTS')
    require((original/'FILES.json').read_bytes()==(cold/'FILES.json').read_bytes(),'MANIFEST')
    records=load(original/'FILES.json')
    for r in records:
        p=Path(r['path']);require(not p.is_absolute() and '..' not in p.parts,'PATH')
        a=(original/p).read_bytes();b=(cold/p).read_bytes()
        require(a==b and len(b)==r['bytes'] and sha(b)==r['sha256'],'COLD_BYTES:'+str(p))
    t=load(cold/'TERMINAL.json');reproduced=False
    if t['status']!='INCONCLUSIVE':
        binding(repo/BASE/'execution-1')
        actual=check(repo/BASE/'execution-1',cold/'off.jsonl.xz')
        require(actual==load(cold/'RESULTS.json') and all(t[k]==v for k,v in actual.items()),'READOUT')
        reproduced=True
    save(receipt,{'kind':'COHERENT_HAND_QUERY_REPAIR_COLD_READBACK','files':len(records)+1,'all_bytes_equal':True,
        'readout_reproduced':reproduced,'scientific_status':t['status'],'old_capture_unchanged':True,
        'new_native_replays':0,'new_population_outcomes':0,'packages_admitted':0,'p9_certified':False})


if __name__=='__main__':
    action,*args=sys.argv[1:];paths=[Path(x).resolve() for x in args]
    if action=='run':raise SystemExit(run(*paths))
    elif action=='verify':verify(*paths)
    else:raise SystemExit('run REPO ENGINE OUTPUT WORK | verify COLD_REPO ORIGINAL COLD RECEIPT')
