"""Restore the published v25 experiment from pinned input archives.

No downloads, scientific runs or mutable-branch reads. Refuses nonempty outputs.
Legacy bytes stay in the owner's existing archive rather than being republished.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
from zipfile import ZipFile

SOURCE_HEAD = 'b813e352f988363bf1c14a4eb12827543608f9ba'
SOURCE_SHA = 'd62c8b3c2f5a0bf0b50b4557c2d5d7b846eac64cc42828dd00813ea36c6fe315'
LEGACY_SHA = '76041bfc907164e0c5b5252d48c4bb0aac7b29223a011eee9f03fef17f180e65'
ENGINE_SHA = '8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def require_hash(path, expected):
    observed = sha(path)
    if observed != expected:
        raise ValueError(f'Input identity mismatch for {path}: {observed}')


def safe_unzip(archive, root):
    with ZipFile(archive) as z:
        for item in z.infolist():
            dest = root / item.filename
            if not dest.resolve().is_relative_to(root.resolve()):
                raise ValueError('Archive path escapes output')
            if item.is_dir():
                dest.mkdir(parents=True, exist_ok=True)
            else:
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(z.read(item))


def restore(source, legacy, engine, output):
    for path, expected in [(source,SOURCE_SHA),(legacy,LEGACY_SHA),(engine,ENGINE_SHA)]:
        require_hash(path, expected)
    if output.exists() and any(output.iterdir()):
        raise ValueError('Output is not empty; previous work is never overwritten')
    output.mkdir(parents=True, exist_ok=True)
    meta = output / 'meta'; meta.mkdir()
    safe_unzip(source, meta)
    for line in (meta/'SHA256SUMS').read_text().splitlines():
        expected, name = line.split()
        require_hash(meta/name,expected)
    head = (meta/'source-head.txt').read_text().strip()
    if head != SOURCE_HEAD:
        raise ValueError('Unexpected source commit')
    snapshot = output/'snapshot';snapshot.mkdir()
    with tarfile.open(meta/'source.tar.gz') as archive:
        archive.extractall(snapshot,filter='data')
    git_tree = {}
    for line in (meta/'source-tree.txt').read_text().splitlines():
        left,name=line.split('\t',1);_,kind,blob=left.split()
        git_tree[name]=(kind,blob)
    verified=0
    for path in snapshot.rglob('*'):
        if not path.is_file():continue
        data=path.read_bytes();name=path.relative_to(snapshot).as_posix()
        blob=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
        if git_tree[name]!=('blob',blob):raise ValueError('Git blob mismatch: '+name)
        verified+=1
    binary=output/'engine/Godot_v4.7.2-stable_linux.x86_64'
    binary.parent.mkdir();shutil.copyfile(engine,binary);binary.chmod(0o555)
    history=snapshot/'research/p9-six-route'
    script=(history/'v21/assemble.py').read_text()
    old="archive=Path('/mnt/data/glassvow-p9-native-continuation-20260905.zip')"
    if script.count(old)!=1:raise ValueError('Assembler input seam changed')
    script=script.replace(old,'archive=Path('+repr(str(legacy))+')')
    script=script.replace("'snapshot':'d1d3367ed863728c991b158f07be65d7a66f88f5'", "'snapshot':"+repr(head))
    (output/'assemble.py').write_text(script)
    commands=[[sys.executable,str(output/'assemble.py')],
              [sys.executable,str(output/'study/fuel_recipes.py')],
              [sys.executable,str(output/'study/capped_recipes.py')]]
    with (meta/'assembly.log').open('wb') as log:
        for command in commands:
            subprocess.run(command,cwd=output,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=60)
    price=output/'price';price.mkdir()
    shutil.copytree(output/'study/project',price/'project')
    shutil.copyfile(output/'study/study.py',price/'study.py')
    for name in ['recipes.py','run_price_recovered.py']:
        shutil.copyfile(history/'v25-fuel-price'/name,price/name)
    checks=output/'checks';checks.mkdir()
    shutil.copyfile(history/'v25-fuel-price/test_price_recovered.gd',checks/'test_price_recovered.gd')
    subprocess.run([sys.executable,str(price/'recipes.py')],cwd=output,check=True,stdout=subprocess.DEVNULL,timeout=30)
    report={'status':'SOURCE_RESTORED_NOT_EXECUTED','source_head':head,'verified_git_files':verified,
            'engine_sha256':sha(binary),'legacy_sha256':sha(legacy),
            'price_contents':json.loads((price/'content/manifest.json').read_text())}
    (output/'RESTORED.json').write_text(json.dumps(report,indent=2)+'\n')
    return report


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for option in ['source','legacy','engine','output']:
        parser.add_argument('--'+option,type=Path,required=True)
    args=parser.parse_args()
    report=restore(*(getattr(args,n).resolve() for n in ['source','legacy','engine','output']))
    print(report['status'],report['verified_git_files'])
