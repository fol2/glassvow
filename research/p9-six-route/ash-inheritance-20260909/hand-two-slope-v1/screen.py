"""Zero-population screen of the already-authored, isolated Hand payoff.
Not a new parameter search, native qualification, model fit or admission.
"""
from __future__ import annotations
import copy
import difflib
import hashlib
import json
from pathlib import Path
import re
import sys
import tarfile

BASE = Path('research/p9-six-route')
ASH = BASE/'ash-inheritance-20260909'
OLD = BASE/'source-package-audit-20260908'
COMBAT = '3ccb89f69f50e41d5a46eadd8f48c0a907fd0e382cd492b2c34dd5f93e091ad0'
CONTENT = '4107c7c0bbed5d9acf8c2bdf97023552426920242ea958c8ebdec793b712afd9'
HISTORICAL = {'candidate.patch':'11d406e3ab3856cf823284ca85face75f73b0876',
              'observer.patch':'e958fe0af8f602f0c8803455af5d9f40426d0cc7'}
PARAMETERS = {False:{'n':6,'reserve':4,'floor_per':2}, True:{'n':7,'reserve':4,'floor_per':2}}
HELPER = '''## Research-only isolated Hand law; missing fields recover native linear payoff.
func _hand_two_slope_raw(stock: int, fx: Dictionary) -> int:
\tvar q: int = maxi(0, stock)
\tvar reserve: int = maxi(0, _ji(fx.get("reserve", 0)))
\treturn _ji(fx["n"]) * maxi(0, q - reserve) + _ji(fx.get("floor_per", 0)) * mini(q, reserve)


'''


def require(ok, why):
    if not ok: raise ValueError(why)


def sha(data): return hashlib.sha256(data).hexdigest()
def blob(data): return hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
def load(p): return json.loads(p.read_bytes())
def save(p,v): p.write_text(json.dumps(v,indent=2)+'\n')


def law(q, fx):
    require(type(q) is int and q >= 0, 'STOCK_DOMAIN')
    require(all(type(v) is int for v in fx.values()), 'INTEGER_EFFECT')
    reserve=max(0,fx.get('reserve',0))
    return fx['n']*max(0,q-reserve)+fx.get('floor_per',0)*min(q,reserve)


def consumer_off(fx):
    result=copy.deepcopy(fx)
    result['n']=0
    if 'floor_per' in result:result['floor_per']=0
    return result


def build(content, combat):
    require(sha(content)==CONTENT and sha(combat)==COMBAT,'BASE_IDENTITIES')
    data=json.loads(content)
    require((json.dumps(data,ensure_ascii=False,indent=2)+'\n').encode()==content,'BASE_SERIALIZATION')
    changed=copy.deepcopy(data)
    card=changed['cards']['phantomBlades']
    require(card['rarity']=='rare' and card['cost']==1,'BASE_CARD')
    for upgraded in (False,True):
        resolved=card['up'] if upgraded else card
        fx=resolved['effects']
        require(fx==[{'kind':'special','id':'phantom','n':4 if upgraded else 3}],'NATIVE_EFFECT')
        fx[0].update(PARAMETERS[upgraded])
        resolved['text']=f'Deal @2@ damage per card in your hand up to 4, then @{PARAMETERS[upgraded]["n"]}@ per card above 4.'
    for k in data:
        if k!='cards':require(data[k]==changed[k],'UNRELATED_CONTENT')
    require(list(data)==list(changed) and list(data['cards'])==list(changed['cards']),'CATALOGUE_ORDER')
    require([k for k in data['cards'] if data['cards'][k]!=changed['cards'][k]]==['phantomBlades'],'ONE_CARD_ONLY')
    before=combat.decode()
    anchor='\t\t"phantom":\n\t\t\thit_enemy(run, cb, target, _ji(fx["n"]) * cb.hand.size(), true, damage_mult)'
    replacement='\t\t"phantom":\n\t\t\thit_enemy(run, cb, target, _hand_two_slope_raw(cb.hand.size(), fx), true, damage_mult)'
    require(before.count(anchor)==1 and before.count('func _apply_special(')==1,'DISPATCH_ANCHOR')
    after=before.replace(anchor,replacement,1).replace('func _apply_special(',HELPER+'func _apply_special(',1)
    require(after.replace(HELPER,'',1).replace(replacement,anchor,1)==before,'ONLY_HAND_RAW_DELTA')
    return (json.dumps(changed,ensure_ascii=False,indent=2)+'\n').encode(),after.encode()


def equations():
    rows=[]
    for up in (False,True):
        fx=PARAMETERS[up];native=4 if up else 3
        for q in range(10):
            y=law(q,fx);old_off=dict(fx,n=0)
            rows.append({'upgraded':up,'remaining_hand':q,'native_raw':native*q,
                         'isolated_raw':y,'difference':y-native*q,
                         'old_n_only_off_raw':law(q,old_off),'matched_all_hand_terms_off_raw':law(q,consumer_off(fx))})
    return rows


def run(repo,out):
    require(not out.exists(),'OUTPUT_EXISTS')
    inputs={}
    for name,want in HISTORICAL.items():
        data=(repo/OLD/name).read_bytes();require(blob(data)==want,'HISTORICAL_SOURCE:'+name)
        inputs[str(OLD/name)]={'bytes':len(data),'git_blob':want,'sha256':sha(data)}
    old=(repo/OLD/'candidate.patch').read_text()
    segment=old[old.index('     "phantomBlades": {'):old.index('     "devour": {')]
    tuples=re.findall(r'\+\s+"n": (\d+),\n\+\s+"reserve": (\d+),\n\+\s+"floor_per": (\d+)',segment)
    require(tuples==[('6','4','2'),('7','4','2')],'HISTORICAL_PARAMETERS')
    source=repo/ASH/'hand-adaptive-v1/execution-1'
    manifest=load(source/'SOURCE-MANIFEST.json')['qualified']
    index={r['path']:r for r in load(source/'FILES.json')}
    archive=source/'runtime-source.tar.xz';b=archive.read_bytes();record=index[archive.name]
    require(len(b)==record['bytes'] and sha(b)==record['sha256'],'ARCHIVE_BYTES')
    sources={}
    with tarfile.open(archive,'r:xz') as t:
        for name,r in manifest.items():
            require(not Path(name).is_absolute() and '..' not in Path(name).parts,'MEMBER_PATH')
            m=t.getmember('qualified/'+name);require(m.isfile(),'FILE_ONLY')
            data=t.extractfile(m).read();require(len(data)==r['bytes'] and sha(data)==r['sha256'],'MEMBER_BYTES')
            sources[name]=data
    # The qualified Hand seam wraps card_data; isolate on the ORIGINAL same-minimum
    # combat bytes stored alongside it in the archived uninstrumented reference.
    all_manifest=load(source/'SOURCE-MANIFEST.json')
    with tarfile.open(archive,'r:xz') as t:
        content=t.extractfile('reference/content/full-content.json').read()
        combat=t.extractfile('reference/domain/rules/combat.gd').read()
    for name,data in [('content/full-content.json',content),('domain/rules/combat.gd',combat)]:
        r=all_manifest['reference'][name];require(len(data)==r['bytes'] and sha(data)==r['sha256'],'REFERENCE_BYTES')
    candidate_content,candidate_combat=build(content,combat)
    linear_scorers=[]
    for name,data in sources.items():
        if name.endswith('.gd') and re.search(r'elif\s+sid\s*==\s*"phantom"\s*:\s*raw\s*\*=\s*maxi\(0,\s*g\.cb\.hand\.size\(\)-1\)',data.decode()):
            linear_scorers.append({'path':name,'sha256':sha(data)})
    require(linear_scorers,'EXPECTED_LEGACY_SCORING_NOT_FOUND')
    # Evidence of a mismatched intrinsic projection, not a performance estimate.
    rows=equations()
    require(any(r['old_n_only_off_raw']>0 for r in rows),'OLD_MASK_COUNTEREXAMPLE')
    require(all(r['matched_all_hand_terms_off_raw']==0 for r in rows),'MATCHED_OPERATOR')
    for n in (0,3,4,6,7):
        require(all(law(q,{'n':n})==n*q for q in range(1001)),'NATIVE_DEFAULT_IDENTITY')
    out.mkdir(parents=True)
    delta=[]
    for name,old_bytes,new_bytes in [('content/full-content.json',content,candidate_content),('domain/rules/combat.gd',combat,candidate_combat)]:
        target=out/'candidate'/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(new_bytes)
        delta.extend(difflib.unified_diff(old_bytes.decode().splitlines(True),new_bytes.decode().splitlines(True),fromfile='a/'+name,tofile='b/'+name))
    (out/'CANDIDATE.patch').write_text(''.join(delta))
    result={'status':'ISOLATED_HAND_DESIGN_CONSTRUCTED_CONTROLLER_AND_OPERATOR_QUALIFICATION_REQUIRED',
        'source_parameters_reused_not_fitted':PARAMETERS,'input_files':inputs,
        'base':{'content_sha256':sha(content),'combat_sha256':sha(combat)},
        'candidate':{'content_sha256':sha(candidate_content),'combat_sha256':sha(candidate_combat)},
        'scope':'One inherited Hand payoff isolation, NOT the failed broad candidate. Only Phantom effect fields/display text and its raw dispatch change. Native sources, rarity, pools, Core/Art, Bloodfire, IDs, save state and all other functions stay unchanged.',
        'equation_table':rows,'legacy_linear_scorers':linear_scorers,
        'decisions':{'old_coefficient_zero_mask_invalid':True,'new_all_terms_off_algebraic_null':True,
                     'native_linear_default_identity':True,'native_query_or_parser_qualified':False,
                     'unchanged_controller_compatible_with_new_payoff_claimed':False,'population_opened':False},
        'witness':'At q=4, n=0 with floor_per=2 still yields8 raw damage. The retained linear scorer at n=6,q=4 projects24 rather than8. A higher n is not by itself a controller-compatible nonlinear mechanic.',
        'next_action':'Repair only the effect-law readout/consumer mask and source-bind the affected public queries with exact native-default parity; no weights or search-budget retuning. Then a finite native delta/null/envelope gate is required BEFORE any new signed-control/value cohort. Keep the historical Hand/Bloodfire negatives immutable.',
        'limits':['Exact-source construction and algebra only; no new native execution or behavioral equivalence theorem.',
                  'The table covers native remaining-hand counts0..9; it is not a population distribution or HP/win forecast.',
                  'Inherited-family eligibility does not admit a new strategy or erase prior scoped failures.',
                  'No fixed validation model, reward ordering, statistical rule, controller result or protected cohort changes.'],
        'review_kind':'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT','new_native_runs':0,'packages_admitted':0,'p9_certified':False}
    save(out/'RESULTS.json',result)
    save(out/'FILES.json',[{'path':str(p.relative_to(out)),'bytes':p.stat().st_size,'sha256':sha(p.read_bytes())}
                           for p in sorted(out.rglob('*')) if p.is_file()])
    print(json.dumps({k:v for k,v in result.items() if k not in ('equation_table','input_files')},indent=2))

if __name__=='__main__':run(*(Path(x).resolve() for x in sys.argv[1:]))
