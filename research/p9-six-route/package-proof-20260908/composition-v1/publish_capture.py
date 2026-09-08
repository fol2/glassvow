"""Cold reconstruction and offline verification of the already captured packet.

Runs no engine and no statistical experiment. Publishes readable evidence only
inside this directory; branch publication is guarded by the workflow.
"""
from pathlib import Path
import hashlib
import io
import json
import lzma
import os
import shutil
import subprocess
import sys
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parent
REPO = Path.cwd().resolve()
SHA = lambda data: hashlib.sha256(data).hexdigest()
BLOB = lambda data: hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()

def require(ok, reason):
    if not ok:
        raise RuntimeError(reason)

def main():
    output = ROOT/'capture'
    require(not output.exists() and not (ROOT/'REMOTE-READBACK.json').exists(), 'ALREADY_PUBLISHED')
    head = subprocess.check_output(['git','rev-parse','HEAD']).decode().strip()
    require(head == os.environ['GITHUB_SHA'], 'HEAD')
    transfer = json.loads((ROOT/'TRANSFER.json').read_bytes())
    pieces=[]
    for item in transfer['parts']:
        path=ROOT/item['name'];data=path.read_bytes()
        require(len(data)==item['bytes'] and SHA(data)==item['sha256'] and BLOB(data)==item['git_blob'], 'PART:'+item['name'])
        indexed=subprocess.check_output(['git','rev-parse','HEAD:'+str(path.relative_to(REPO))]).decode().strip()
        require(indexed==BLOB(data),'INDEX:'+item['name'])
        pieces.append(data)
    packed=b''.join(pieces)
    require(len(packed)==32596 and SHA(packed)=='ddc8773e258fdc75dcadea24e01de9e6b8fa9895282b810f7a754c2651fbd703','ARCHIVE')
    with tempfile.TemporaryDirectory(prefix='p9-composition-') as tmp:
        folder=Path(tmp);unpacked=folder/'capture';unpacked.mkdir()
        with tarfile.open(fileobj=io.BytesIO(lzma.decompress(packed)),mode='r:') as archive:
            members=archive.getmembers()
            require(len(members)==24 and len({m.name for m in members})==24,'MEMBERS')
            for m in members:
                require(m.isfile() and Path(m.name).name==m.name and 0<=m.size<=2000000,'MEMBER_PATH')
                (unpacked/m.name).write_bytes(archive.extractfile(m).read())
        require(SHA((unpacked/'MANIFEST.json').read_bytes())==transfer['manifest_sha256'],'MANIFEST')
        manifest=json.loads((unpacked/'MANIFEST.json').read_bytes())
        require(set(manifest['files'])|{'MANIFEST.json'}=={m.name for m in members},'FILE_COVERAGE')
        for name,item in manifest['files'].items():
            data=(unpacked/name).read_bytes()
            require(len(data)==item['bytes'] and SHA(data)==item['sha256'],'INNER:'+name)
        require(json.loads((unpacked/'PROTOCOL.json').read_bytes())==json.loads((ROOT/'PROTOCOL.json').read_bytes()),'FROZEN_OBJECT')
        tests=subprocess.run([sys.executable,'-m','unittest','-v','test_compose','test_native_reader','test_capture_review'],cwd=unpacked,capture_output=True,timeout=60)
        require(tests.returncode==0 and b'Ran 29 tests' in tests.stderr,'REGRESSION')
        candidate=folder/'candidate'
        assembly=subprocess.run([sys.executable,str(REPO/'research/p9-six-route/source-package-audit-20260908/assemble.py'),str(REPO),str(candidate)],capture_output=True,timeout=60)
        require(assembly.returncode==0,'ASSEMBLY:'+assembly.stderr.decode())
        expected={
            'COMPOSITION.json':('compose.py',[str(REPO),str(candidate)],'da5a355f05294c4e400e6c6e8fc1b83d134c370ad76d320d83b13bc22da0952c'),
            'NATIVE.json':('read_native.py',['raw.ndjson'],'c7530f9c5368b3783a504aefa33a724d3b320ba1b073ff0b60078b7b1fa4478d'),
            'CAPTURE-REVIEW.json':('review_capture.py',['.'],'b3ec0df99047aafacc423ba0d67319e2abf0f3d0a3e678e781e291e517929290')}
        derived={}
        for name,(script,args,digest) in expected.items():
            data=subprocess.check_output([sys.executable,script]+args,cwd=unpacked,timeout=60)
            require(data==(unpacked/name).read_bytes() and SHA(data)==digest,'DERIVED:'+name)
            derived[name]={'bytes':len(data),'sha256':digest,'git_blob':BLOB(data)}
        raw=(unpacked/'raw.ndjson').read_bytes()
        require(len(raw)==1861970 and SHA(raw)=='70176a36ba032b4434bb4baee35e3963112c63d8b42f7aa96b74de1f12a59b09','RAW')
        shutil.copytree(unpacked,output)
        (output/'REMOTE-TESTS.log').write_bytes(tests.stdout+tests.stderr)
    receipt={'kind':'COLD_CHECKOUT_COMPLETE_CAPTURE_AND_OFFLINE_READBACK','source_head':head,
             'freeze_head':'0726f9e4eecd84ede09ae587befd1d216c038ab1','workflow_run':int(os.environ['GITHUB_RUN_ID']),
             'parts_matched':6,'archive_bytes':len(packed),'archive_sha256':SHA(packed),
             'original_files':24,'raw_bytes':len(raw),'raw_sha256':SHA(raw),'derived':derived,
             'tests_passed':29,'native_runs_in_this_workflow':0,'new_independent_samples':0,
             'packages_admitted':0,'p9_certified':False,
             'scope':'Full capture reconstructed, source identities and original readout bytes matched. This is byte/readout verification, not independent semantic or P9 approval.'}
    (ROOT/'REMOTE-READBACK.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print('READBACK_RECEIPT='+json.dumps(receipt,sort_keys=True))

if __name__=='__main__':
    main()
