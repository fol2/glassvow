#!/usr/bin/env python3
"""Verify retained PREP-1 records; never import repository code or launch a child."""
import argparse, base64, copy, hashlib, json, lzma, os, platform, resource, time
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
I='d4e91e4fc70d57c81922cc1883b339877d835a53'
RUN='prep1-revalidation-20260921T211017Z'
PINS={'positive-and-sealed.json':'cc6d1051266180fc641d2e92a9ffe712af8514e3','post-matrix-capture.json':'e62f92ac3ab4cc75d580b2f4ea75da5e08235fa4'}
GUARDS={'replay':'unit already reserved; no second spawn','sealed-failed-parent':'missing/failed preparation reservation','sealed-original-seed':'sealed original archive corruption','sealed-runtime-config':'sealed snapshot corruption','sealed-seal-bytes':'sealed receipt changed','sealed-sidecar-corrupt':'sealed snapshot corruption','sealed-sidecar-missing':'sealed snapshot inventory changed','sealed-sidecar-symlink':'derived symlink','sealed-spliced-receipt':'unbound preparation receipt','sealed-wrong-engine':'sealed engine/source/demand lineage','sealed-wrong-runtime-view':'wrong bound sealed execution view'}
def need(v,m):
    if not v: raise ValueError(m)
def sha(b): return hashlib.sha256(b).hexdigest()
def blob(b): return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def enc(v): return (json.dumps(v,sort_keys=True,separators=(',',':'),allow_nan=False)+'\n').encode()
def pairs(items):
    d={}
    for k,v in items:
        need(k not in d,'duplicate JSON key'); d[k]=v
    return d
def load(b): return json.loads(b,object_pairs_hook=pairs,parse_constant=lambda x: (_ for _ in ()).throw(ValueError(x)))
def safe(n):
    p=PurePosixPath(n)
    need(isinstance(n,str) and not p.is_absolute() and str(p)==n and all(s not in ('','..','.','.git','.env','.ssh') for s in n.split('/')),'unsafe evidence/source path')
    return n
def unpack(path):
    raw=path.read_bytes(); need(blob(raw)==PINS[path.name],'GitHub wrapper identity')
    w=load(raw);need(w['run_id']==RUN and w['encoding']=='xz+base64','bundle identity')
    packed=base64.b64decode(''.join(w['payload_base64_lines']),validate=True)
    need(len(packed)==w['compressed_bytes'] and sha(packed)==w['compressed_sha256'],'compressed identity')
    decoder=lzma.LZMADecompressor(memlimit=128*2**20); data=decoder.decompress(packed,max_length=4*2**20)
    need(decoder.eof and not decoder.unused_data,'incomplete/trailing XZ')
    need(len(data)==w['decoded_bytes'] and sha(data)==w['decoded_sha256'],'decoded identity')
    return load(data),{'git_blob':blob(raw),'wrapper_bytes':len(raw),'compressed_bytes':len(packed),'compressed_sha256':sha(packed),'decoded_bytes':len(data),'decoded_sha256':sha(data)}
def main():
    p=argparse.ArgumentParser();p.add_argument('--input',type=Path,required=True);p.add_argument('--source',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    need(not a.output.exists(),'refuse overwrite'); started=datetime.now(timezone.utc).isoformat(); t=time.monotonic();cpu=resource.getrusage(resource.RUSAGE_SELF)
    positive,pmeta=unpack(a.input/'positive-and-sealed.json');post,qmeta=unpack(a.input/'post-matrix-capture.json')
    need(positive['run_id']==post['run_id']==RUN,'execution splice')
    sources={}; restored={}; rows={}
    def descriptor(d):
        codec=d['codec']
        if codec=='utf8-hex': b=d['data'].encode('utf-8')
        elif codec=='base64-hex': b=base64.b64decode(d['data'],validate=True)
        elif codec=='git-blob-hex':
            need(d['commit']==I,'external source ref');n=safe(d['path']);f=a.source/n
            need(f.resolve()==f.absolute() and not f.is_symlink(),'source alias')
            b=f.read_bytes();need(blob(b)==d['git_blob'],'external Git blob')
            sources[n]={'commit':I,'git_blob':blob(b),'bytes':len(b),'sha256':sha(b)}
        else: raise ValueError('unknown descriptor')
        if 'bytes' in d: need(len(b)==d['bytes'],'descriptor bytes')
        if 'sha256' in d: need(sha(b)==d['sha256'],'descriptor SHA')
        return b
    for name,e in positive['records'].items():
        safe(name);safe(e['original_name']);r=copy.deepcopy(e['record'])
        rfiles=r.get('files',{})
        for n,d in list(rfiles.items()): safe(n);rfiles[n]=descriptor(d).hex()
        for n in e['top_level_hex_fields']:r[n]=descriptor(r[n]).hex()
        raw=enc(r);need(len(raw)==e['original_bytes'] and sha(raw)==e['original_sha256'],name+': original record identity')
        restored[name]=r
        before_raw=bytes.fromhex(r['account_before_hex']);before=load(before_raw);after=r['account']
        need(before.get('synthetic') is True and after.get('synthetic') is True,'non-synthetic account')
        need(before['historical']==after['historical'],'historical mutation')
        result=load(r['stdout']);need(r['stderr']=='','controller stderr')
        row={'original_name':e['original_name'],'bytes':len(raw),'sha256':sha(raw),'argv':r['argv'],'exit':r['exit'],'before_account_sha256':sha(before_raw),'after_account_sha256':sha(enc(after))}
        if name in GUARDS:
            need(r['exit']==2 and result['pre_release_error']=='ReservationError:'+GUARDS[name],name+': guard')
            need(enc(after)==before_raw,name+': account effect')
            need(not rfiles,name+': new capture')
            row.update(outcome='EXPECTED_PRE_RELEASE_REJECTION',guard=result['pre_release_error'],new_reservations=0)
            if name=='replay': row['limit']='Replay record has no files/unit fields; existing positive output is not asserted absent.'
        else:
            need(name in ('positive','sealed-runtime') and r['exit']==0 and result==r['result'],name+': controller')
            u=r['unit'];need(u['overlay_head']==I and u['mode']=='inert_control','source/mode')
            need(sha(before_raw)==u['account_sha256'],'bound account')
            unsigned=dict(u);unsigned.pop('receipt_sha256',None)
            need(r['receipt']['schema']=='DD1-INERT-ONLY' and r['receipt']['demand_sha256']==sha(enc(unsigned)) and u['receipt_sha256']==sha(enc(r['receipt'])),'input inert receipt')
            br=before['recovery'].get('unit_reservations_v2',[]);ar=after['recovery']['unit_reservations_v2']
            need(ar[:-1]==br and len(ar)==len(br)+1,'reservation append')
            charge=ar[-1];need(charge==result['charged'] and charge['state']=='COMPLETE','complete charged row')
            need(charge['starts']==1 and charge['cpu_ns']==u['cpu_seconds']*10**9 and charge['raw_bytes']==u['raw_bytes'],'reserved envelope')
            need(charge['before_account_sha256']==sha(before_raw) and charge['demand_sha256']==sha(enc(u)) and charge['release_protocol']=='B1-ACK-1','reservation binding')
            need(result['success'] is True and result['cleanup_confirmed'] is True and result['native_qualified'] is False and result['n0_accepted'] is False,'actual outcome/scope')
            filebytes={n:bytes.fromhex(v) for n,v in rfiles.items()}
            ur=load(filebytes['UNIT-RESULT.json']);grant=load(filebytes['UNIT-GRANT.json'])
            need(ur['unit']==charge and ur['result']==charge['observations'],'raw result/ledger agreement')
            for key in ('unit_id','account_sha256','overlay_head','source_files','execution_files'):need(grant[key]==u[key],'grant '+key)
            need(result['task_outcome']['ok'] is True and filebytes['capture/save.bin']==b'PREP1\n','task bytes')
            need(filebytes['capture/stderr.bin']==b'','workload stderr')
            need(result['helper_sha256']==u['linux']['helper']['sha256']=='b22fdaba90df2a1a317f1d3a690522736a1301f9b442016764d5bf173f2fdf0f','helper pin')
            need(u['linux']['runtime']['/workload']['sha256']=='d13b4975c0c131e15780f435474d88f2950cb25629c69fe497cbb7824a446629','harmless producer pin')
            row.update(outcome='EXPECTED_CONNECTED_SUCCESS',demand_sha256=sha(enc(u)),input_receipt_sha256=sha(enc(r['receipt'])),grant_sha256=sha(filebytes['UNIT-GRANT.json']),result_sha256=sha(filebytes['UNIT-RESULT.json']),charge={k:charge[k] for k in ('starts','cpu_ns','raw_bytes','state','release_protocol')},processes=charge['processes'],observed_resources={k:result[k] for k in ('controller_cpu_seconds_at_report','elapsed_seconds_at_report','setup_raw_reserved','workload_raw_reserved')},workload_stdout=filebytes['capture/stdout.bin'].decode())
        rows[name]=row
    need(set(rows)==set(GUARDS)|{'positive','sealed-runtime'},'case-set completeness')
    pos=restored['positive'];runtime=restored['sealed-runtime'];b={k:bytes.fromhex(v) for k,v in pos['files'].items()};u=pos['unit'];sealraw=b['sealed/SEAL.json'];seal=load(sealraw)
    need(sha(sealraw)==pos['result']['sealed_preparation']['sha256'],'seal identity')
    need(seal['demand_sha256']==sha(enc(u)) and seal['before_account_sha256']==u['account_sha256'] and seal['source_head']==I,'seal lineage')
    need(seal['recipe']==u['preparation'] and seal['recipe_sha256']==sha(enc(u['preparation'])),'seal recipe')
    raw_project=b['sealed/originals/project.godot']; prep_project=raw_project.replace(b'"res://addons/funplay_mcp/plugin.cfg", ',b'',1)
    v=seal['execution_view'];need(v['original_project_sha256']==v['runtime_project_sha256']==sha(raw_project) and v['preparation_project_sha256']==sha(prep_project),'project projection')
    need(b['sealed/payload/project.godot']==raw_project,'runtime original restored')
    for n,item in seal['files'].items():
        need(n.startswith('res://'),'seal source name');data=b['sealed/payload/'+safe(n[6:])]
        need(len(data)==item['bytes'] and sha(data)==item['sha256'],'complete sealed file map')
    for n,item in seal['original_archive'].items():
        data=b['sealed/originals/'+safe(n[6:])];need(len(data)==item['bytes'] and sha(data)==item['sha256']==u['source_files'][n],'original archive')
    need(set(seal['files'])==set(u['source_files'])|set(seal['generated']),'sealed inventory')
    audit=pos['result']['preparation_audit'];need(audit['ok'] is True and audit['seed_history']['ok'] is True and sha(b['PREPARATION-MUTATIONS.bin'])==audit['journal_sha256'],'positive audit')
    need(runtime['unit']['sealed_input']=={k:pos['result']['sealed_preparation'][k] for k in ('unit_id','receipt_path','sha256')} and runtime['unit']['execution_files']=={n:d['sha256'] for n,d in seal['files'].items()},'runtime same exact seal')
    need(runtime['result']['sealed_preparation'] is None,'runtime does not reseal')
    post_files={};absent=[]
    for case,files in post['records'].items():
        for n,d in files.items():
            safe(case);safe(n)
            if not d['exists']:absent.append(case+'/'+n);continue
            need(d['encoding'] in ('utf8','base64'),'post encoding');data=d['content'].encode() if d['encoding']=='utf8' else base64.b64decode(d['content'],validate=True)
            need(len(data)==d['bytes'] and sha(data)==d['sha256'],'post file identity');post_files[case+'/'+n]=data
    need(post_files['positive/output/derived/0/imported/probe.resource']==b'UNAPPROVED MUTABLE WORKSPACE' and post_files['positive/output/derived/1']==b'WRONG UID/OPTIONS','retained mutable edits')
    need(b['sealed/payload/.godot/imported/probe.resource']==b'DD1-INERT-RESOURCE:quality=7:ASSET-INERT\n','sealed resource')
    checks=post['postcheck_processes'];ids={(d['boot_id'],d['pid'],d['start_ticks']) for d in checks}
    need(len(ids)==len(checks)==post['recorded_controller_supervisor_workload_identities']==60 and all(d['pid_absent_at_postcheck'] is True for d in checks),'recorded cleanup set')
    for case in ('positive','sealed-runtime'):
        for d in rows[case]['processes'].values():need((d['boot_id'],d['pid'],d['start_ticks']) in ids,'same-run cleanup join')
    for n,d in sources.items():
        raw=(a.source/n).read_bytes();need(len(raw)==d['bytes'] and sha(raw)==d['sha256'] and blob(raw)==d['git_blob'],'source after drift')
    usage=resource.getrusage(resource.RUSAGE_SELF)
    out={'schema':'PREP1-POSITIVE-POST-VERIFICATION-1','run_id':a.input.parent.name,'execution_run_id':RUN,'implementation':I,'started_utc':started,'ended_utc':datetime.now(timezone.utc).isoformat(),'result':'PASS_READBACK_AND_RESTORATION','reader_sha256':sha(Path(__file__).read_bytes()),'wrappers':{'positive':pmeta,'post':qmeta},'sources':sources,'cases':rows,'projection':{'original_project_sha256':sha(raw_project),'preparation_project_sha256':sha(prep_project),'seal_sha256':sha(sealraw),'sealed_files':len(seal['files']),'original_archives':len(seal['original_archive']),'audit_sha256':audit['journal_sha256'],'mutable_workspace_changed_but_sealed_resource_retained':True},'post_capture':{'observed_utc':post['observed_utc'],'phase':post['phase'],'present_files':len(post_files),'present_bytes':sum(map(len,post_files.values())),'absent_files':absent,'connected_units':post['connected_units'],'recorded_absent_process_identities':len(ids),'boot_ids':sorted({x[0] for x in ids})},'new_reader_resources':{'wall_seconds':time.monotonic()-t,'user_cpu_seconds':usage.ru_utime-cpu.ru_utime,'system_cpu_seconds':usage.ru_stime-cpu.ru_stime,'scope':'This reader only; transport/materialization/earlier inspection/analysis excluded; not live-account credit'},'current_reader_host':{'boot_id':Path('/proc/sys/kernel/random/boot_id').read_text().strip(),'tasks':len(list(Path('/proc/self/task').iterdir()))},'limits':['No engine/inert/build/H/metadata execution here.','No current /proc check substitutes for another boot cleanup.','Post-capture input unit/receipt may reflect replay; pre-release facts use original case records.','No native producer qualification or independent approval.','Preliminary inspection assumed replay had files; its distinct schema was then handled explicitly. No implementation or test was changed.']}
    a.output.write_bytes(enc(out));print(json.dumps({'result':out['result'],'cases':len(rows),'external_sources':len(sources),'output_bytes':a.output.stat().st_size,'output_sha256':sha(a.output.read_bytes()),'new_reader_resources':out['new_reader_resources']},indent=2))
if __name__=='__main__':main()
