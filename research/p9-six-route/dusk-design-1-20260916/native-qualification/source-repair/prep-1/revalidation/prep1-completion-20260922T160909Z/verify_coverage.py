"""Evidence-only PREP-1 reader; does not import or execute implementation."""
import base64,copy,hashlib,json,lzma,re,time,resource
from pathlib import Path,PurePosixPath
from datetime import datetime,timezone
ROOT=Path(__file__).resolve().parent
I='d4e91e4fc70d57c81922cc1883b339877d835a53'
RUN='prep1-revalidation-20260921T211017Z'
def sha(b):return hashlib.sha256(b).hexdigest()
def enc(x):return (json.dumps(x,sort_keys=True,separators=(',',':'),allow_nan=False)+'\n').encode()
def need(x,m):
 if not x: raise ValueError(m)
def unique(rows):
 d={}
 for k,v in rows:need(k not in d,'duplicate JSON key');d[k]=v
 return d
def load(b):return json.loads(b,object_pairs_hook=unique)
def safe(p):
 q=PurePosixPath(p);need(not q.is_absolute() and '..' not in q.parts and '\\' not in p and '\0' not in p,'unsafe path '+p)
 return p
def descriptor(d):
 if d['codec']=='utf8-hex':b=d['data'].encode()
 elif d['codec']=='base64-hex':b=base64.b64decode(d['data'],validate=True)
 elif d['codec']=='git-blob-hex':
  b=(ROOT/'source'/safe(d['path'])).read_bytes();need(hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()==d['git_blob'],'external blob')
 else:raise ValueError('unknown descriptor')
 if 'bytes' in d:need(len(b)==d['bytes'],'descriptor length')
 if 'sha256' in d:need(sha(b)==d['sha256'],'descriptor hash')
 return b
PINS={
 'bindings':(7056,'07077407974f7c28eeb5174ad75ee8bad2c77934772387f429434d4a91b809e0',164503,'fe6904f5c51a79dcf8b497bddcc05901777df538737dd0bf105d1c401f7d74b6'),
 'crash':(6776,'14ca459e003250bd145316ad68530ce0f51c92f5cbce4c2eff716771258dcf27',47378,'becdc773845c122eb08f7b8170c598f9c313b8d218eb135124a6ce5d4af09c95')}
GUARDS={'asset-sha':'seed asset identity','engine':'preparation engine lineage','execution-map':'wrong bound preparation execution view','execution-view':'wrong original/derived/runtime view binding','producer':'wrong producer/recipe binding','recipe-head':'preparation source lineage','seed-blob':'wrong tracked sidecar seed identity','seed-path':'not a generated import/UID/cache slot','seed-sha':'wrong tracked sidecar seed identity','traversal':'invalid generated path','undeclared-dependency':'sidecar dependency outside declared generated inventory','unpriced-copies':'raw cannot fit immutable inputs and workload'}
def restore(group):
 n,h,dn,dh=PINS[group];compressed=base64.b64decode(''.join((ROOT/'inputs'/f'{group}.payload').read_text().splitlines()),validate=True)
 need(len(compressed)==n and sha(compressed)==h,'compressed identity')
 dec=lzma.LZMADecompressor(memlimit=128*2**20);raw=dec.decompress(compressed,max_length=4*2**20)
 need(dec.eof and not dec.unused_data and len(raw)==dn and sha(raw)==dh,'decoded identity/end-of-stream')
 bundle=load(raw);need(bundle['run_id']==RUN,'run identity');records={};rows=[]
 for name,entry in bundle['records'].items():
  safe(name);need(entry['original_name']==name+'.json','name mapping');r=copy.deepcopy(entry['record'])
  for k in entry['top_level_hex_fields']:r[k]=descriptor(r[k]).hex()
  for k,v in r.get('files',{}).items():safe(k);r['files'][k]=descriptor(v).hex()
  restored=enc(r);need(len(restored)==entry['original_bytes'] and sha(restored)==entry['original_sha256'],'restored raw identity '+name)
  (ROOT/'restored'/entry['original_name']).write_bytes(restored);records[name]=r
  rows.append({'case':name,'original_bytes':len(restored),'original_sha256':sha(restored),'raw_locator':f'{group}.decoded.json#/records/{name}','execution_run_id':RUN})
 return records,rows
def main():
 t=time.monotonic();u=resource.getrusage(resource.RUSAGE_SELF);started=datetime.now(timezone.utc).isoformat();allrows=[]
 for group in PINS:
  records,rows=restore(group)
  for row in rows:
   name=row['case'];r=records[name]
   if 'unit' in r:
    unit=r['unit'];need(unit['overlay_head']==I and unit['mode']=='inert_control','source/mode')
    need(r['account']['synthetic'] is True,'synthetic account');need(r['stderr']=='','stderr')
    need(load(r['stdout'])==r['result'],'stdout/result');before=bytes.fromhex(r['account_before_hex'])
    need(enc(r['account'])==before,'pre-release account changed');need(r['files']=={},'pre-release captured output')
    need(r['exit']==2,'pre-release exit');expected=GUARDS[name[8:]] if name.startswith('binding-') else 'one executor already holds account'
    need(r['result']['pre_release_error']=='ReservationError:'+expected,'wrong guard')
    demand=copy.deepcopy(unit);demand.pop('receipt_sha256',None)
    row.update(argv=r['argv'],demand_sha256=sha(enc(demand)),account_before_sha256=sha(before),receipt_sha256=sha(enc(r['receipt'])),guard=expected,result='PASS_PRE_RELEASE_REJECTION',new_reservation=False,files=[],source_manifest=unit['source_files'],build_runtime=unit['linux']['runtime'],helper=unit['linux']['helper'])
   else:
    before=r['before_kill'];after=r['after'];b=before['recovery']['unit_reservations_v2'][0];a=after['recovery']['unit_reservations_v2'][0]
    need(before['synthetic'] and after['synthetic'],'kill synthetic');need(r['remaining_pids']==[],'recorded cleanup');need(before['historical']==after['historical'],'history')
    for k,v in {'starts':1,'cpu_ns':16000000000,'raw_bytes':12582912}.items():need(a[k]==b[k]==v,'kill charge')
    need(b['state']=='RESERVED' and b['release_protocol']=='B1-ACK-1','before-kill reservation')
    if name=='kill-controller':
     need(r['exit']==-9 and before==after,'controller kill retention');need({x['pid'] for x in r['adopted']}=={b['processes'][x]['pid'] for x in ('supervisor','workload')},'adopted identities');need(all(x['status']==9 for x in r['adopted']),'adopted status')
    else:
     need(a['state']=='FAILED','supervisor failure retention');obs=a['observations'];need(obs['success'] is False and obs['cleanup_confirmed'] is True and obs['sealed_preparation'] is None,'supervisor failure seal');need(load(r['stdout'])['success'] is False,'controller stdout')
    row.update(result='PASS_KILL_RETENTION_AND_RECORDED_CLEANUP',killed=r['killed'],processes=b['processes'],before_state=b['state'],after_state=a['state'],retained_envelope={k:a[k] for k in ('starts','cpu_ns','raw_bytes')},remaining_pids_observed_then=[],absent_final_artifacts='Not fabricated; source checker requires no seal; post-matrix capture to be linked separately')
  allrows+=rows
 usage=resource.getrusage(resource.RUSAGE_SELF)
 result={'schema':'PREP1-COVERAGE-PART-1','verification_run_id':'prep1-completion-20260922T160909Z','execution_run_id':RUN,'implementation':I,'started_utc':started,'ended_utc':datetime.now(timezone.utc).isoformat(),'reader_sha256':sha(Path(__file__).read_bytes()),'result':'PASS','cases':allrows,'resources':{'wall_seconds':time.monotonic()-t,'user_cpu_seconds':usage.ru_utime-u.ru_utime,'system_cpu_seconds':usage.ru_stime-u.ru_stime,'scope':'reader only; excludes retrieval/analysis; no historical account credit'},'limits':'New evidence verification, not reexecution or independent approval. Process cleanup is recorded on original boot, not a current /proc observation.'}
 (ROOT/'out'/'COVERAGE-BINDING-CRASH.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'result':'PASS','cases':len(allrows),'resources':result['resources']},indent=2))
if __name__=='__main__':main()
