"""Frozen inherited-Ash support + direct consumer interventions in one capture.
No adaptive policies, scalar tuning, protected cohort, or legacy outcome carry.
"""
from concurrent.futures import ThreadPoolExecutor
import importlib.util
import hashlib
import io
import json
import lzma
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import time
import read_pair as reader

HERE=Path(__file__).resolve().parent
ROOT=Path('research/p9-six-route')
SCREEN=ROOT/'ash-inheritance-20260909/minimal-v1/screen-v1'
BRANCH='research/p9-six-route-local-20260905'
require,sha=reader.require,reader.sha


def save(path,obj):Path(path).write_text(json.dumps(obj,indent=2)+'\n')

def git(repo,*args):return subprocess.check_output(['git','-C',str(repo),*args],timeout=90).decode().strip()

def publish(repo,out,expected,message):
    require(git(repo,'ls-remote','origin','refs/heads/'+BRANCH).split()[0]==expected,'CONCURRENT_WRITER')
    rel=str(out.relative_to(repo));subprocess.run(['git','add','-f',rel],cwd=repo,check=True)
    staged=git(repo,'diff','--cached','--name-only').splitlines()
    require(staged and all(p.startswith(rel+'/') for p in staged),'STAGED_SCOPE')
    subprocess.run(['git','commit','-m',message],cwd=repo,check=True)
    subprocess.run(['git','push','origin','HEAD:refs/heads/'+BRANCH],cwd=repo,check=True,timeout=90)
    return git(repo,'rev-parse','HEAD')


def command(argv,logs,label,seconds=120,cwd=None):
    start=time.monotonic();error=None;code=None
    try:
        with (logs/(label+'.stdout')).open('wb') as a,(logs/(label+'.stderr')).open('wb') as b:
            result=subprocess.run(argv,cwd=cwd,stdout=a,stderr=b,timeout=seconds,
                    env=dict(os.environ,GODOT_SILENCE_ROOT_WARNING='1'))
        code=result.returncode
    except subprocess.TimeoutExpired:error='INVOCATION_WATCHDOG'
    diagnostic=(logs/(label+'.stderr')).read_bytes()
    if code!=0 or b'ERROR:' in diagnostic or b'Failed to load script' in diagnostic:error=error or 'PROCESS_OR_SCRIPT_DIAGNOSTIC'
    receipt={'argv':argv,'returncode':code,'error':error,'seconds':time.monotonic()-start}
    save(logs/(label+'.command.json'),receipt)
    require(error is None,error)


def prepare(repo,work,out,p):
    manifest_path=repo/SCREEN/'execution-1/FILES.json';data=manifest_path.read_bytes()
    require(hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()==p['screen_files_git_blob'],'SCREEN_MANIFEST')
    old_files={r['path']:r for r in json.loads(data)}
    source=repo/SCREEN/'execution-1/runtime-source.tar.xz';data=source.read_bytes()
    require(sha(data)==old_files['runtime-source.tar.xz']['sha256'],'RUNTIME_ARCHIVE')
    old_manifest=(repo/SCREEN/'execution-1/RUNTIME-SOURCE-MANIFEST.json').read_bytes()
    require(sha(old_manifest)==old_files['RUNTIME-SOURCE-MANIFEST.json']['sha256'],'RUNTIME_MANIFEST')
    expected=json.loads(old_manifest)['candidate'];project=work/'candidate';project.mkdir()
    with tarfile.open(fileobj=io.BytesIO(data),mode='r:xz') as tf:
        members=[m for m in tf.getmembers() if m.name.startswith('candidate/')]
        require(len(members)==len(expected) and len({m.name for m in members})==len(expected),'RUNTIME_COVERAGE')
        for m in members:
            rel=m.name[len('candidate/'):];r=expected[rel]
            require(m.isfile() and not Path(rel).is_absolute() and '..' not in Path(rel).parts,'ARCHIVE_PATH')
            b=tf.extractfile(m).read();require(sha(b)==r['sha256'] and len(b)==r['bytes'],'RUNTIME_BYTES:'+rel)
            target=project/rel;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(b)
    stock=(project/'tools/balance_sim.gd').read_text()
    old='var game: GlassvowGame = GlassvowGame.new(content, run)'
    require(stock.count(old)==1 and stock.count('class_name BalanceSim\n')==1,'OBSERVER_FACTORY')
    observed=stock.replace('class_name BalanceSim\n','',1).replace(old,'var game: GlassvowGame = preload("res://observed_game.gd").new(content, run)',1)
    (project/'tools/observed_sim.gd').write_text(observed)
    for name in ('observed_game.gd','probe.gd','qualify.gd'):shutil.copyfile(HERE/name,project/name)
    source_names=['balance_sim.gd','observed_sim.gd','balance_pilot.gd','balance_policy.gd','balance_metrics.gd','vow_incentives.gd']
    p['runtime']={'sources':{n:sha((project/'tools'/n).read_bytes()) for n in source_names},
                  'content_sha256':expected['content/full-content.json']['sha256'],
                  'combat_sha256':expected['domain/rules/combat.gd']['sha256'],
                  'observer_sha256':sha((project/'observed_game.gd').read_bytes()),
                  'probe_sha256':sha((project/'probe.gd').read_bytes())}
    save(out/'RESOLVED-PROTOCOL.json',p)
    save(out/'SOURCE-MANIFEST.json',{str(f.relative_to(project)):{'sha256':sha(f.read_bytes()),'bytes':f.stat().st_size} for f in sorted(project.rglob('*')) if f.is_file()})
    with tarfile.open(out/'runtime-source.tar.xz','w:xz') as tf:
        for f in sorted(project.rglob('*')):
            if f.is_file():tf.add(f,arcname=str(f.relative_to(project)),recursive=False)
    return project


def compress(path,p):
    require(path.stat().st_size<=p['raw_bytes_per_stream'],'RAW_CAP')
    b=path.read_bytes();packed=lzma.compress(b,preset=6)
    require(lzma.decompress(packed)==b,'COMPRESSION_IDENTITY')
    out=path.with_suffix(path.suffix+'.xz');out.write_bytes(packed);path.unlink()
    return {'name':out.name,'raw_bytes':len(b),'raw_sha256':sha(b),'packed_sha256':sha(packed)}


def cell(cfg,project,engine,out,p):
    stem=f"v{cfg['vow']}-{cfg['first']:03d}"
    config=out/(stem+'.config.json');save(config,cfg)
    outcomes=out/(stem+'.outcomes.jsonl');traces=out/(stem+'.traces.jsonl')
    receipt={'status':'INCONCLUSIVE','cfg':cfg}
    try:
        command([str(engine),'--headless','--path',str(project),'-s','res://probe.gd','--',str(config),str(outcomes),str(traces)],out,stem)
        rows=reader.outcome_records(outcomes,cfg,p)
        reader.trace_summary(traces,{r['row_key'] for r in rows})
        receipt.update(status='COMPLETE',rows=len(rows))
    except Exception as exc:receipt['failure']=repr(exc)
    receipt['raw']=[]
    for file in (outcomes,traces):
        if file.exists():receipt['raw'].append(compress(file,p))
    save(out/(stem+'.RECEIPT.json'),receipt)
    return receipt


def execute(repo,engine,out,work,publish_enabled):
    repo,engine,out,work=map(lambda x:Path(x).resolve(),(repo,engine,out,work))
    require(not out.exists() and not work.exists(),'OUTPUT_EXISTS_NO_AUTORERUN')
    out.mkdir(parents=True);work.mkdir()
    head=git(repo,'rev-parse','HEAD');initial=head
    terminal={'status':'INCONCLUSIVE','source_head':head,'stages':{},'new_independent_package_confirmation':False,'packages_admitted':0,'p9_certified':False}
    try:
        p=json.loads((HERE/'PROTOCOL.json').read_bytes())
        for name,want in p['source_sha256'].items():require(sha((HERE/name).read_bytes())==want,'SOURCE:'+name)
        require(sha(engine.read_bytes())==p['engine_sha256'],'ENGINE')
        pre=json.loads((repo/SCREEN/'readback-1/REMOTE-READBACK.json').read_bytes())
        require(pre['scientific_status']=='SIGNED_CONTROL_NECESSARY_SCREEN_PASS_NOT_P9' and pre['readout_reproduced_byte_for_byte'],'PREREQUISITE')
        project=prepare(repo,work,out,p)
        if publish_enabled:head=publish(repo,out,head,'research(p9): freeze inherited pair exact runtime before observations')
        q=out/'qualification';q.mkdir()
        command([sys.executable,'-m','unittest','-v','test_pair'],q,'tests',cwd=HERE)
        command([str(engine),'--headless','--path',str(project),'--import'],q,'import')
        command(['env','GODOT='+str(engine),'bash','tools/check_scripts.sh','observed_game.gd','probe.gd','qualify.gd','tools/observed_sim.gd'],q,'parse',cwd=project)
        raw=q/'clones.jsonl'
        command([str(engine),'--headless','--path',str(project),'-s','res://qualify.gd','--',str(raw)],q,'clone-qualification')
        reader.trace_summary(raw,{f'qualify:{i}' for i in range(16)},qualification=True)
        compress(raw,p)
        for vow in (5,0):
            cfg={'root':p['policy_root'],'first':0,'count':2,'seeds':[p['qualification_seed']],'vow':vow,'integration':True}
            r=cell(cfg,project,engine,q,p);require(r['status']=='COMPLETE','OBSERVATIONAL_PARITY_QUALIFICATION')
        save(q/'RESULTS.json',{'status':'CLONE_AND_OBSERVER_QUALIFIED','constructed_states':16,'full_run_observer_stock_pairs':4,'package_admission':False})
        if publish_enabled:head=publish(repo,out,head,'research(p9): preserve new clone and observer qualification before support rows')
        for vow in (5,0):
            target=out/f'v{vow}';target.mkdir()
            specs=[{'root':p['policy_root'],'first':i,'count':p['policies_per_cell'],'seeds':p['seeds'],'vow':vow,'integration':False} for i in range(0,p['policies'],p['policies_per_cell'])]
            for offset in range(0,len(specs),2):
                with ThreadPoolExecutor(max_workers=2) as pool:
                    receipts=list(pool.map(lambda cfg:cell(cfg,project,engine,target,p),specs[offset:offset+2]))
                if publish_enabled:head=publish(repo,out,head,f'research(p9): preserve assigned Ash pair v{vow} chunk {offset//2+1}')
                require(all(r['status']=='COMPLETE' for r in receipts),'INCOMPLETE_FIXED_STAGE')
            result=reader.analyze(target,p,vow);save(target/'RESULTS.json',result)
            terminal['stages'][str(vow)]={k:v for k,v in result.items() if k not in ('row_results','policy_ids')}
            if not result['pass']:
                terminal.update(status='INHERITED_ASH_PAIR_SUPPORT_FAIL_IN_FIXED_POLICY_FAMILY',last_vow=vow)
                if vow==5:terminal['v0_skipped']=True
                break
            if publish_enabled:head=publish(repo,out,head,f'research(p9): preserve complete Ash pair v{vow} support decision')
        else:terminal['status']='INHERITED_ASH_PAIR_SUPPORT_PASS_NOT_CERTIFICATE'
    except Exception as exc:terminal['failure']=repr(exc)
    finally:
        # Partial captures remain; never call an exception a scientific zero.
        save(out/'TERMINAL.json',terminal)
        save(out/'FILES.json',[{'path':str(f.relative_to(out)),'bytes':f.stat().st_size,'sha256':sha(f.read_bytes())} for f in sorted(out.rglob('*')) if f.is_file()])
        if publish_enabled:head=publish(repo,out,head,'research(p9): preserve honest terminal of fixed inherited Ash pair')
        if os.environ.get('GITHUB_ENV'):
            with open(os.environ['GITHUB_ENV'],'a') as env:env.write('PUBLISHED_HEAD='+head+'\n')
        print(json.dumps({'published_head':head,'terminal':terminal},sort_keys=True))
    return 3 if terminal['status']=='INCONCLUSIVE' else 0


def verify(source,cold,out):
    source,cold,out=map(Path,(source,cold,out))
    require(not out.exists(),'READBACK_EXISTS')
    entries=json.loads((source/'FILES.json').read_bytes())
    for r in entries:
        rel=Path(r['path']);require(not rel.is_absolute() and '..' not in rel.parts,'MANIFEST_PATH')
        a=(source/rel).read_bytes();b=(cold/rel).read_bytes()
        require(a==b and len(b)==r['bytes'] and sha(b)==r['sha256'],'READBACK_BYTES:'+str(rel))
    require((source/'FILES.json').read_bytes()==(cold/'FILES.json').read_bytes(),'MANIFEST_READBACK')
    terminal=json.loads((cold/'TERMINAL.json').read_bytes());p=json.loads((cold/'RESOLVED-PROTOCOL.json').read_bytes())
    for v in terminal['stages']:
        result=reader.analyze(cold/f'v{v}',p,int(v))
        rendered=(json.dumps(result,indent=2)+'\n').encode()
        require(rendered==(cold/f'v{v}'/'RESULTS.json').read_bytes(),'RESULT_BYTE_RECONSTRUCTION')
    save(out,{'kind':'INHERITED_PAIR_FULL_COLD_READBACK','files':len(entries)+1,'all_bytes_equal':True,
              'reproduced_stages':list(terminal['stages']),'scientific_status':terminal['status'],
              'new_native_runs':0,'packages_admitted':0,'p9_certified':False})

if __name__=='__main__':
    if sys.argv[1]=='run':raise SystemExit(execute(*sys.argv[2:6],publish_enabled='--publish' in sys.argv))
    elif sys.argv[1]=='verify':verify(*sys.argv[2:])
    else:raise SystemExit('MODE')
