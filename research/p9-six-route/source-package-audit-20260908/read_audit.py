"""Verify and read complete finite native output. No simulator or model fitting."""
from pathlib import Path
import collections,hashlib,io,json,lzma,tarfile
R=Path(__file__).resolve().parent

def sha(data):return hashlib.sha256(data).hexdigest()
def blob(data):return hashlib.sha1(f'blob {len(data)}\0'.encode()+data).hexdigest()
def read(root=R):
    root=Path(root)
    manifest=json.loads((root/'NATIVE-MANIFEST.json').read_text())
    parts=[]
    for p in manifest['parts']:
        d=(root/'native.parts'/p['file']).read_bytes()
        assert len(d)==p['bytes'] and sha(d)==p['sha256'] and blob(d)==p['git_blob']
        parts.append(d)
    archive=b''.join(parts)
    assert len(archive)==manifest['archive_bytes'] and sha(archive)==manifest['archive_sha256']
    with tarfile.open(fileobj=io.BytesIO(archive),mode='r:xz') as tf:
        members=tf.getmembers()
        assert len(members)==len(manifest['files']) and all(x.isfile() for x in members)
        files={m.name:tf.extractfile(m).read() for m in members}
    assert set(files)==set(manifest['files'])
    for name,d in files.items():
        assert len(d)==manifest['files'][name]['bytes'] and sha(d)==manifest['files'][name]['sha256']
    for name in ('stderr.log','stdout.log','parse.log','import.log'):
        assert not any(word in files[name] for word in (b'SCRIPT ERROR',b'Parse Error',b'ERROR:'))
    assert json.loads(files['receipt.json'])['returncode']==0
    rows=[json.loads(s) for s in files['native.ndjson'].splitlines()]
    kinds=collections.Counter(x['kind'] for x in rows)
    assert kinds=={'manifest':1,'dormant':116,'active':48,'card_memory':2,'player_memory':2,'echo_disjunction':2,'reward_pool':2,'summary':1}
    frozen=json.loads((root/'PROTOCOL.json').read_text()); first=rows[0]; summary=rows[-1]
    assert first['content_sha256']==frozen['content_sha256']
    for field,path in [('test_sha256','test_package_nulls.gd'),('selective_sha256','selective_fervor.gd')]:
        assert sha((root/path).read_bytes())==first[field]==frozen['source_sha256'][path]
    assert first['legacy_sha256']==frozen['source_sha256']['diagnostic_legacy.gd']
    assert first['combat_sha256']==frozen['source_sha256']['domain/rules/combat.gd']
    assert first['engine']=='4.7.2-stable (official)'
    assert summary['failures']==0 and summary['checks']==677
    dormant=[x for x in rows if x['kind']=='dormant']; active=[x for x in rows if x['kind']=='active']
    expected={(r,a,u,e) for r in ('echo','multihit','growth','handstock','catalyst') for a in (0,1) for u in (False,True) for e in ('plain','weak','thorns','weak_thorns','block','vulnerable') if r!='echo' or e!='vulnerable'}
    assert {(x['role'],x['aspect'],x['up'],x['environment']) for x in dormant}==expected
    expected_active={(a,u,e,s) for a in (0,1) for u in (False,True) for e in ('plain','weak','thorns','weak_thorns','block','vulnerable') for s in (1,3)}
    assert {(x['aspect'],x['up'],x['environment'],x['strength']) for x in active}==expected_active
    def same(a,b):return all(a[k]==b[k] for k in ('state_sha256','events_sha256'))
    roles={}
    for role in sorted({x['role'] for x in dormant}):
        cells=[x for x in dormant if x['role']==role]
        roles[role]={'pairs':len(cells),'legacy_exact_null':sum(same(x['baseline'],x['legacy']) for x in cells)}
    assert roles['multihit']=={'pairs':24,'legacy_exact_null':0}
    assert all(same(x['baseline'],x['selective']) for x in dormant if x['role']=='multihit')
    assert all(same(x['baseline'],x['selective_off']) for x in active)
    assert all(x['baseline']['hit_events']==x['selective']['hit_events'] and x['baseline']['player_loss']==x['selective']['player_loss'] for x in active)
    witnesses=[]
    for x in dormant:
        if x['role']=='multihit' and x['aspect']==0 and x['up']:
            witnesses.append({'environment':x['environment'],**{key:{k:x[key][k] for k in ('enemy_loss','player_loss','hit_events')} for key in ('baseline','legacy','selective')}})
    return {'status':'FINITE_NULL_AUDIT_COMPLETE_NOT_P9','checks':summary['checks'],'failures':0,
      'frozen_protocol_sha256':sha((root/'PROTOCOL.json').read_bytes()),'content_sha256':first['content_sha256'],
      'raw_sha256':sha(files['native.ndjson']),'archive_sha256':sha(archive),'native_rows':len(rows),
      'dormant_by_role':roles,'selective_dormant_exact':24,'selective_off_exact':48,
      'active_hit_and_thorns_preserved':48,'counterexamples':witnesses,
      'structural_witnesses':[{k:v for k,v in x.items() if k!='events'} for x in rows if x['kind'] in ('card_memory','player_memory','echo_disjunction','reward_pool')],
      'limits':['Constructed finite fixtures, not new population trials or complete null proof.',
        'Old multihit diagnostic remains its frozen multiplicity estimand; exact-null causal attribution is not admitted.',
        'New operator is research-only, not a replacement for frozen descriptor/training/validation.',
        'Different state-carrier witnesses do not prove a full canonical quotient or six-package admission.',
        'Pool eligibility with all reveals is not full natural-economy reachability.',
        'Large historical original-arm archive still lacks verified remote preservation.']}

if __name__=='__main__':
    result=read();data=json.dumps(result,indent=2,ensure_ascii=False)+'\n';path=R/'RESULTS.json'
    if path.exists():assert path.read_text()==data,'Existing readout differs; never overwrite silently'
    else:path.write_text(data)
    print(result['status'],result['checks'],result['failures'],result['native_rows'])
