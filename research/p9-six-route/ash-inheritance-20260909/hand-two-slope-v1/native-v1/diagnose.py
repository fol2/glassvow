"""Diagnose the preserved fixed-query mismatch; no engine, replay or gate change."""
import hashlib
import json
import lzma
from pathlib import Path
import re
import sys
import tarfile
from collections import Counter


def require(ok, why):
    if not ok: raise ValueError(why)


def sha(b): return hashlib.sha256(b).hexdigest()
def save(p,v): p.write_text(json.dumps(v,indent=2)+'\n')


def main(capture,out):
    require(not out.exists(),'OUTPUT_EXISTS')
    files=json.loads((capture/'FILES.json').read_bytes())
    require(len(files)==len({r['path'] for r in files}),'DUPLICATE_PATH')
    for r in files:
        p=Path(r['path']);require(not p.is_absolute() and '..' not in p.parts,'PATH')
        b=(capture/p).read_bytes();require(len(b)==r['bytes'] and sha(b)==r['sha256'],'INPUT:'+str(p))
    proof=json.loads((capture/'REMOTE-READBACK.json').read_bytes())
    require(proof['all_bytes_equal'] is True,'PRIOR_READBACK')
    manifest=json.loads((capture/'SOURCE-MANIFEST.json').read_bytes())
    sources={}
    with tarfile.open(capture/'runtime-source.tar.xz','r:xz') as tf:
        for role in ('reference','linear','candidate'):
            chain=[];name='lab_policy.gd'
            while name:
                require(name not in chain and len(chain)<8,'INHERITANCE')
                chain.append(name)
                b=tf.extractfile(role+'/'+name).read();m=manifest[role][name]
                require(len(b)==m['bytes'] and sha(b)==m['sha256'],'SOURCE:'+role+'/'+name)
                text=b.decode();starts=list(re.finditer(r'^(?:static )?func (\w+)\(',text,re.M))
                selected={}
                for i,s in enumerate(starts):
                    body=text[s.start():starts[i+1].start() if i+1<len(starts) else len(text)]
                    if s[1] in ('score','draft') or '"phantom"' in body:selected[s[1]]=body
                if selected:sources[role+'/'+name]={'identity':m,'functions':selected}
                p=re.search(r'^extends\s+"res://([^\"]+)"',text,re.M)
                name=p.group(1) if p else None
    summaries={};mismatches=[]
    for role in ('reference','linear','candidate','legacy-mask','legacy-query'):
        data=[json.loads(x) for x in lzma.decompress((capture/(role+'.jsonl.xz')).read_bytes()).splitlines()]
        tail=data.pop();require(tail=={'kind':'terminal','cases':len(data)},'COVERAGE')
        counts=Counter();examples={}
        for r in data:
            native=r['after']==r['expanded_after'] and r['events']==r['expanded_events']
            raw=r['actual_raw']==r['expected_raw']
            score=r['score']==r['expanded_score']
            draft=r['draft']==r['expanded_draft']
            k=f"raw={raw},native={native},score={score},draft={draft},zero={r['expected_raw']==0}"
            counts[k]+=1
            brief={n:r[n] for n in ('key','q','up','aspect','context','active','expected_raw','actual_raw','score','expanded_score','draft','expanded_draft','data')}
            if k not in examples:examples[k]=brief
            if not (raw and native and score and draft):mismatches.append({'role':role,**brief})
        summaries[role]={'rows':len(data),'comparisons':dict(counts),'first_example_of_each_comparison':examples}
    out.mkdir(parents=True)
    save(out/'SOURCES.json',sources)
    save(out/'MISMATCHES.json',mismatches)
    save(out/'RESULTS.json',{'kind':'PRESERVED_QUERY_MISMATCH_DIAGNOSIS','summaries':summaries,
        'new_native_runs':0,'new_population_outcomes':0,'packages_admitted':0,'p9_certified':False,
        'limits':'All fixed records examined. Comparison grouping is diagnostic, not scientific reclassification or changed acceptance.'})
    save(out/'FILES.json',[{'path':p.name,'bytes':p.stat().st_size,'sha256':sha(p.read_bytes())} for p in sorted(out.iterdir())])


if __name__=='__main__':main(*(Path(x) for x in sys.argv[1:]))
