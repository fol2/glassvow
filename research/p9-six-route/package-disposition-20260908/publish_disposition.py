"""Cold-reproduce this owned source audit and compare separately fetched bytes.

No game, new sample, original panel rerun, model fit or package admission.
"""
import argparse,hashlib,json,os,subprocess,sys,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
blob=lambda b:hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
SOURCES={'census.py':'fc6a90f1d6270ba24d7c888070dcdfbc00a9460afb9c65b52a3c1050d7001071','read_packet.py':'a303699de752b78ea7bb80667890484c13c36bf8094a6fd715dd0f26562a211a','test_census.py':'b4a17a75f405a30d3ac23bbf6d840dca18f6e3d24422f45b72b51a95755ae634','disposition.py':'f15beff085e3f19383bcdcc74d59c752ac0eef7ea0269de4f3e4bb13e0a2f27e','hand_contract.py':'3920ae8f137d1b1005822d2d86a1c90dc9dda1bc1cd7c685f35d54e71841ae43','HAND-PRIMARY.json':'eef548b4e6aa936bd746379db3155b1f77e7b0e30c773baaedf0e9b5e6435633','test_disposition.py':'35b46fc7cce109824d97cec49975298d8f30b8ed49b47b30ed5b9dfa7400f363'}
OUTPUTS={'HAND-READOUT.json':'5c491d7f13e566773bfce4fb976fe5dd721873c292381ed3ef35d99f716175b9','DISPOSITION.json':'78143d9fd05cf05b383441f3cf38783af0120cb5720a192e68b66f55399fe3c6','ROADMAP.md':'61481c8631062ef8412c2e56b8d659bd1f5fdd614e6d8979523849cbdd330696'}

def require(ok,message):
    if not ok:raise RuntimeError(message)

def git_files(repo,scope):
    result=[]
    for row in subprocess.check_output(['git','-C',str(repo),'ls-tree','-r','-z','HEAD','--',str(scope)]).split(b'\0'):
        if not row:continue
        meta,path=row.split(b'\t');mode,kind,expected=meta.decode().split();p=Path(path.decode());b=(repo/p).read_bytes()
        require(kind=='blob' and blob(b)==expected,'GIT_BYTES:'+str(p))
        result.append({'path':str(p),'bytes':len(b),'sha256':sha(b),'git_blob':expected})
    return result

def run(repo):
    for name,digest in SOURCES.items():require(sha((ROOT/name).read_bytes())==digest,'SOURCE:'+name)
    observed=git_files(repo,ROOT.relative_to(repo))
    for version,want in [(1,'9526a5f3280b2e7ac02ba96f68620c00d30ae1cf'),(2,'38b3a5b7d1ca7e308cb308edf037f9462d1bf73c')]:
        p=repo/f'historical/research/issue-421/protocols/post-v38-hand-size-inventory-v{version}.json'
        require(blob(p.read_bytes())==want,'HISTORICAL_HAND_CONTRACT')
    import census,read_packet,hand_contract,disposition
    primary=read_packet.unpack(ROOT)
    old_readout=census.dump(census.read(primary))
    require(sha(old_readout)=='02b704c6f250bfd1ee590b20ce5bdc1f814d0d83d197f2860fdfebe5d809001e','CENSUS_RECONCILIATION')
    require((ROOT/'CENSUS-READOUT.json').read_bytes()==old_readout,'REUSE_EXISTING_READOUT')
    hand=census.dump(hand_contract.analyze(json.loads((ROOT/'HAND-PRIMARY.json').read_bytes()),primary))
    with tempfile.TemporaryDirectory(prefix='p9-disposition-') as folder:
        target=Path(folder)/'candidate'
        subprocess.run([sys.executable,str(repo/'research/p9-six-route/source-package-audit-20260908/assemble.py'),str(repo),str(target)],check=True)
        env=dict(os.environ,P9_BASE=str(repo),P9_CANDIDATE=str(target))
        tests=subprocess.run([sys.executable,'-m','unittest','-v','test_census','test_disposition'],cwd=ROOT,env=env,capture_output=True,timeout=90)
        require(tests.returncode==0 and b'Ran 38 tests' in tests.stderr,'TESTS_FAILED:'+tests.stderr.decode())
        data=disposition.build(repo,target,ROOT)
    outputs={'HAND-READOUT.json':hand,'DISPOSITION.json':(json.dumps(data,indent=2)+'\n').encode(),'ROADMAP.md':disposition.markdown(data).encode(),'DISPOSITION-TESTS.log':tests.stdout+tests.stderr}
    for name,b in outputs.items():
        if name in OUTPUTS:require(sha(b)==OUTPUTS[name],'RESULT_IDENTITY:'+name)
        require(not (ROOT/name).exists(),'OUTPUT_ALREADY_EXISTS:'+name)
        (ROOT/name).write_bytes(b)
    receipt={'kind':'COLD_REMOTE_EXACT_SOURCE_AND_EVIDENCE_DISPOSITION','source_head':os.environ['GITHUB_SHA'],'workflow_run':os.environ['GITHUB_RUN_ID'],'source_files':observed,'tests_passed':38,'outputs':{n:{'bytes':len(b),'sha256':sha(b),'git_blob':blob(b)} for n,b in outputs.items()},'cohort_rows':2048,'base_policy_vectors':1,'missing_hand_payoff_observation_rows':2048,'new_native_runs':0,'new_independent_samples':0,'packages_admitted':0,'p9_certified':False,'old_archive_remote_complete':False}
    (ROOT/'DISPOSITION-EXECUTION.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print('DISPOSITION_EXECUTION='+json.dumps(receipt,sort_keys=True))

def verify(repo,readback):
    files=git_files(readback,ROOT.relative_to(repo))
    for row in files:
        p=Path(row['path']);require((repo/p).read_bytes()==(readback/p).read_bytes(),'READBACK:'+str(p))
    print('DISPOSITION_READBACK='+json.dumps({'published_head':subprocess.check_output(['git','-C',str(readback),'rev-parse','HEAD']).decode().strip(),'files_matched':len(files),'files':files,'new_native_runs':0,'p9_certified':False},sort_keys=True))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--readback',type=Path);a=p.parse_args();repo=Path.cwd().resolve()
    if a.readback:verify(repo,a.readback.resolve())
    else:run(repo)
