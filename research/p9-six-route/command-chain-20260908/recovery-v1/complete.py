"""Reconstruct the committed full capture and explain every Facet veto. No engine."""
import argparse,base64,hashlib,json
from pathlib import Path
import pack_native
import read

def sha(data):return hashlib.sha256(data).hexdigest()
def need(ok,reason):
    if not ok:raise ValueError(reason)
def reconstruct(root):
    m=json.loads((root/'RAW-MANIFEST.json').read_text());parts=[]
    need(m['format']=='P9_LOSSLESS_JSON_DELTA_XZ_V1','FORMAT')
    for part in m['parts']:
        p=(root/part['path']).resolve();need(p.is_relative_to(root.resolve()),'PATH')
        b=p.read_bytes();need(len(b)==part['bytes'] and sha(b)==part['sha256'],'PART')
        need(hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()==part['git_blob'],'BLOB')
        parts.append(b.strip())
    packed=base64.b64decode(b''.join(parts),validate=True)
    need(len(packed)==m['packed_bytes'] and sha(packed)==m['packed_sha256'],'PACKED')
    raw=pack_native.unpack(packed)
    need(len(raw)==m['raw_bytes'] and sha(raw)==m['raw_sha256'],'RAW')
    return raw

def explain(records,result):
    states={r['sha256']:json.loads(r['serialized']) for r in records if r['kind']=='state'}
    rows={(read.key(r['fixture']),r['mask'],r['consumer']):r for r in records if r['kind']=='row' and r['fixture']['role']=='facet'}
    def health(r):return r['metrics']['hp_removed']
    def preblock(r):return sum(e['amount']+e['blocked'] for s in r['steps'] for e in s['events'] if e['t']=='hitEnemy')
    def block(r):return sum(e['blocked'] for s in r['steps'] for e in s['events'] if e['t']=='hitEnemy')
    def contrast(k,mask,fn):return fn(rows[k,mask,True])-fn(rows[k,mask,False])-fn(rows[k,0,True])+fn(rows[k,0,False])
    def chain(k,mask):
        r=rows[k,mask,True];s=next(s for s in r['steps'] if s['cmd'].get('uid')==1000)
        before=states[s['before']][1]['enemies'][0]
        earlier=r['steps'][:r['steps'].index(s)]
        events=s['events'];first_hit=next(i for i,e in enumerate(events) if e['t']=='hitEnemy')
        after_hit_shatters=sum(e['t']=='shatter' for e in events[first_hit+1:])
        return {'producer_shatters_before_consumer':sum(e['t']=='shatter' for a in earlier for e in a['events']),
                'consumer_pre_echo_gate':before['staggered'] or before['statuses'].get('vulnerable',0)>0,
                'consumer_pre_block':before['block'],'consumer_pre_chips':before['chips'],
                'shatters_after_consumer_hit':after_hit_shatters}
    # These fixtures have no overkill/finale handoff: verify before using pre-block accounting.
    need(all(e.get('overkill',0)==0 and not e.get('dead',False) for r in rows.values() for s in r['steps'] for e in s['events'] if e['t']=='hitEnemy'),'SATURATION')
    for r in rows.values():need(preblock(r)-block(r)==health(r),'HEALTH_BLOCK_IDENTITY')
    full=[];subset_contrasts=[]
    for k in sorted({k for k,m,c in rows}):
        n=3 if k[2]==0 else 4
        for mask in range(1<<n):
            h=contrast(k,mask,health);p=contrast(k,mask,preblock);b=contrast(k,mask,block)
            need(h==p-b,'CONTRAST_DECOMPOSITION')
            item={'fixture':list(k),'mask':mask,'health_interaction':h,'preblock_interaction':p,'blocked_interaction':b,**chain(k,mask)}
            subset_contrasts.append(item)
            if mask==(1<<n)-1:full.append(item)
    explained=[]
    for f in result['failures']:
        need(f['name'].startswith('FACET_'),'UNEXPECTED_FAILURE')
        k=tuple(f['fixture']);mask=f['value'][0] if f['name']=='FACET_PROPER_SUBSET_HEALTH' else (1<<(3 if k[2]==0 else 4))-1
        item=next(i for i in subset_contrasts if tuple(i['fixture'])==k and i['mask']==mask)
        need(item['preblock_interaction']==0 and item['health_interaction']==-item['blocked_interaction'],'UNEXPLAINED_FAILURE')
        explained.append({'name':f['name'],**item})
    need(len(explained)==64 and len(rows)==384 and len(subset_contrasts)==192,'COVERAGE')
    return {'status':'POSTHOC_COMPLETE_ATTRIBUTION_NOT_CONFIRMATION','facet_rows':len(rows),'paired_subset_contrasts':192,'original_failed_checks':64,'failed_checks_with_zero_preblock_interaction':64,
            'full_contexts':full,'all_failed_checks':explained,
            'decision':'Keep COMMAND_CONTRACT_FAIL. Positive health interaction alone cannot establish the named mediator chain. Preexisting Cracked does not remove coupled Stun or its downstream block effect. A Shatter after the consumer hit cannot enable that hit. Do not unbundle Stun, reset enemy block between commands, retune the candidate, or silently change original signs.',
            'scope_limit':'This diagnoses the constructed verifier and attribution assumptions, not global package futility, P9 impossibility, or population performance. Pre-block arithmetic is an explanatory coordinate, not a replacement acceptance metric.',
            'new_native_runs':0,'new_independent_samples':0,'packages_admitted':0,'p9_certified':False}

def main(root,out):
    raw=reconstruct(root);records=[json.loads(s) for s in raw.splitlines()]
    result=read.analyze(records,json.loads((root/'PROTOCOL.json').read_text()))
    rendered=(json.dumps(result,indent=2)+'\n').encode()
    need(sha(rendered)=='81f5261c118eced66482a78857e3d1335beed80abc5e83d97215c5b9e6289e8f','RESULT_IDENTITY')
    out.mkdir(parents=True,exist_ok=False)
    (out/'native.ndjson').write_bytes(raw);(out/'RESULTS.json').write_bytes(rendered)
    (out/'ATTRIBUTION.json').write_text(json.dumps(explain(records,result),indent=2)+'\n')
    print(json.dumps({'raw_bytes':len(raw),'raw_sha256':sha(raw),'result_sha256':sha(rendered),'status':result['status'],'failed_checks':result['failed_checks'],'facet_failures_explained':64}))
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('fresh_output');a=p.parse_args();main(Path(__file__).resolve().parent,Path(a.fresh_output).resolve())
