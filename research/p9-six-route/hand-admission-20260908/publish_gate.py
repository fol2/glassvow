"""Publish an exact deterministic replay of the local preflight, never a new sample.

The local container cannot reach GitHub directly. A seven-second native replay
with exact raw equality is cheaper than model-transcribing 100 KB of compressed
binary. Any mismatch remains FAILED and retains available diagnostics.
"""
from __future__ import annotations
import hashlib
import json
import lzma
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

ROOT=Path(__file__).resolve().parent
REPO=Path.cwd().resolve()
RAW_SHA='46f1e8720060a925306cb07eb376cd40972b95114ba53e1377ad750cb38df267'
RESULT_SHA='d100b5bd56773543c0d6fe98a0d0a493f5ca5733a324d5c05a3d3d543e8e9082'
REVIEW_SHA='bea08d7332b5b03c295b04e09da13b3bd6c32f5a91d9942d56cd044b43d43d89'
SOURCES={
 'hand_rules.gd':'273492adb05cbc718a16491f03def85e646980acdc338ebe7d7db4643a1c107e',
 'preflight.gd':'aee2a470039c4d6e36f8aa6a54957c13f4af6043aa1a4cb7cced98fb0aca5d23',
 'read_preflight.py':'96994d7ae25ba0b46a59aaefcb2fe8c291e43ed3630ea9d72645726ce5167c15',
 'review_preflight.py':'0372253a690f7bd76adf9417c80789e7f5cc98c59ed6a5ecd4424d163f4b3902',
 'test_preflight.py':'404e552de1f32b92ed337b188e61f43360c2c9ce7e6e0e504ed6b962828b63f7'}

def sha(data):return hashlib.sha256(data).hexdigest()
def require(ok,why):
    if not ok:raise RuntimeError(why)
def encoded(value):return (json.dumps(value,indent=2)+'\n').encode()

def main(engine):
    output=ROOT/'native-1'
    require(not output.exists(),'TERMINAL_ALREADY_RECORDED')
    output.mkdir()
    receipt={'status':'FAILED','freeze_head':'f751ba1ced6cad40dfe157c65e499d2527a5356c',
             'source_head':os.environ['GITHUB_SHA'],'workflow_run':os.environ['GITHUB_RUN_ID'],
             'native_runs':0,'new_independent_samples':0,'packages_admitted':0,'p9_certified':False,
             'purpose':'Exact-byte replay/publication of local 1032-row preflight, not additional scientific replication.',
             'commands':[],'source_files':{}}
    def run(name,cmd,cwd,timeout=120,env=None):
        start=time.monotonic();p=subprocess.run(cmd,cwd=cwd,capture_output=True,timeout=timeout,env=env)
        (output/(name+'.stdout')).write_bytes(p.stdout);(output/(name+'.stderr')).write_bytes(p.stderr)
        receipt['commands'].append({'name':name,'command':list(map(str,cmd)),'returncode':p.returncode,'seconds':time.monotonic()-start})
        require(p.returncode==0,'PROCESS:'+name)
        require(b'SCRIPT ERROR:' not in p.stderr and b'Failed to load script' not in p.stderr,'DIAGNOSTIC:'+name)
        return p.stdout
    try:
        protocol=json.loads((ROOT/'PROTOCOL.json').read_bytes())
        require(sha(engine.read_bytes())==protocol['engine_sha256'],'ENGINE_BYTES')
        for name,digest in SOURCES.items():
            data=(ROOT/name).read_bytes();require(sha(data)==digest,'SOURCE:'+name)
            path=str((ROOT/name).relative_to(REPO))
            blob=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
            require(subprocess.check_output(['git','rev-parse','HEAD:'+path]).decode().strip()==blob,'INDEX:'+name)
            receipt['source_files'][name]={'sha256':digest,'git_blob':blob,'bytes':len(data)}
        with tempfile.TemporaryDirectory(prefix='p9-hand-publish-') as tmp:
            candidate=Path(tmp)/'candidate'
            run('assembly',[sys.executable,str(REPO/'research/p9-six-route/source-package-audit-20260908/assemble.py'),str(REPO),str(candidate)],REPO)
            deps={
              'causal_probe.gd':('research/p9-six-route/natural-contribution-20260907/causal_probe.gd','c6aa9a9075b11e2e35015fe379088caa8f4ea61ce4b271164aea8160ab4bdc7e'),
              'diagnostic_rules.gd':('research/p9-six-route/natural-contribution-20260907/diagnostic_rules.gd','c168a2d6741284db419429537b83dcfae20832029644b3fd67944bf709104144'),
              'health_accounting.gd':('research/p9-six-route/v16/recovery/health_accounting.gd','61168bfeb608dcb0f417a69356b0a147ff8fca5e70a924cd9bdbc521bc497d5f')}
            for name,(path,digest) in deps.items():
                data=(REPO/path).read_bytes();require(sha(data)==digest,'DEPENDENCY:'+name)
                (candidate/name).write_bytes(data)
            for name in ('hand_rules.gd','preflight.gd'):shutil.copyfile(ROOT/name,candidate/name)
            shutil.copyfile(REPO/'tools/check_scripts.sh',candidate/'tools/check_scripts.sh')
            env=dict(os.environ,GODOT=str(engine),GODOT_SILENCE_ROOT_WARNING='1')
            version=run('version',[str(engine),'--version'],candidate,env=env)
            require(version.strip()==b'4.7.2.stable.official.ed1daf0bf','ENGINE_VERSION')
            run('import',[str(engine),'--headless','--import'],candidate,env=env)
            run('parse',['bash','tools/check_scripts.sh','hand_rules.gd','preflight.gd'],candidate,env=env)
            receipt['native_runs']=1
            run('native',[str(engine),'--headless','--path','.', '-s','res://preflight.gd','--',str(output/'raw.ndjson')],candidate,timeout=120,env=env)
        raw=(output/'raw.ndjson').read_bytes()
        require(len(raw)==8768376 and sha(raw)==RAW_SHA,'LOCAL_REMOTE_RAW_MISMATCH')
        for name,script,digest in [('RESULTS.json','read_preflight.py',RESULT_SHA),('REVIEW.json','review_preflight.py',REVIEW_SHA)]:
            data=run(name,[sys.executable,str(ROOT/script),str(output/'raw.ndjson'),str(ROOT/'PROTOCOL.json')],REPO)
            require(sha(data)==digest,'LOCAL_REMOTE_READOUT:'+name)
            (output/name).write_bytes(data)
        run('tests',[sys.executable,'-m','unittest','-v','test_preflight'],ROOT,env=dict(os.environ,HAND_CAPTURE=str(output)))
        require(b'Ran 18 tests' in (output/'tests.stderr').read_bytes(),'TEST_COVERAGE')
        receipt.update(status='HAND_PREFLIGHT_PASS_WITH_EXACT_LOCAL_REMOTE_BYTES',tests_passed=18,raw_bytes=len(raw),raw_sha256=sha(raw),engine_sha256=protocol['engine_sha256'])
    except Exception as exc:
        receipt['failure']=repr(exc)
    finally:
        if (output/'raw.ndjson').exists():
            raw=(output/'raw.ndjson').read_bytes()
            (output/'raw.ndjson.xz').write_bytes(lzma.compress(raw))
            (output/'raw.ndjson').unlink()
        receipt['files']={p.name:{'bytes':p.stat().st_size,'sha256':sha(p.read_bytes())} for p in output.iterdir() if p.is_file()}
        (output/'EXECUTION.json').write_bytes(encoded(receipt))
        print('HAND_PUBLICATION='+json.dumps(receipt,sort_keys=True))
    return 0 if receipt['status']=='HAND_PREFLIGHT_PASS_WITH_EXACT_LOCAL_REMOTE_BYTES' else 3

if __name__=='__main__':
    raise SystemExit(main(Path(sys.argv[1]).resolve()))
