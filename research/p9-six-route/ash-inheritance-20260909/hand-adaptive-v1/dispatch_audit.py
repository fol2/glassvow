"""Read the actual nested planner dispatch from the preserved native source archive."""
from pathlib import Path
import hashlib,json,re,sys,tarfile
root=Path(sys.argv[1]);output=Path(sys.argv[2]);assert not output.exists()
manifest=json.loads((root/'SOURCE-MANIFEST.json').read_bytes())['qualified']
chosen={};record={}
with tarfile.open(root/'runtime-source.tar.xz','r:xz') as tf:
    wrapper=tf.extractfile('qualified/public_rollout.gd').read().decode()
    core=re.search(r'const Base[^\n]*preload\("res://([^"]+)"\)',wrapper).group(1)
    assert core in manifest
    for name in ('lab_policy.gd','public_rollout.gd',core):
        data=tf.extractfile('qualified/'+name).read();m=manifest[name]
        assert len(data)==m['bytes'] and hashlib.sha256(data).hexdigest()==m['sha256']
        text=data.decode();matches=list(re.finditer(r'^(?:static )?func (\w+)\(',text,re.M))
        bodies={s[1]:text[s.start():matches[i+1].start() if i+1<len(matches) else len(text)] for i,s in enumerate(matches)}
        chosen[name]={'prelude':text[:matches[0].start()] if matches else text,
                      'functions':{n:b for n,b in bodies.items() if 'rollout' in n or '.rollout(' in b or 'clone_public' in b or 'greedy_completion' in n}}
        record[name]=m
output.write_text(json.dumps({'kind':'ACTUAL_NESTED_PLANNER_DISPATCH_SOURCE_AUDIT','source':record,'code':chosen,'new_native_runs':0,'packages_admitted':0,'p9_certified':False},indent=2)+'\n')
