"""Lossless representation packing; never calls the engine or infers an outcome."""
import argparse,base64,copy,hashlib,json,lzma,re
from pathlib import Path

def canonical(x):return json.dumps(x,ensure_ascii=False,sort_keys=True,separators=(',',':'))
def diff(a,b,p=()):
    if type(a)!=type(b):return [[list(p),b]]
    if isinstance(a,dict) and a.keys()==b.keys():return [v for k in b for v in diff(a[k],b[k],p+(k,))]
    if isinstance(a,list) and len(a)==len(b):return [v for i in range(len(b)) for v in diff(a[i],b[i],p+(i,))]
    return [] if a==b else [[list(p),b]]
def patch(a,ops):
    b=copy.deepcopy(a)
    for path,value in ops:
        if not path:b=value;continue
        target=b
        for k in path[:-1]:target=target[k]
        target[path[-1]]=value
    return b

def pack(raw):
    records=[json.loads(s) for s in raw.splitlines()]
    assert b''.join((canonical(r)+'\n').encode() for r in records)==raw
    hashes={r['sha256']:f'@STATE{i:04d}@' for i,r in enumerate(r for r in records if r['kind']=='state')}
    assert not re.search(rb'@STATE[0-9]+@',raw)
    text=re.sub(rb'(?<![0-9a-f])[0-9a-f]{64}(?![0-9a-f])',lambda m:hashes.get(m[0].decode(),m[0].decode()).encode(),raw)
    records=[json.loads(s) for s in text.splitlines()];last={};packed=[]
    for r in records:
        kind=r['kind']
        if kind=='state':
            x=json.loads(r['serialized']);assert canonical(x)==r['serialized'];r['serialized']=x
        ops=diff(last.get(kind),r);packed.append([kind,ops]);last[kind]=r
    return lzma.compress(canonical(packed).encode(),preset=9)

def unpack(blob):
    packed=json.loads(lzma.decompress(blob));last={};records=[];hashes={}
    for kind,ops in packed:
        r=patch(last.get(kind),ops);last[kind]=copy.deepcopy(r)
        if kind=='state':
            r['serialized']=canonical(r['serialized'])
            hashes[r['sha256']]=hashlib.sha256(r['serialized'].encode()).hexdigest()
        records.append(r)
    text=''.join(canonical(r)+'\n' for r in records)
    return re.sub(r'@STATE[0-9]{4}@',lambda m:hashes[m[0]],text).encode()
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['pack','unpack']);p.add_argument('source');p.add_argument('destination');a=p.parse_args()
    b=Path(a.source).read_bytes();out=pack(b) if a.action=='pack' else unpack(b)
    if a.action=='pack':assert unpack(out)==b,'Roundtrip must be byte exact'
    with Path(a.destination).open('xb') as f:f.write(out)
    print(len(out),hashlib.sha256(out).hexdigest())
