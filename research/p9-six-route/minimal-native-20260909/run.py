"""One bounded exact-source capture or offline verification. No adaptive input.

Hosted capture is an explicit byte-identical preservation replay of the local
fixed fixture capture, not independent evidence. No product/policy cohort runs.
"""
from __future__ import annotations
import hashlib,json,lzma,os,shutil,subprocess,sys,tempfile,time
from pathlib import Path
import prove_contract, verify
R=Path(__file__).resolve().parent
RAW='d8fe513d2cc8992e6168fb3ec4a64e970dd2b5ee82bd2e6c247a33df06bcfd2f'
DOMAIN='85c74ff18cdf73b7355dea340e535edbf01d6b38b53acdc0a251ec528d987b1e'

def save(p,value):p.write_text(json.dumps(value,indent=2)+'\n')
def h(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def must(ok,reason):
    if not ok:raise RuntimeError(reason)

def command(cmd,out,label,cwd,limit=120):
    start=time.monotonic()
    with (out/(label+'.stdout')).open('wb') as so,(out/(label+'.stderr')).open('wb') as se:
        p=subprocess.run(cmd,cwd=cwd,stdout=so,stderr=se,timeout=limit,env=dict(os.environ,GODOT_SILENCE_ROOT_WARNING='1'))
    must(p.returncode==0 and b'ERROR:' not in (out/(label+'.stderr')).read_bytes(),label+' failed')
    return {'command':cmd,'returncode':p.returncode,'seconds':time.monotonic()-start}

def offline(base,out):
    raw=out/'raw.ndjson.xz';data=lzma.decompress(raw.read_bytes());must(verify.sha(data)==RAW,'raw identity')
    result=verify.main(raw,R/'CONTRACT.json')
    proof=prove_contract.check_semantics(raw,R/'CONTRACT.json',base)
    must(result['status']=='MINIMAL_NATIVE_ROLE_CONTRACT_CHECKED_NOT_ADMITTED','fixed claim failure')
    return result,proof

def main(base,engine,out,mode='capture'):
    base,engine,out=map(lambda x:Path(x).resolve(),(base,engine,out))
    contract=json.loads((R/'CONTRACT.json').read_bytes())
    for name,digest in contract['source_sha256'].items():must(h(R/name)==digest,'source '+name)
    if mode=='verify':
        result,proof=offline(base,out)
        for n,v in [('RESULTS.json',result),('SOURCE-PROOF.json',proof)]:
            must((out/n).read_bytes()==(json.dumps(v,indent=2)+'\n').encode(),'readout bytes '+n)
        print('OFFLINE_FULL_RAW_AND_READOUT_MATCH',RAW);return
    must(not out.exists(),'capture directory already exists');out.mkdir(parents=True)
    must(h(engine)==contract['engine_sha256'],'engine bytes')
    terminal={'status':'INCONCLUSIVE','source_freeze':'c88f7c8b47e57b058e8c71fd9151488808b5b5a4','new_independent_samples':0,'packages_admitted':0,'p9_certified':False,'purpose':'Exact-byte replay to preserve the already observed local capture, count once, no new independent sample.'}
    try:
        with tempfile.TemporaryDirectory(prefix='p9-native-role-') as t:
            project=Path(t)/'project';project.mkdir()
            for d in ('domain','content'):shutil.copytree(base/d,project/d)
            manifest={str(p.relative_to(project)):h(p) for p in sorted((project/'domain').rglob('*')) if p.is_file()}
            must(verify.sha(json.dumps(manifest,sort_keys=True,separators=(',',':')).encode())==DOMAIN,'domain identity')
            (project/'tools').mkdir()
            for name in ('vow_incentives.gd','check_scripts.sh'):shutil.copyfile(base/'tools'/name,project/'tools'/name)
            for name in ('probe.gd','roles.gd'):shutil.copyfile(R/name,project/name)
            (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="P9 minimal native role contract"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
            calls=[command([str(engine),'--headless','--path',str(project),'--import'],out,'import',project)]
            env=dict(os.environ,GODOT=str(engine),GODOT_SILENCE_ROOT_WARNING='1')
            p=subprocess.run(['bash','tools/check_scripts.sh','roles.gd','probe.gd'],cwd=project,env=env,capture_output=True,timeout=120)
            (out/'parse.stdout').write_bytes(p.stdout);(out/'parse.stderr').write_bytes(p.stderr)
            must(p.returncode==0,'parse failed')
            path=out/'raw.ndjson';cmd=[str(engine),'--headless','--path',str(project),'-s','res://probe.gd','--',str(R/'CONTRACT.json'),str(path)]
            start=time.monotonic()
            with (out/'native.stdout').open('wb') as so,(out/'native.stderr').open('wb') as se:
                p=subprocess.Popen(cmd,stdout=so,stderr=se,env=env)
                try:
                    while p.poll() is None:
                        must(time.monotonic()-start<120,'native watchdog')
                        must(not path.exists() or path.stat().st_size<=134217728,'raw bound')
                        time.sleep(.1)
                finally:
                    if p.poll() is None:p.kill();p.wait()
            must(p.returncode==0 and b'ERROR:' not in (out/'native.stderr').read_bytes(),'native failure')
            raw=path.read_bytes();must(verify.sha(raw)==RAW,'preservation replay differs')
            (out/'raw.ndjson.xz').write_bytes(lzma.compress(raw,preset=6));path.unlink()
            result,proof=offline(base,out)
            save(out/'RESULTS.json',result);save(out/'SOURCE-PROOF.json',proof)
            terminal.update(status=result['status'],counts=result['counts'],raw_bytes=len(raw),raw_sha256=RAW,source_domain_sha256=DOMAIN,command=cmd,returncode=0,seconds=time.monotonic()-start,source_dependencies=proof['source']['source_dependencies'])
    except Exception as exc:
        terminal['failure']=repr(exc)
        path=out/'raw.ndjson'
        if path.exists():(out/'raw.ndjson.xz').write_bytes(lzma.compress(path.read_bytes()));path.unlink()
    terminal['files']={p.name:{'bytes':p.stat().st_size,'sha256':h(p)} for p in out.iterdir() if p.is_file()}
    save(out/'TERMINAL.json',terminal)
    print(json.dumps({k:v for k,v in terminal.items() if k not in ('files','source_dependencies','command')},sort_keys=True))
    must(terminal['status']!='INCONCLUSIVE',terminal.get('failure','inconclusive'))

if __name__=='__main__':main(*sys.argv[1:])
