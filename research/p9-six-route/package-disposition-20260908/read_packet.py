"""Reconstruct the committed compact census; never claim full old raw recovery."""
from pathlib import Path
import hashlib,json
from census import require,sha,dump,read

def unpack(root):
    import zlib
    root=Path(root)
    manifest=json.loads((root/'CENSUS-MANIFEST.json').read_bytes())
    require(manifest['codec']=='zlib','codec')
    require(manifest['expanded_bytes']==23941 and manifest['expanded_sha256']=='f61e152c2aaaca46bdc358298975c9515a33f2208d827d783d3efcd74dba82a6','projection binding')
    parts=[]
    require([r['path'] for r in manifest['parts']]==[f'CENSUS.part{i:02}' for i in range(4)],'part coverage')
    for row in manifest['parts']:
        b=(root/row['path']).read_bytes()
        blob=hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
        require(len(b)==row['bytes'] and sha(b)==row['sha256'] and blob==row['git_blob'],'part identity')
        parts.append(b)
    b=b''.join(parts)
    require(len(b)==manifest['packed_bytes'] and sha(b)==manifest['packed_sha256'],'packed identity')
    d=zlib.decompressobj();raw=d.decompress(b,manifest['expanded_bytes']+1)
    require(d.eof and not d.unused_data and not d.unconsumed_tail,'zlib coverage')
    require(len(raw)==manifest['expanded_bytes'] and sha(raw)==manifest['expanded_sha256'],'projection identity')
    return json.loads(raw)


if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser();parser.add_argument('root',type=Path)
    args=parser.parse_args();p=unpack(args.root);r=read(p)
    print(json.dumps(r,indent=2))
