"""Bounded deterministic runner, with per-chunk durable publication and byte fetch.

Only the coordinating thread writes Git; workers own distinct capture directories.
The fixed support decision is not a package/P9 certificate. No outcome retuning.
"""
from __future__ import annotations
from concurrent.futures import ThreadPoolExecutor
import hashlib,json,lzma,os,shutil,subprocess,sys,tempfile,time
from pathlib import Path
from cohort import configurations,policies,identity,ENGINE,CONTENT
from read_support import read_cell,summarize
R=Path(__file__).resolve().parent
BRANCH='research/p9-six-route-local-20260905'

def require(ok,why):
    if not ok:raise RuntimeError(why)
def sha(b):return hashlib.sha256(b).hexdigest()
def dump(o):return (json.dumps(o,indent=2)+'\n').encode()
def save(p,o):p.write_bytes(dump(o))

def publication(root:Path,message:str,push:bool):
    if not push:return None
    repo=Path.cwd().resolve();relative=root.relative_to(repo)
    head=subprocess.check_output(['git','rev-parse','HEAD']).decode().strip()
    require(subprocess.check_output(['git','ls-remote','origin','refs/heads/'+BRANCH]).decode().split()[0]==head,'CONCURRENT_WRITER')
    subprocess.run(['git','add',str(relative)],check=True)
    staged=subprocess.check_output(['git','diff','--cached','--name-only']).decode().splitlines()
    require(staged and all(p.startswith(str(relative)+'/') for p in staged),'PUBLICATION_SCOPE')
    subprocess.run(['git','-c','user.name=github-actions[bot]','-c','user.email=41898282+github-actions[bot]@users.noreply.github.com','commit','-m',message],check=True,stdout=subprocess.DEVNULL)
    subprocess.run(['git','push','origin','HEAD:refs/heads/'+BRANCH],check=True,stdout=subprocess.DEVNULL)
    published=subprocess.check_output(['git','rev-parse','HEAD']).decode().strip()
    # New empty repository: fetch exact commit from remote, not local object reuse.
    with tempfile.TemporaryDirectory(prefix='p9-cold-') as tmp:
        cold=Path(tmp)
        subprocess.run(['git','init','-q',str(cold)],check=True)
        url=subprocess.check_output(['git','remote','get-url','origin']).decode().strip()
        subprocess.run(['git','-C',str(cold),'remote','add','origin',url],check=True)
        # Reuse already-approved checkout auth without exposing credentials in logs/argv.
        env=os.environ.copy();auth=[]
        for key in subprocess.check_output(['git','config','--name-only','--get-regexp','^http\\..*\\.extraheader$']).decode().splitlines():
            auth.append((key,subprocess.check_output(['git','config','--get',key]).decode().strip()))
        env['GIT_CONFIG_COUNT']=str(len(auth))
        for i,(key,value) in enumerate(auth):env['GIT_CONFIG_KEY_'+str(i)]=key;env['GIT_CONFIG_VALUE_'+str(i)]=value
        subprocess.run(['git','-C',str(cold),'fetch','-q','--depth=1','--filter=blob:none','origin',published],check=True,env=env)
        matched=[]
        listing=subprocess.check_output(['git','ls-tree','-r','-z',published,'--']+staged)
        for line in listing.split(b'\0'):
            if not line:continue
            meta,path=line.split(b'\t');kind=meta.split()[1];blob=meta.split()[2].decode();name=path.decode()
            require(kind==b'blob','NON_BLOB_EVIDENCE')
            data=subprocess.check_output(['git','-C',str(cold),'show','FETCH_HEAD:'+name],env=env)
            require(data==Path(name).read_bytes(),'REMOTE_BYTE_MISMATCH:'+name)
            require(hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()==blob,'REMOTE_BLOB_IDENTITY')
            matched.append({'path':name,'bytes':len(data),'sha256':sha(data),'git_blob':blob})
    receipt={'published_head':published,'files_matched':len(matched),'files':matched,'new_native_runs':0,'p9_certified':False}
    print('CHUNK_READBACK='+json.dumps({k:v for k,v in receipt.items() if k!='files'},sort_keys=True),flush=True)
    return receipt

def execute(cfg,project,engine,out):
    out.mkdir();save(out/'CONFIG.json',cfg)
    paths=[out/'endpoints.ndjson',out/'trace.ndjson']
    cmd=[str(engine),'--headless','--path',str(project),'-s','res://support_runner.gd','--',str(out/'CONFIG.json'),*map(str,paths)]
    start=time.monotonic();rc=None;failure=None
    env=dict(os.environ,GODOT_SILENCE_ROOT_WARNING='1')
    try:
        with (out/'stdout.log').open('wb') as stdout,(out/'stderr.log').open('wb') as stderr:
            p=subprocess.Popen(cmd,stdout=stdout,stderr=stderr,env=env)
            try:
                while p.poll() is None:
                    require(time.monotonic()-start<120,'INVOCATION_WATCHDOG')
                    require(sum(x.stat().st_size for x in paths if x.exists())<=536870912,'RAW_SIZE_CONTAINMENT')
                    time.sleep(.2)
                rc=p.returncode
            finally:
                if p.poll() is None:p.kill();p.wait()
        require(rc==0,'NATIVE_RETURN')
        error=(out/'stderr.log').read_bytes()
        require(b'SCRIPT ERROR:' not in error and b'Failed to load script' not in error and b'ERROR:' not in error,'NATIVE_DIAGNOSTIC')
        cell=read_cell(*paths,cfg);save(out/'CELL.json',cell)
    except Exception as exc:failure=repr(exc)
    raw={}
    for p in paths:
        if p.exists():
            h=hashlib.sha256();n=0
            with p.open('rb') as src,lzma.open(str(p)+'.xz','wb',preset=3) as target:
                for b in iter(lambda:src.read(1048576),b''):h.update(b);n+=len(b);target.write(b)
            raw[p.name]={'bytes':n,'sha256':h.hexdigest()};p.unlink()
    receipt={'config_id':cfg['id'],'source_head':os.environ.get('GITHUB_SHA','LOCAL_INTEGRATION_ONLY'),
      'command':cmd,'returncode':rc,'seconds':time.monotonic()-start,'status':'COMPLETE' if failure is None else 'INCONCLUSIVE_CAPTURE','failure':failure,'raw':raw,
      'files':{p.name:{'bytes':p.stat().st_size,'sha256':sha(p.read_bytes())} for p in out.iterdir() if p.is_file()},'p9_certified':False}
    save(out/'EXECUTION.json',receipt)
    return receipt

def smoke_check(folder):
    compared=[]
    for v in (0,5):
        for i in (0,1):
            pair=[]
            for obs in (False,True):
                p=folder/f'p{i:03}-v{v}-o{int(obs)}'/'endpoints.ndjson.xz'
                data=[json.loads(x) for x in lzma.decompress(p.read_bytes()).splitlines()]
                require(len(data)==2,'SMOKE_ROWS')
                r=data[1].copy();r.pop('hand_counters');r.pop('policy_id');r.pop('policy_parameters');pair.append(r)
            require(pair[0]==pair[1],'OBSERVER_ALTERS_EXISTING_CONTROLLER')
            compared.append({'policy_index':i,'vow':v,'seed':58080010,'full_endpoint_equal':True})
    return {'status':'SUPPORT_INTEGRATION_IDENTITY_PASS','pairs':compared,'new_population_samples':0,'p9_certified':False}

def main(base,engine,output,push=False,smoke_only=False):
    require(not output.exists(),'OUTPUT_ALREADY_EXISTS')
    output.mkdir(parents=True)
    protocol=json.loads((R/'PROTOCOL.json').read_bytes())
    require(sha(engine.read_bytes())==ENGINE,'ENGINE_IDENTITY')
    require(identity(policies())==protocol['policy_manifest_sha256'],'FIXED_POLICY_BINDING')
    for name,digest in protocol['source_sha256'].items():require(sha((R/name).read_bytes())==digest,'SOURCE_IDENTITY:'+name)
    hand=R.parent if (R.parent/'hand_rules.gd').exists() else base.parent/'hand-admission'
    require(sha((hand/'hand_rules.gd').read_bytes())==protocol['hand_rules_sha256'],'HAND_RULES_IDENTITY')
    readbacks=[];terminal={'status':'INCONCLUSIVE','p9_certified':False,'packages_admitted':0}
    with tempfile.TemporaryDirectory(prefix='p9-support-') as tmp:
        project=Path(tmp)/'project'
        try:
            subprocess.run([sys.executable,str(R/'assemble_support.py'),str(base),str(hand),str(project)],check=True,timeout=120)
            require(sha((project/'content/full-content.json').read_bytes())==CONTENT,'CONTENT_IDENTITY')
            env=dict(os.environ,GODOT=str(engine),GODOT_SILENCE_ROOT_WARNING='1')
            for name,cmd in [('import',[str(engine),'--headless','--path',str(project),'--import']),('parse',['bash','tools/check_scripts.sh','hand_rules.gd','hand_game.gd','support_runner.gd'])]:
                p=subprocess.run(cmd,cwd=project,capture_output=True,timeout=120,env=env)
                (output/(name+'.stdout')).write_bytes(p.stdout);(output/(name+'.stderr')).write_bytes(p.stderr)
                require(p.returncode==0 and b'SCRIPT ERROR:' not in p.stderr and b'ERROR:' not in p.stderr,'PREEXECUTION:'+name)
            smoke=output/'integration';smoke.mkdir()
            configs=configurations(0,True)+configurations(5,True)
            with ThreadPoolExecutor(max_workers=2) as ex:
                receipts=list(ex.map(lambda c:execute(c,project,engine,smoke/c['id']),configs))
            require(all(r['status']=='COMPLETE' for r in receipts),'INTEGRATION_CAPTURE_FAILURE')
            save(smoke/'RESULTS.json',smoke_check(smoke))
            rb=publication(output,'research(p9): preserve full Hand support integration identity',push)
            if rb:readbacks.append(rb)
            if smoke_only:terminal.update(status='INTEGRATION_ONLY_COMPLETE')
            else:
                for vow in (5,0):
                    stage=output/f'v{vow}';stage.mkdir();cells=[];configs=configurations(vow)
                    for start in range(0,128,8):
                        with ThreadPoolExecutor(max_workers=2) as ex:
                            receipts=list(ex.map(lambda c:execute(c,project,engine,stage/c['id']),configs[start:start+8]))
                        complete=all(r['status']=='COMPLETE' for r in receipts)
                        if complete:cells.extend(json.loads((stage/c['id']/'CELL.json').read_bytes()) for c in configs[start:start+8])
                        save(stage/'PROGRESS.json',{'closed_policies':len(cells),'complete_chunk':complete,'whole_stage_decision':'NOT_EVALUATED_UNTIL_COMPLETE','p9_certified':False})
                        rb=publication(output,f'research(p9): preserve V{vow} support chunk {start//8+1:02} without interim selection',push)
                        if rb:readbacks.append(rb)
                        require(complete,'INCOMPLETE_FIXED_STAGE')
                    result=summarize(cells);save(stage/'RESULTS.json',result)
                    terminal.update(status=result['status'],last_completed_vow=vow)
                    rb=publication(output,f'research(p9): preserve complete fixed V{vow} Hand support decision',push)
                    if rb:readbacks.append(rb)
                    if result['status']!='HAND_NATURAL_SUPPORT_GATE_PASS_NOT_PACKAGE_ADMISSION':break
        except Exception as exc:terminal.update(status='INCONCLUSIVE',failure=repr(exc))
        terminal['readbacks']=readbacks;save(output/'TERMINAL.json',terminal)
        publication(output,'research(p9): preserve Hand support terminal and chunk readbacks',push)
    print('SUPPORT_TERMINAL='+json.dumps({k:v for k,v in terminal.items() if k!='readbacks'},sort_keys=True),flush=True)
    return 0 if terminal['status']!='INCONCLUSIVE' else 3

if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser();p.add_argument('base',type=Path);p.add_argument('engine',type=Path);p.add_argument('output',type=Path);p.add_argument('--push',action='store_true');p.add_argument('--smoke-only',action='store_true');a=p.parse_args()
    raise SystemExit(main(a.base.resolve(),a.engine.resolve(),a.output.resolve(),a.push,a.smoke_only))
