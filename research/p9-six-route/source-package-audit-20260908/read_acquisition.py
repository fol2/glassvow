"""Read exact selected native rows. Existence only, not an incidence estimator."""
from pathlib import Path
import io,json,tarfile
from read_audit import sha,blob
R=Path(__file__).resolve().parent

def read(root=R):
    root=Path(root);outer=json.loads((root/'ACQUISITION-WITNESSES.json').read_text());parts=[]
    for spec in outer['parts']:
        data=(root/'acquisition.parts'/spec['file']).read_bytes()
        assert len(data)==spec['bytes'] and sha(data)==spec['sha256'] and blob(data)==spec['git_blob']
        parts.append(data)
    data=b''.join(parts)
    assert len(data)==outer['archive_bytes'] and sha(data)==outer['archive_sha256']
    with tarfile.open(fileobj=io.BytesIO(data),mode='r:xz') as tf:
        members=tf.getmembers();assert all(m.isfile() for m in members)
        files={m.name:tf.extractfile(m).read() for m in members}
    assert len(files)==len(members)==22 and sha(files['INDEX.json'])==outer['index_sha256']
    index=json.loads(files['INDEX.json']);assert set(index['files'])|{'INDEX.json'}==set(files)
    for name,spec in index['files'].items():
        assert len(files[name])==spec['bytes'] and sha(files[name])==spec['sha256']
    bitmap=json.loads((root.parent/'natural-contribution-20260907/replication/continuation-20260908/ORIGINAL-PRIMARY.json').read_text())
    assert bitmap['format']=='p9-original-arm-win-bitmap-v1' and bitmap['rows']==2048
    bits={(a,v):int(h,16) for cat,a,v,arm,h in bitmap['cells'] if cat==1 and arm==1}
    expected={(a,v,r) for a,rs in {'duskblade':['facet','fervor','cycle'],'ashwarden':['smolder','hand','cycle']}.items() for v in (0,5) for r in rs}
    assert len(index['witnesses'])==12 and {(w['aspect'],w['vow'],w['route']) for w in index['witnesses']}==expected
    results=[]
    for w in index['witnesses']:
        raw=files[w['row_file']];assert sha(raw)==w['native_row_sha256']
        row=json.loads(raw);native=json.loads(files[w['source_manifest']]);receipt=json.loads(files[w['source_receipt']])
        assert (row['aspect'],row['vow'],row['arm'],row['seed'])==(w['aspect'],w['vow'],1,w['seed'])
        assert receipt['complete'] and receipt['exit_code']==0 and receipt['diagnostics']==[] and receipt['exception'] is None
        assert receipt['bindings'] and receipt['assigned'] and receipt['valid_wins'] and receipt['n']==64
        assert receipt['output_sha256']==w['source_file_sha256']
        assert receipt['log_sha256']==sha(files[w['source_log']])
        assert receipt['observer']['engine_sha256']=='8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e'
        assert native['content_sha256']==index['candidate_sha256']==bitmap['catalogue_sha256'][1]
        assert native['config']==receipt['spec'] and native['config']['arm']==1
        assert native['driver_sha256']==receipt['observer']['sources']['arms_runner.gd']
        a=0 if w['aspect']=='duskblade' else 1;offset=w['seed']-45010000
        assert 0<=offset<64 and row['outcome']==('win' if (bits[a,w['vow']]>>(63-offset))&1 else 'loss')
        assert row['error']=='' and len(row['deckIds'])==row['deck']
        components={}
        for c in sorted({w['producer'],w['consumer']}):
            assert c in row['deckIds'] and row['packageEvents'].get(c+'Played',0)>0 and row['packageEvents'].get(c+'Drawn',0)>0
            components[c]={k:row['packageEvents'].get(c+k,0) for k in ('Offered','Drawn','Played')}
        results.append({k:w[k] for k in ('aspect','vow','route','seed')}|{'native_row_sha256':sha(raw),'components':components,'run_outcome':row['outcome']})
    return {'status':index['status'],'contexts':12,'unique_native_rows':len({w['row_file'] for w in index['witnesses']}),
      'new_simulations':0,'candidate_sha256':index['candidate_sha256'],'archive_sha256':outer['archive_sha256'],
      'selection':index['selection'],'witnesses':results,'limits':index['limits']}

if __name__=='__main__':
    result=read();data=json.dumps(result,indent=2)+'\n';p=R/'ACQUISITION-RESULTS.json'
    if p.exists():assert p.read_text()==data,'Existing readout differs'
    else:p.write_text(data)
    print(result['status'],result['contexts'],result['unique_native_rows'])
