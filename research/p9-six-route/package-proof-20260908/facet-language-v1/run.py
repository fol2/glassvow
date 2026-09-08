"""Single bounded native invocation; captures every available byte on failure."""
import hashlib,importlib.util,json,lzma,os,signal,subprocess,sys,time
from pathlib import Path
from prepare import prepare
from verify import verify,sha

def main(repo,engine,output):
    study=Path(__file__).resolve().parent
    if output.exists():raise ValueError('FRESH_OUTPUT_REQUIRED')
    output.mkdir(parents=True)
    protocol=json.loads((study/'PROTOCOL.json').read_text())
    if sha(engine.read_bytes())!=protocol['engine_sha256']:raise ValueError('ENGINE_IDENTITY')
    for name,digest in protocol['source_files'].items():
        if sha((study/name).read_bytes())!=digest:raise ValueError('STUDY_IDENTITY:'+name)
    project=output/'project'; manifest=prepare(repo,project,study)
    old=repo/'research/p9-six-route/command-chain-20260908/recovery-v1'
    sys.path.insert(0,str(old));import complete
    prior=complete.reconstruct(old)
    if sha(prior)!=protocol['old_raw_sha256']:raise ValueError('OLD_RAW_IDENTITY')
    initials={}
    for r in map(json.loads,prior.splitlines()):
        if r['kind']=='row':
            s=r['fixture']
            if s['role']=='facet' and s['aspect']==0 and not s['control']:
                k=(s['vow'],s['up']);initials[k]=r['initial']
    if len(initials)!=4:raise ValueError('OLD_INITIALS')
    (output/'OLD-INITIALS.json').write_text(json.dumps([dict(vow=v,up=u,initial=h) for (v,u),h in sorted(initials.items())],indent=2)+'\n')
    env={k:v for k,v in os.environ.items() if k in ('PATH','HOME','LANG','LC_ALL','TMPDIR')}
    env['GODOT_SILENCE_ROOT_WARNING']='1'
    for name,args in [('import',['--editor','--import']),('parse',['--script','res://facet_language.gd','--check-only'])]:
        with (output/(name+'.stdout')).open('wb') as out,(output/(name+'.stderr')).open('wb') as err:
            done=subprocess.run([str(engine),'--headless','--path',str(project)]+args,stdout=out,stderr=err,env=env,timeout=90)
        data=(output/(name+'.stdout')).read_bytes()+(output/(name+'.stderr')).read_bytes()
        if done.returncode or any(x in data for x in (b'SCRIPT ERROR',b'Parse Error',b'ERROR:')):raise ValueError('MECHANICAL_PREFLIGHT:'+name)
    raw=output/'native.ndjson';started=time.monotonic();error=None
    with (output/'native.stdout').open('wb') as stdout,(output/'native.stderr').open('wb') as stderr:
        proc=subprocess.Popen([str(engine),'--headless','--path',str(project),'--script','res://facet_language.gd','--',str(raw)],stdout=stdout,stderr=stderr,env=env,start_new_session=True)
        while proc.poll() is None:
            data=(output/'native.stderr').read_bytes()
            if any(x in data for x in (b'SCRIPT ERROR',b'Parse Error',b'ERROR:',b'Assertion failed')):error='NATIVE_DIAGNOSTIC'
            if time.monotonic()-started>protocol['watchdog_seconds']:error='WATCHDOG'
            if raw.exists() and raw.stat().st_size>protocol['raw_cap_bytes']:error='TRACE_CAP'
            if error:os.killpg(proc.pid,signal.SIGKILL);break
            time.sleep(.05)
        rc=proc.wait()
    elapsed=time.monotonic()-started
    post={str(p.relative_to(project)):sha(p.read_bytes()) for p in project.rglob('*') if p.is_file() and '.godot' not in p.parts and p.suffix!='.uid'}
    if post!=manifest:error='POST_SOURCE_IDENTITY'
    if rc and error is None:error='NATIVE_RETURN'
    result=None
    if error is None:
        try:
            result=verify([json.loads(x) for x in raw.read_bytes().splitlines()],initials,sha((study/'search.gd').read_bytes()))
            (output/'RESULTS.json').write_text(json.dumps(result,indent=2)+'\n')
        except Exception as exc:
            error='READER:'+type(exc).__name__+':'+str(exc)
    files={}
    for p in sorted(output.iterdir()):
        if not p.is_file():continue
        b=p.read_bytes();files[p.name]=dict(bytes=len(b),sha256=sha(b))
    receipt=dict(protocol_sha256=sha((study/'PROTOCOL.json').read_bytes()),engine_sha256=protocol['engine_sha256'],returncode=rc,error=error,elapsed_seconds=elapsed,files=files,post_source_equal=post==manifest,new_native_invocations=1,new_independent_samples=0,p9_certified=False)
    (output/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    if raw.exists():
        b=raw.read_bytes();packed=lzma.compress(b,preset=9)
        if lzma.decompress(packed)!=b:raise ValueError('RAW_ROUNDTRIP')
        (output/'native.ndjson.xz').write_bytes(packed)
    print(json.dumps(dict(receipt=receipt,result=result)))
    return 0 if error is None else 3
if __name__=='__main__':
    sys.exit(main(Path(sys.argv[1]).resolve(),Path(sys.argv[2]).resolve(),Path(sys.argv[3]).resolve()))
