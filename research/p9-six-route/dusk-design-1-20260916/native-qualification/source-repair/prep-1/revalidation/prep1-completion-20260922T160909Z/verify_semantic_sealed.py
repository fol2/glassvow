"""Read-only verification of retained PREP-1 case evidence; no implementation import."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
import verify_coverage as v
import copy,json,base64,lzma,hashlib,time,resource,os
from datetime import datetime,timezone
ROOT=v.ROOT
PINS={
 'semantic':(24108,'96a3e61af0ef5a698a4f88c5f0162e610dea8e6b9a59fc6f204420b51386a860',1048046,'2de8f1e46b7daf748c52b0010d7c59f0c906bb65650eb74c3ac0273feb0598b9'),
 'positive':(13692,'460fd4f964d1595e4b42de43a7e8761d48adefa6e95708d20d09303e6913dd8f',381281,'9c8a1d0444c98bdf291dfedfe87dc986241b7190a99ff64379f7c11534100bb0')}
GUARDS={'sealed-sidecar-corrupt':'sealed snapshot corruption','sealed-sidecar-symlink':'derived symlink','sealed-sidecar-missing':'sealed snapshot inventory changed','sealed-original-seed':'sealed original archive corruption','sealed-runtime-config':'sealed snapshot corruption','sealed-seal-bytes':'sealed receipt changed','sealed-failed-parent':'missing/failed preparation reservation','sealed-spliced-receipt':'unbound preparation receipt','sealed-wrong-engine':'sealed engine/source/demand lineage','sealed-wrong-runtime-view':'wrong bound sealed execution view'}
def decoded(group):
 n,h,dn,dh=PINS[group];b=base64.b64decode(''.join((ROOT/'inputs'/f'{group}.payload').read_text().splitlines()),validate=True)
 v.need(len(b)==n and v.sha(b)==h,'compressed identity')
 d=lzma.LZMADecompressor(memlimit=128*2**20);raw=d.decompress(b,max_length=4*2**20)
 v.need(d.eof and not d.unused_data and len(raw)==dn and v.sha(raw)==dh,'decoded identity')
 z=v.load(raw);v.need(z['run_id']==v.RUN,'run identity');return z

def restore(name,entry,allow_external_missing=False):
 r=copy.deepcopy(entry['record']);missing=[]
 for k in entry['top_level_hex_fields']:r[k]=v.descriptor(r[k]).hex()
 for k,d in r.get('files',{}).items():
  v.safe(k)
  if d['codec']=='git-blob-hex' and not (ROOT/'source'/d['path']).is_file():
   if not allow_external_missing:raise ValueError('external source missing '+d['path'])
   missing.append(d);continue
  r['files'][k]=v.descriptor(d).hex()
 if not missing:
  raw=v.enc(r);v.need(len(raw)==entry['original_bytes'] and v.sha(raw)==entry['original_sha256'],'restored record identity '+name)
  (ROOT/'restored'/entry['original_name']).write_bytes(raw)
 return r,missing

def connected(name,r,expected):
 u,z=r['unit'],r['result'];v.need(u['overlay_head']==v.I and u['mode']=='inert_control','source/mode')
 v.need(r['exit']==0 and not r['stderr'] and v.load(r['stdout'])==z,'controller stream')
 before=v.load(bytes.fromhex(r['account_before_hex']));after=r['account']
 v.need(before['synthetic'] is True and after['synthetic'] is True and before['historical']==after['historical'],'synthetic/history')
 row=after['recovery']['unit_reservations_v2'][-1]
 v.need(row['starts']==1 and row['cpu_ns']==u['cpu_seconds']*10**9 and row['raw_bytes']==u['raw_bytes'],'retained reservation')
 v.need(row['before_account_sha256']==v.sha(bytes.fromhex(r['account_before_hex'])) and row['demand_sha256']==v.sha(v.enc(u)),'reservation demand binding')
 v.need(row['state']==('COMPLETE' if expected else 'FAILED') and row['release_protocol']=='B1-ACK-1','reservation state/ACK')
 v.need(z['success'] is expected and z['cleanup_confirmed'] is True and z['native_qualified'] is False and z['n0_accepted'] is False,'inert outcome/cleanup')
 v.need(bool(z['sealed_preparation'])==(expected and u['stage']=='preparation'),'seal promotion')
 files={n:bytes.fromhex(d) for n,d in r['files'].items() if isinstance(d,str)}
 grant=v.load(files['UNIT-GRANT.json']);result=v.load(files['UNIT-RESULT.json'])
 v.need(result['unit']['unit_id']==u['unit_id'] and result['unit']==row and result['unit']['before_account_sha256']==row['before_account_sha256'] and result['unit']['demand_sha256']==row['demand_sha256'],'raw final reservation/account identity')
 v.need(result['result']==row['observations'],'raw final observation')
 v.need(grant['unit_id']==u['unit_id'] and grant['account_sha256']==u['account_sha256'] and grant['overlay_head']==v.I,'grant identities')
 v.need(grant['source_files']==u['source_files'] and grant['execution_files']==u['execution_files'],'grant source/execution view')
 journal=files.get('PREPARATION-MUTATIONS.bin');audit=z.get('preparation_audit')
 if journal is not None:v.need(v.sha(journal)==audit['journal_sha256'] and len(journal)==audit['bytes_read'],'raw mutation journal')
 return {'unit_id':u['unit_id'],'argv':r['argv'],'demand_sha256':v.sha(v.enc(u)),'receipt_sha256':v.sha(v.enc(r['receipt'])),'account_before_sha256':row['before_account_sha256'],'grant_sha256':v.sha(files['UNIT-GRANT.json']),'unit_result_sha256':v.sha(files['UNIT-RESULT.json']),'state':row['state'],'reservation_before_release':'SOURCE atomic_write before runner; B1-ACK identities and kill before_kill record; final UNIT-RESULT is not pre-release','reserved_envelope':{k:row[k] for k in ('starts','cpu_ns','raw_bytes')},'processes':row['processes'],'recorded_cleanup_confirmed':True,'source_manifest':u['source_files'],'helper':u['linux']['helper'],'runtime':u['linux']['runtime'],'success':expected,'task_errors':z['task_outcome']['errors'],'seed_history':(audit or {}).get('seed_history'),'files':{n:{'bytes':len(b),'sha256':v.sha(b)} for n,b in files.items()},'scope':'Inert recorded observations only; original boot cleanup, not reobserved here.'}

def main():
 start=datetime.now(timezone.utc).isoformat();t=time.monotonic();cpu=resource.getrusage(resource.RUSAGE_SELF);rows=[];positive=None
 for group in PINS:
  z=decoded(group)
  for name,e in z['records'].items():
   r,missing=restore(name,e,allow_external_missing=name=='positive')
   row={'case':name,'execution_run_id':v.RUN,'bundle':group,'locator':'records/'+name,'original_record_bytes':e['original_bytes'],'original_record_sha256':e['original_sha256'],'original_hash_verified':not missing}
   if group=='semantic':
    row.update(connected(name,r,False));obs=r['result']
    if name in ('wrong-uid','wrong-param','wrong-source','incomplete'):v.need(any('drift' in x for x in obs['task_outcome']['errors']),'semantic guard')
    if name in ('never-read','double-write','mutate-restore'):v.need(obs['preparation_audit']['seed_history']['ok'] is False,'history guard')
    if name in ('alias','hardlink'):v.need(any(x['nr']==(88 if name=='alias' else 86) and x['errno']==95 for x in obs['refused_requests']),'alias effect guard')
    if name=='mutate-restore':
     f={n:bytes.fromhex(b) for n,b in r['files'].items()};v.need(f['derived/0/imported/probe.resource']==b'DD1-INERT-RESOURCE:quality=9:ASSET-INERT\n' and f['derived/1'].endswith(b'quality=7\n'),'mutate/use/restore resource')
     row['changed_options_witness']={'resource_utf8':f['derived/0/imported/probe.resource'].decode(),'final_sidecar_utf8':f['derived/1'].decode(),'audit':obs['preparation_audit'],'promoted':False}
    row['result']='PASS_EXPECTED_NEGATIVE'
   elif name in GUARDS:
    v.need(r['exit']==2 and not r['stderr'] and v.load(r['stdout'])==r['result'] and r['files']=={},'pre-release sealed')
    v.need(v.enc(r['account'])==bytes.fromhex(r['account_before_hex']),'sealed account mutation')
    v.need(r['result']['pre_release_error']=='ReservationError:'+GUARDS[name],'sealed guard')
    row.update(result='PASS_PRE_RELEASE_SEAL_GUARD',guard=GUARDS[name],argv=r['argv'],unit=r['unit'],receipt=r['receipt'],account_before_sha256=v.sha(bytes.fromhex(r['account_before_hex'])),reservation_created=False)
   elif name=='replay':
    v.need(r['exit']==2 and not r['stderr'] and v.load(r['stdout'])['pre_release_error'].startswith('ReservationError:unit already reserved'),'replay guard')
    v.need(v.enc(r['account'])==bytes.fromhex(r['account_before_hex']),'replay account')
    row.update(result='PASS_REPLAY_GUARD',argv=r['argv'],guard='unit already reserved',account_sha256=v.sha(v.enc(r['account'])),source_link='Same positive controller argv/path; no new unit fabricated')
   else:
    row.update(connected(name,r,True));row.update(result='PASS_RECORDED_POSITIVE' if not missing else 'POSITIVE_INLINE_PROOF_VERIFIED; EXTERNAL_RESTORATION_PENDING',external_source_descriptors=missing)
    if name=='positive':
     positive=r;seal=v.load(bytes.fromhex(r['files']['sealed/SEAL.json']));view=seal['execution_view']
     v.need(view['original_project_sha256']==view['runtime_project_sha256']!=view['preparation_project_sha256'],'projection')
     v.need(seal['seed_history']['ok'] is True,'positive history')
     v.need(v.sha(bytes.fromhex(r['files']['sealed/SEAL.json']))==r['result']['sealed_preparation']['sha256'],'seal identity')
     row['seal_sha256']=r['result']['sealed_preparation']['sha256'];row['projection']=view;row['seal']=seal
    else:
     v.need(positive is not None and r['unit']['sealed_input']=={k:positive['result']['sealed_preparation'][k] for k in ('unit_id','receipt_path','sha256')},'positive-to-runtime seal binding')
     v.need(r['unit']['execution_files']=={n:x['sha256'] for n,x in v.load(bytes.fromhex(positive['files']['sealed/SEAL.json']))['files'].items()},'actual sealed-runtime demand')
     row['seal_parent']='positive';row['not_a_mutable_working_copy']='Source Matrix.positive changes both mutable derived files before this command; post-capture linked separately.'
   rows.append(row)
 usage=resource.getrusage(resource.RUSAGE_SELF)
 report={'schema':'PREP1-SEMANTIC-SEALED-COVERAGE-1','verification_run':'prep1-completion-20260922T160909Z','implementation':v.I,'started_utc':start,'ended_utc':datetime.now(timezone.utc).isoformat(),'reader_sha256':v.sha(Path(__file__).read_bytes()),'reader_dependency_sha256':v.sha((ROOT/'verify_coverage.py').read_bytes()),'cwd':os.getcwd(),'resources':{'wall_seconds':time.monotonic()-t,'user_cpu_seconds':usage.ru_utime-cpu.ru_utime,'system_cpu_seconds':usage.ru_stime-cpu.ru_stime,'scope':'Only this reader execution; excludes retrieval and analysis; no ledger credit'},'cases':rows,'whole_outer_command_metadata':'Not supplied by these case records; no other run metadata substituted','engine_or_inert_runs_here':0}
 (ROOT/'out'/'COVERAGE-SEMANTIC-SEALED.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'cases':len(rows),'original_hashes_verified':sum(x['original_hash_verified'] for x in rows),'resources':report['resources']}))
if __name__=='__main__':main()
