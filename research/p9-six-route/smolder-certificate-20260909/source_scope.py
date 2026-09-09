"""Read pinned native and historical laws. No engine or experimental outcome.
The archive is evidence, not a source to install into the product.
"""
from __future__ import annotations
import hashlib, io, json, re, tarfile
from pathlib import Path
import sys

ARCHIVE_BLOB = '0e963a6dfadb87912f9b1074b78d8629bbad2a47'
CONTENT = 'a0d608a5142d2e3aab799cdf33d3163922b402c2aaf2a895e46e096399b56cf1'
COMBAT = '3adb0e063a536bf249d3b5d9524427facf1398304206da59d97594d3fff246e8'
TERMS = ('mistbound', 'bloodfire', 'catalyst', 'poison')

def sha(data): return hashlib.sha256(data).hexdigest()
def blob(data): return hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
def require(ok, why):
    if not ok: raise ValueError(why)

def functions(text):
    matches=list(re.finditer(r'^(?:static )?func (\w+)\(',text,re.M))
    return {m.group(1):text[m.start():matches[i+1].start() if i+1<len(matches) else len(text)]
            for i,m in enumerate(matches)}

def main(repo, archive, out):
    repo,archive,out=map(Path,(repo,archive,out))
    require(not out.exists(),'OUTPUT_EXISTS');out.mkdir(parents=True)
    data=archive.read_bytes();require(blob(data)==ARCHIVE_BLOB,'ARCHIVE_IDENTITY')
    b=(repo/'content/full-content.json').read_bytes();require(sha(b)==CONTENT,'CONTENT')
    c=(repo/'domain/rules/combat.gd').read_bytes();require(sha(c)==COMBAT,'COMBAT')
    inventory={}; chosen={}
    with tarfile.open(fileobj=io.BytesIO(data),mode='r:gz') as tf:
        for member in tf.getmembers():
            if member.isdir():continue
            require(member.isfile() and not member.name.startswith('/') and '..' not in Path(member.name).parts,'ARCHIVE_PATH')
            d=tf.extractfile(member).read();inventory[member.name]={'bytes':len(d),'sha256':sha(d)}
            if member.name.endswith('.gd'):
                text=d.decode()
                for name,body in functions(text).items():
                    if any(term in body.lower() for term in TERMS):
                        chosen[member.name+'::'+name]={'body':body,'sha256':sha(body.encode())}
    content=json.loads(b)
    native={name:body for name,body in functions(c.decode()).items()
            if any(term in body.lower() for term in TERMS)}
    facts={'kind':'PINNED_SOURCE_EXTRACTION_NOT_PACKAGE_ADMISSION','archive_git_blob':blob(data),
           'archive_files':inventory,'native_content_sha256':CONTENT,'native_combat_sha256':COMBAT,
           'cards':{k:content['cards'][k] for k in ('venomStrike','toxicMist','catalyst','bloodRite','leechBlade','preparation','surge','phantomBlades')},
           'native_function_hashes':{k:sha(v.encode()) for k,v in native.items()},
           'historical_function_hashes':{k:v['sha256'] for k,v in chosen.items()},
           'new_native_runs':0,'packages_admitted':0,'p9_certified':False}
    (out/'SOURCE-INDEX.json').write_text(json.dumps(facts,indent=2)+'\n')
    (out/'HISTORICAL-FUNCTIONS.json').write_text(json.dumps(chosen,indent=2)+'\n')
    (out/'NATIVE-FUNCTIONS.json').write_text(json.dumps(native,indent=2)+'\n')
    print(json.dumps({'functions':list(chosen),'inputs_verified':True},sort_keys=True))

if __name__=='__main__':main(*sys.argv[1:])
