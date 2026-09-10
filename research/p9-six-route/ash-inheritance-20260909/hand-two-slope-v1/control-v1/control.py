"""One exact isolated-Hand signed-arm2 screen, reusing the maintained reader.
No controller tuning, historical row reuse, package admission or product merge.
"""
from concurrent.futures import ThreadPoolExecutor
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

ROOT=Path('research/p9-six-route')
HAND=ROOT/'ash-inheritance-20260909/hand-two-slope-v1'
NATIVE=HAND/'native-v1'
SHARED=ROOT/'guardrail-confirmation-20260909'
HERE=Path(__file__).resolve().parent
BRANCH='research/p9-six-route-local-20260905'
ENGINE='8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e'
INPUTS={'read_control.py':'2515bcbb7d9dc998d81654882abaa9173cd66c82',
        'execute_control.py':'45ec7b22bd6c194256c5cfe18e7b8c99dac1d480'}


def require(ok,why):
    if not ok:raise ValueError(why)


def sha(b):return hashlib.sha256(b).hexdigest()
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def load(p):return json.loads(p.read_bytes())
def save(p,v):p.write_text(json.dumps(v,indent=2)+'\n')
def git(repo,*args):return subprocess.check_output(['git','-C',str(repo),*args]).decode().strip()


def publish(repo,out,head,message):
    require(git(repo,'rev-parse','HEAD')==head and git(repo,'ls-remote','origin','refs/heads/'+BRANCH).split()[0]==head,'WRITER_DRIFT')
    rel=str(out.relative_to(repo));git(repo,'add',rel)
    names=git(repo,'diff','--cached','--name-only').splitlines()
    require(names and all(x.startswith(rel+'/') for x in names),'STAGED_SCOPE')
    git(repo,'commit','-m',message);git(repo,'push','origin','HEAD:refs/heads/'+BRANCH)
    head=git(repo,'rev-parse','HEAD')
    if os.environ.get('GITHUB_ENV'):
        with open(os.environ['GITHUB_ENV'],'a') as f:f.write('PUBLISHED_HEAD='+head+'\n')
    return head


def dependencies(repo):
    for n,h in INPUTS.items():require(blob((repo/SHARED/n).read_bytes())==h,'SHARED_SOURCE:'+n)
    sys.path.insert(0,str(repo/SHARED));import execute_control,read_control
    return execute_control,read_control


def seed_check(repo,seed0,count):
    requested=set(range(seed0,seed0+count));require(not requested.intersection(range(5000,5200)),'PROTECTED_SEEDS')
    names=git(repo,'ls-files','research/p9-six-route/**/*.config.json').splitlines()
    require(names and all((repo/n).is_file() for n in names),'METADATA_CHECKOUT')
    def collision(x):
        if isinstance(x,dict):
            if type(x.get('seed0')) is int and type(x.get('runs')) is int:
                if any(x['seed0']<=s<x['seed0']+x['runs'] for s in requested):return True
            return any(collision(v) for v in x.values())
        if isinstance(x,list):return any(collision(v) for v in x)
        return type(x) is int and x in requested
    hits=[n for n in names if collision(load(repo/n))]
    require(not hits,'PREVIOUS_SEED_METADATA:'+','.join(hits))
    return {'checked_configurations':len(names),'requested_seed0':seed0,'count':count,'collisions':[],
            'scope':'Complete tracked config metadata, including seed0/runs ranges. Not a claim of universal independence.'}


def copy_archive_file(tf,role,rel,manifest):
    p=Path(rel);require(not p.is_absolute() and '..' not in p.parts,'ARCHIVE_PATH')
    item=tf.getmember(role+'/'+rel);require(item.isfile(),'ARCHIVE_TYPE')
    data=tf.extractfile(item).read();r=manifest[role][rel]
    require(len(data)==r['bytes'] and sha(data)==r['sha256'],'ARCHIVE_BYTES:'+rel)
    return data


def setup(repo,work,out,p):
    q=repo/NATIVE/'query-repair-1/execution-1'
    proof=load(q/'REMOTE-READBACK.json');t=load(q/'TERMINAL.json')
    require(proof['all_bytes_equal'] and proof['readout_reproduced'] and t['status']=='COHERENT_HAND_QUERY_AND_OFF_MASK_QUALIFIED_NOT_CERTIFICATE','QUERY_PREREQUISITE')
    save(out/'SEED-METADATA.json',seed_check(repo,p['seed0'],128))
    original=repo/NATIVE/'execution-1';entries={r['path']:r for r in load(original/'FILES.json')}
    for n in ('SOURCE-MANIFEST.json','runtime-source.tar.xz'):
        b=(original/n).read_bytes();r=entries[n]
        require(sha(b)==r['sha256'] and len(b)==r['bytes'],'NATIVE_SOURCE:'+n)
    manifest=load(original/'SOURCE-MANIFEST.json')
    with tarfile.open(original/'runtime-source.tar.xz','r:xz') as tf:
        selected={n:copy_archive_file(tf,'legacy-query',n,manifest)
                  for n in ('content/full-content.json','domain/rules/combat.gd')}
    source_content=json.loads((repo/'content/full-content.json').read_bytes())
    candidate=json.loads(selected['content/full-content.json'])
    require(list(source_content)==list(candidate) and list(source_content['cards'])==list(candidate['cards']),'CATALOGUE_ORDER')
    require(all(source_content[k]==candidate[k] for k in source_content if k!='cards'),'NONCARD_CONTENT_DELTA')
    changed={k for k in source_content['cards'] if source_content['cards'][k]!=candidate['cards'][k]}
    require(changed=={'bloodRite','leechBlade','phantomBlades'},'ONLY_SELECTED_CONTENT')
    require(candidate['cards']['phantomBlades']['rarity']==source_content['cards']['phantomBlades']['rarity'],'RARITY')
    template=load(repo/SHARED/'PROTOCOL.json')
    require(sha((repo/'content/full-content.json').read_bytes())==template['content_sha256']['baseline'],'EXACT_MAIN_CONTENT')
    require(sha((repo/'domain/rules/combat.gd').read_bytes())==template['combat_sha256']['baseline'],'EXACT_MAIN_COMBAT')
    resolved=json.loads(json.dumps(template));resolved.update(seed0=p['seed0'],seeds_per_grid=128,arm=2,
        scope='Single isolated Hand two-slope plus minimum Bloodfire versus exact current-main baseline. Signed shipping arm2 only; no planner nomination.')
    resolved['containment'].update(workers=2,invocation_seconds=120,raw_bytes_per_cell=67108864)
    resolved['source_parent_contract']=p
    projects={};manifests={}
    for cat in ('baseline','candidate'):
        project=work/cat;project.mkdir()
        for n in ('domain','content'):shutil.copytree(repo/n,project/n)
        if cat=='candidate':
            for rel,data in selected.items():(project/rel).write_bytes(data)
        (project/'tools').mkdir()
        for n,h in resolved['tool_sha256'].items():
            b=(repo/'tools'/n).read_bytes();require(sha(b)==h,'SHIPPING_TOOL:'+n);(project/'tools'/n).write_bytes(b)
        for n in ('balance_sweep.gd','check_scripts.sh'):shutil.copyfile(repo/'tools'/n,project/'tools'/n)
        shutil.copyfile(repo/SHARED/'probe.gd',project/'probe.gd')
        (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="P9 signed-control screen"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        for key,rel in (('content_sha256','content/full-content.json'),('combat_sha256','domain/rules/combat.gd')):
            resolved[key][cat]=sha((project/rel).read_bytes())
        domain={str(f.relative_to(project)):sha(f.read_bytes()) for f in sorted((project/'domain').rglob('*')) if f.is_file()}
        resolved['domain_manifest_sha256'][cat]=sha(json.dumps(domain,sort_keys=True,separators=(',',':')).encode())
        projects[cat]=project
        manifests[cat]={str(f.relative_to(project)):{'bytes':f.stat().st_size,'sha256':sha(f.read_bytes())} for f in sorted(project.rglob('*')) if f.is_file()}
    require({k for k in manifests['baseline'] if manifests['baseline'][k]!=manifests['candidate'][k]}==set(selected),'ONLY_TWO_RUNTIME_FILES')
    save(out/'RESOLVED-PROTOCOL.json',resolved);save(out/'RUNTIME-SOURCE-MANIFEST.json',manifests)
    with tarfile.open(out/'runtime-source.tar.xz','w:xz') as tf:
        for cat in projects:
            for rel in manifests[cat]:tf.add(projects[cat]/rel,arcname=cat+'/'+rel,recursive=False)
    return projects,resolved


def run(repo,engine,out,work):
    require(not out.exists() and not work.exists(),'NO_RERUN');out.mkdir(parents=True);work.mkdir()
    executor,reader=dependencies(repo);p=load(HERE/'PROTOCOL.json')
    head=git(repo,'rev-parse','HEAD');t={'status':'INCONCLUSIVE','source_head':head,'packages_admitted':0,'p9_certified':False}
    try:
        require(p['seed0']==73760100 and p['seeds_per_grid']==128 and p['arm']==2,'FIXED_ASSIGNMENT')
        require(sha(engine.read_bytes())==ENGINE,'ENGINE')
        projects,resolved=setup(repo,work,out,p)
        head=publish(repo,out,head,'research(p9): freeze exact isolated-Hand signed-control runtimes before outcomes')
        setup_dir=out/'setup';setup_dir.mkdir();headers=out/'headers';headers.mkdir();raw_dir=out/'raw';raw_dir.mkdir()
        for cat,project in projects.items():
            receipt=executor.command([str(engine),'--headless','--path',str(project),'--import'],setup_dir,cat+'-import',project,120)
            require(receipt['failure'] is None,'IMPORT:'+cat)
            cfg=dict(id=cat+'-header',catalogue=cat,aspect='ashwarden',vow=0,arm=2,seed0=p['seed0'],runs=0)
            require(executor.execute(cfg,project,engine,headers,resolved)['status']=='COMPLETE','SIGNED_ZERO_ROW_HEADER:'+cat)
        specs=sorted(reader.specifications(resolved),key=lambda c:(c['aspect'],c['vow'],c['catalogue']))
        receipts=[]
        for start in range(0,8,2):
            with ThreadPoolExecutor(max_workers=2) as pool:
                batch=list(pool.map(lambda c:executor.execute(c,projects[c['catalogue']],engine,raw_dir,resolved),specs[start:start+2]))
            receipts+=batch
            for cfg in specs[start:start+2]:
                path=raw_dir/(cfg['id']+'.ndjson')
                if path.exists():
                    b=path.read_bytes();packed=lzma.compress(b);require(lzma.decompress(packed)==b,'COMPRESSION')
                    path.with_suffix('.ndjson.xz').write_bytes(packed);path.unlink()
            save(out/'PROGRESS.json',{'completed_cells':sum(r['status']=='COMPLETE' for r in receipts),'assigned_cells':8,'receipts':receipts})
            head=publish(repo,out,head,'research(p9): preserve isolated-Hand matched signed-control cells')
            require(all(r['status']=='COMPLETE' for r in batch),'INCOMPLETE_NATIVE_CELL')
        result=reader.analyze(raw_dir,resolved);save(out/'RESULTS.json',result)
        t.update(status=result['status'],rows=result['rows'],decision=result['decision'])
    except Exception as exc:t['failure']=repr(exc)
    finally:
        save(out/'TERMINAL.json',t)
        save(out/'FILES.json',[{'path':str(f.relative_to(out)),'bytes':f.stat().st_size,'sha256':sha(f.read_bytes())} for f in sorted(out.rglob('*')) if f.is_file() and f.name!='FILES.json'])
        publish(repo,out,head,'research(p9): preserve exact isolated-Hand signed-control terminal')
        print(json.dumps(t,indent=2))
    return 3 if t['status']=='INCONCLUSIVE' else 0


def verify(repo,original,cold,receipt):
    require(not receipt.exists(),'RECEIPT_EXISTS');_,reader=dependencies(repo)
    require((original/'FILES.json').read_bytes()==(cold/'FILES.json').read_bytes(),'MANIFEST')
    records=load(original/'FILES.json')
    for r in records:
        p=Path(r['path']);require(not p.is_absolute() and '..' not in p.parts,'PATH')
        b=(cold/p).read_bytes();require(b==(original/p).read_bytes() and len(b)==r['bytes'] and sha(b)==r['sha256'],'COLD_BYTES:'+str(p))
    t=load(cold/'TERMINAL.json');reproduced=False
    if t['status']!='INCONCLUSIVE':
        actual=reader.analyze(cold/'raw',load(cold/'RESOLVED-PROTOCOL.json'))
        require(actual==load(cold/'RESULTS.json') and actual['status']==t['status'],'READOUT');reproduced=True
    save(receipt,{'kind':'ISOLATED_HAND_SIGNED_CONTROL_COLD_READBACK','files':len(records)+1,
         'all_bytes_equal':True,'readout_reproduced':reproduced,'scientific_status':t['status'],
         'new_native_replays':0,'packages_admitted':0,'p9_certified':False})


if __name__=='__main__':
    mode,*args=sys.argv[1:];p=[Path(x).resolve() for x in args]
    if mode=='run':raise SystemExit(run(*p))
    elif mode=='verify':verify(*p)
    else:raise SystemExit('run REPO ENGINE OUTPUT WORK | verify COLD_REPO ORIGINAL COLD RECEIPT')
