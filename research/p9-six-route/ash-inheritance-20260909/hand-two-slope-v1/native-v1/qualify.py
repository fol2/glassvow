"""Fixed source-bound Hand law delta; retains every actual output and failure."""
from __future__ import annotations
import hashlib
import importlib.util
import json
import lzma
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import time

ROOT=Path('research/p9-six-route')
HERE=ROOT/'ash-inheritance-20260909/hand-two-slope-v1'
HAND=ROOT/'ash-inheritance-20260909/hand-adaptive-v1'
ROLES=('reference','linear','candidate','legacy-mask','legacy-query')
ENGINE='8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e'


def require(ok,why):
    if not ok:raise ValueError(why)


def sha(b):return hashlib.sha256(b).hexdigest()
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def load(p):return json.loads(p.read_bytes())
def save(p,v):p.write_text(json.dumps(v,indent=2)+'\n')
def once(s,a,b):
    require(s.count(a)==1,'SOURCE_ANCHOR:'+a[:55]);return s.replace(a,b,1)


def repair_query(text):
    original=text
    text=once(text,'elif sid=="phantom":raw*=maxi(0,g.cb.hand.size()-1)',
              'elif sid=="phantom":raw=g.rules._hand_two_slope_raw(maxi(0,g.cb.hand.size()-1),fx)')
    text=once(text,'"phantom":n*4.0',
              '"phantom":float(g.rules._hand_two_slope_raw(4,fx)) if fx.has("reserve") else n*4.0')
    require(text!=original,'NO_QUERY_REPAIR')
    return text


def repair_mask(text):
    return once(text,'\t\t\teffect["n"] = 0\n',
                '\t\t\teffect["n"] = 0\n\t\t\tif effect.has("floor_per"):\n\t\t\t\teffect["floor_per"] = 0\n')


def setup(repo,work,out):
    spec=importlib.util.spec_from_file_location('existing_isolation',repo/HERE/'screen.py')
    mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
    require(blob((repo/HERE/'screen.py').read_bytes())=='9ba0296cfd6e54586ffd78b66c2543fba60cb5e0','ISOLATION_SOURCE')
    evidence=repo/HERE/'execution-1';r=load(evidence/'RESULTS.json')
    require(load(evidence/'REMOTE-READBACK.json')['full_design_reproduced'] is True,'ISOLATION_READBACK')
    source=repo/HAND/'execution-1';manifest=load(source/'SOURCE-MANIFEST.json')
    index={r['path']:r for r in load(source/'FILES.json')}
    b=(source/'runtime-source.tar.xz').read_bytes();record=index['runtime-source.tar.xz']
    require(len(b)==record['bytes'] and sha(b)==record['sha256'],'ARCHIVE_IDENTITY')
    projects={}
    with tarfile.open(source/'runtime-source.tar.xz','r:xz') as archive:
        for role in ROLES:
            inherited='reference' if role=='reference' else 'qualified'
            target=work/role;target.mkdir();projects[role]=target
            for rel,record in manifest[inherited].items():
                p=Path(rel);require(not p.is_absolute() and '..' not in p.parts,'ARCHIVE_PATH')
                member=archive.getmember(inherited+'/'+rel);require(member.isfile(),'REGULAR_FILE')
                b=archive.extractfile(member).read()
                require(len(b)==record['bytes'] and sha(b)==record['sha256'],'MEMBER_IDENTITY:'+rel)
                q=target/p;q.parent.mkdir(parents=True,exist_ok=True);q.write_bytes(b)
            if role!='reference':
                c=target/'domain/rules/combat.gd';original=c.read_text()
                text=once(original,'func _apply_special(',mod.HELPER+'func _apply_special(')
                a='\t\t"phantom":\n\t\t\thit_enemy(run, cb, target, _ji(fx["n"]) * cb.hand.size(), true, damage_mult)'
                z='\t\t"phantom":\n\t\t\thit_enemy(run, cb, target, _hand_two_slope_raw(cb.hand.size(), fx), true, damage_mult)'
                text=once(text,a,z)
                if role!='legacy-mask':text=repair_mask(text)
                c.write_text(text)
                if role!='legacy-query':
                    p=target/'legacy_policy.gd';p.write_text(repair_query(p.read_text()))
                if role!='linear':
                    b=(evidence/'candidate/content/full-content.json').read_bytes()
                    require(sha(b)==r['candidate']['content_sha256'],'CANDIDATE_CONTENT')
                    (target/'content/full-content.json').write_bytes(b)
                allowed={'domain/rules/combat.gd'}
                if role!='legacy-query':allowed.add('legacy_policy.gd')
                if role!='linear':allowed.add('content/full-content.json')
                changed={rel for rel,record in manifest[inherited].items() if sha((target/rel).read_bytes())!=record['sha256']}
                require(changed==allowed,'EXACT_ROLE_DELTA:'+role)
            shutil.copyfile(repo/HERE/'native-v1/gate.gd',target/'gate_delta.gd')
    identities={role:{str(p.relative_to(project)):{'bytes':p.stat().st_size,'sha256':sha(p.read_bytes())}
                      for p in sorted(project.rglob('*')) if p.is_file()} for role,project in projects.items()}
    save(out/'SOURCE-MANIFEST.json',identities)
    with tarfile.open(out/'runtime-source.tar.xz','w:xz') as tf:
        for role,project in projects.items():
            for rel in identities[role]:tf.add(project/rel,arcname=role+'/'+rel,recursive=False)
    return projects


def git(repo,*args):
    return subprocess.check_output(['git','-C',str(repo),*args]).decode().strip()


def publish(repo,out,expected,message):
    branch='research/p9-six-route-local-20260905'
    require(git(repo,'rev-parse','HEAD')==expected,'LOCAL_WRITER_DRIFT')
    require(git(repo,'ls-remote','origin','refs/heads/'+branch).split()[0]==expected,'CONCURRENT_WRITER')
    rel=str(out.relative_to(repo));git(repo,'add','--sparse',rel)
    names=git(repo,'diff','--cached','--name-only').splitlines()
    require(names and all(n.startswith(rel+'/') for n in names),'STAGED_SCOPE')
    git(repo,'config','user.name','github-actions[bot]')
    git(repo,'config','user.email','41898282+github-actions[bot]@users.noreply.github.com')
    git(repo,'commit','-m',message);git(repo,'push','origin','HEAD:refs/heads/'+branch)
    head=git(repo,'rev-parse','HEAD')
    require(git(repo,'ls-remote','origin','refs/heads/'+branch).split()[0]==head,'PUSH_REF')
    if os.environ.get('GITHUB_ENV'):
        with open(os.environ['GITHUB_ENV'],'a') as f:f.write('PUBLISHED_HEAD='+head+'\n')
    return head


def command(argv,cwd,out,label):
    started=time.monotonic()
    with (out/(label+'.stdout')).open('wb') as a,(out/(label+'.stderr')).open('wb') as b:
        try:
            p=subprocess.run(argv,cwd=cwd,stdout=a,stderr=b,timeout=240,check=False);code=p.returncode
        except subprocess.TimeoutExpired:code=-999
    save(out/(label+'.receipt.json'),{'argv':argv,'returncode':code,'seconds':time.monotonic()-started})
    text=(out/(label+'.stderr')).read_text(errors='replace')
    require(code==0 and not any(x in text for x in ('SCRIPT ERROR:','Parse Error:','ERROR:')),'NATIVE_COMMAND:'+label)


def rows(path):
    compressed=path.with_suffix(path.suffix+'.xz')
    raw=lzma.decompress(compressed.read_bytes()) if compressed.exists() else path.read_bytes()
    return [json.loads(line) for line in raw.splitlines() if line]


def check(out,protocol):
    expected={}
    for role in ROLES:
        wanted=set()
        for a in (0,1):
            for v in (0,5):
                for u in (False,True):
                    for q in (0,4,5,6,9):
                        for x in protocol['cases']['contexts']:
                            for on in protocol['cases']['active'][role]:
                                wanted.add(f'{a}:{v}:{str(u).lower()}:{q}:{x}:{str(on).lower()}')
        data=rows(out/(role+'.jsonl'));tail=data.pop()
        require(tail=={'kind':'terminal','cases':protocol['expected_cases'][role]},'TERMINAL_COVERAGE')
        indexed={r['key']:r for r in data}
        require(len(indexed)==len(data)==len(wanted) and set(indexed)==wanted,'ASSIGNED_CASES:'+role)
        expected[role]=indexed
    mask_detected=query_detected=0
    for role,data in expected.items():
        for key,r in data.items():
            flags=[True,True,r['active']]
            require(r['readonly'] and r['catalogue_unchanged'],'READONLY')
            require(r['flags']==r['exact_flags']==r['public_flags']==flags,'CLONE_FLAGS')
            require(r['after']==r['exact_after'] and r['events']==r['exact_events'],'EXACT_CLONE')
            require(r['return'] is (r['context']!='no-energy'),'LEGAL_ELIGIBILITY')
            q=r['q'];up=r['up'];on=r['active']
            require(type(q) is int and type(up) is bool and type(on) is bool,'CASE_TYPES')
            require(key==f"{r['aspect']}:{r['vow']}:{str(up).lower()}:{q}:{r['context']}:{str(on).lower()}",'CASE_KEY')
            nonlinear=role not in ('reference','linear')
            coefficient=(7 if up else 6) if nonlinear else (4 if up else 3)
            planned=(coefficient*max(0,q-4)+2*min(q,4)) if nonlinear else coefficient*q
            if not on:planned=0
            require(r['expected_raw']==planned,'SOURCE_LAW_ORACLE')
            effect={'kind':'special','id':'phantom','n':coefficient if on else 0}
            if nonlinear:effect.update(reserve=4,floor_per=2 if on or role=='legacy-mask' else 0)
            require(r['data']['effects']==[effect],'RESOLVED_EFFECT_VIEW')
            observed=effect['n']*max(0,q-effect.get('reserve',0))+effect.get('floor_per',0)*min(q,effect.get('reserve',0))
            require(r['actual_raw']==observed,'ACTUAL_RAW_ORACLE')
            good_raw=r['actual_raw']==r['expected_raw']
            good_native=r['after']==r['expanded_after'] and r['events']==r['expanded_events']
            good_score=r['expected_raw']==0 or r['score']==r['expanded_score']
            good_draft=r['draft']==r['expanded_draft']
            if role not in ('legacy-mask','legacy-query'):
                require(good_raw and good_native,'NATIVE_ENVELOPE:'+role+':'+key)
                require(good_score and good_draft,'QUERY_PROJECTION:'+role+':'+key)
            if r['q']==4 and r['context']=='plain':
                if role=='legacy-mask':
                    require(not good_raw and not good_native,'MASK_MUTANT_NOT_DETECTED');mask_detected+=1
                if role=='legacy-query':
                    require(good_raw and good_native and not good_score and not good_draft,'QUERY_MUTANT_NOT_DETECTED');query_detected+=1
    for key,r in expected['reference'].items():
        require(r==expected['linear'][key],'DEFAULT_ON_FULL_ROW_PARITY:'+key)
    require(mask_detected==query_detected==8,'NAMED_MUTANT_COVERAGE')
    return {'status':'ISOLATED_HAND_LAW_AND_INTRINSIC_QUERIES_QUALIFIED_NOT_CERTIFICATE',
            'cases':{k:len(v) for k,v in expected.items()},'default_on_full_reference_rows':280,
            'native_damage_expansion_comparisons':1120,'complete_planner_decision_pairs':8,
            'mask_mutants_detected':mask_detected,'query_mutants_detected':query_detected,
            'source_and_rarity_pools_unchanged':True,'controller_weights_and_search_parameters_changed':False,
            'raw_zero_score_not_repaired_or_promoted':True,
            'limits':['Constructed source-bound law/clone/query/envelope proof, not independent oracle or package admission.',
                      'No population, signed-control, descriptor predictive, peer/economy or independent confirmation evidence is added.',
                      'The old incomplete intrinsic formula is detected, not evidence that a revised controller wins more games.'],
            'new_population_outcomes':0,'new_independent_samples':0,'packages_admitted':0,'p9_certified':False,
            'review_kind':'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT'}


def run(repo,engine,out,work):
    require(not out.exists() and not work.exists(),'NO_RERUN');out.mkdir(parents=True);work.mkdir(parents=True)
    source=repo/HERE/'native-v1';protocol=load(source/'PROTOCOL.json')
    head=git(repo,'rev-parse','HEAD')
    freeze=load(source/'FREEZE.json')
    terminal={'status':'INCONCLUSIVE','source_head':freeze['source_head'],'packages_admitted':0,'p9_certified':False}
    try:
        for name,digest in freeze['source_sha256'].items():require(sha((source/name).read_bytes())==digest,'FROZEN_SOURCE')
        require(sha(engine.read_bytes())==ENGINE,'ENGINE_IDENTITY')
        projects=setup(repo,work,out)
        head=publish(repo,out,head,'research(p9): freeze exact isolated Hand law delta runtimes before native observations')
        command([str(engine),'--version'],work,out,'engine')
        for role,project in projects.items():
            command([str(engine),'--headless','--path',str(project),'--import'],project,out,role+'-import')
            command(['env','GODOT='+str(engine),'bash','tools/check_scripts.sh','domain/rules/combat.gd','legacy_policy.gd','gate_delta.gd'],project,out,role+'-parse')
            command([str(engine),'--headless','--path',str(project),'-s','res://gate_delta.gd','--',role,str(out/(role+'.jsonl')),str(out/(role+'.traces.jsonl'))],project,out,role+'-native')
        result=check(out,protocol);save(out/'RESULTS.json',result);terminal.update(result)
    except Exception as e:terminal['failure']=repr(e)
    finally:
        for p in out.glob('*.jsonl'):
            p.with_suffix(p.suffix+'.xz').write_bytes(lzma.compress(p.read_bytes()));p.unlink()
        save(out/'TERMINAL.json',terminal)
        save(out/'FILES.json',[{'path':str(p.relative_to(out)),'bytes':p.stat().st_size,'sha256':sha(p.read_bytes())}
                              for p in sorted(out.rglob('*')) if p.is_file()])
        head=publish(repo,out,head,'research(p9): preserve complete isolated Hand native delta and actual terminal')
    print(json.dumps(terminal,indent=2))
    return 0 if terminal['status']!='INCONCLUSIVE' else 3

if __name__=='__main__':
    if sys.argv[1]=='run':raise SystemExit(run(*(Path(x).resolve() for x in sys.argv[2:])))
    elif sys.argv[1]=='read':print(json.dumps(check(Path(sys.argv[2]),load(Path(sys.argv[3]))),indent=2))
