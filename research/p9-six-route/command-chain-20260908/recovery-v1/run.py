"""Run one already-bound finite command verifier in an assembled measurement project."""
import hashlib,json,os,shutil,subprocess,sys,time
from pathlib import Path
R=Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main(project,engine,out):
    p=json.loads((R/'PROTOCOL.json').read_text());sources=json.loads((R/'SOURCE-MANIFEST.json').read_text())
    for name,info in p['files'].items():
        assert sha(R/name)==info['sha256'],name
    assert sha(engine)==p['engine_sha256']
    assert subprocess.check_output([str(engine),'--version'],text=True).strip()==p['engine_version']
    for name,digest in sources.items():assert sha(project/name)==digest,name
    assert not out.exists(),'Never overwrite an execution attempt'
    out.mkdir(parents=True);shutil.copyfile(R/'probe.gd',project/'command_probe.gd')
    env={**os.environ,'GODOT_SILENCE_ROOT_WARNING':'1'}
    parse=[str(engine),'--headless','--path',str(project),'--check-only','-s','res://command_probe.gd']
    with (out/'parse.log').open('wb') as f:r=subprocess.run(parse,stdout=f,stderr=subprocess.STDOUT,timeout=30,env=env)
    assert r.returncode==0 and not any(x in (out/'parse.log').read_bytes() for x in (b'ERROR:',b'SCRIPT ERROR',b'Parse Error'))
    cmd=[str(engine),'--headless','--path',str(project),'-s','res://command_probe.gd','--',str(out/'native.ndjson')]
    start=time.monotonic();reason=None
    with (out/'stdout.log').open('wb') as stdout,(out/'stderr.log').open('wb') as stderr:
        process=subprocess.Popen(cmd,stdout=stdout,stderr=stderr,env=env)
        while process.poll() is None:
            if time.monotonic()-start>p['watchdog_seconds']:reason='WATCHDOG'
            if sum(f.stat().st_size for f in out.iterdir() if f.is_file())>p['trace_cap_bytes']:reason='TRACE_CAP'
            if any(x in (out/'stderr.log').read_bytes() for x in (b'ERROR:',b'SCRIPT ERROR',b'Parse Error')):reason='DIAGNOSTIC'
            if reason:process.kill();break
            time.sleep(.02)
        rc=process.wait()
    receipt={'returncode':rc,'stop_reason':reason,'elapsed_seconds':time.monotonic()-start,'command':cmd,'engine_sha256':sha(engine),'protocol_sha256':sha(R/'PROTOCOL.json'),'source_equal_after':all(sha(project/n)==h for n,h in sources.items()),'probe_equal_after':sha(project/'command_probe.gd')==p['files']['probe.gd']['sha256'],'files':{f.name:{'bytes':f.stat().st_size,'sha256':sha(f)} for f in out.iterdir() if f.is_file()}}
    (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt))
    assert rc==0 and reason is None and receipt['source_equal_after'] and receipt['probe_equal_after']
    assert not any(x in (out/'stderr.log').read_bytes() for x in (b'ERROR:',b'SCRIPT ERROR',b'Parse Error'))
if __name__=='__main__':
    assert len(sys.argv)==4,'run.py ASSEMBLED_PROJECT PINNED_ENGINE FRESH_OUTPUT'
    main(*(Path(x).resolve() for x in sys.argv[1:]))
