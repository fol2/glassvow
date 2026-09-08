"""Publish closed native cells as explicit sufficient statistics, never fabricated raw.

Complete local native captures are retained separately. The JSON envelope preserves
configurations, logs, execution receipts and per-run validation/acquisition inputs.
It is not a full-native-raw backup. No model fitting or outcome-based cell selection.
"""
from pathlib import Path
import argparse, hashlib, json, sys, collections, lzma
R=Path(__file__).resolve().parent
sys.path.insert(0,str(R/'replication'))
import primary_codec
import resume_validation as resume
import read_causal

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def build(folder,names):
    freeze=json.loads((folder/'freeze.json').read_text())
    specs={s['id']:s for s in freeze['specs']}
    assert set(names)<=set(specs) and len(names)==len(set(names))
    cells={}; receipts={}; logs={}; acquisition={}
    for name in names:
        s=specs[name];p=folder/f'{name}.receipt.json';receipt=json.loads(p.read_text())
        assert receipt['spec']==s and receipt['observer']==freeze['observer']
        assert receipt['complete'] and receipt['exit_code']==0 and receipt['exception'] is None
        assert not receipt['diagnostics'] and all(receipt[k] for k in ('bindings','assigned','valid_wins'))
        for ext,key in [('.ndjson','output_sha256'),('.json','config_sha256'),('.log','log_sha256')]:
            assert sha(folder/f'{name}{ext}')==receipt[key]
        manifest,rows=resume.study.parse_rows(folder/f'{name}.ndjson')
        assert manifest['config']==s
        assert manifest['content_sha256']==receipt['content_sha256']==freeze['observer']['content_files'][s['content_path']]
        assert manifest['driver_sha256']==freeze['observer']['sources']['lab_runner.gd']
        assert manifest['policy_sha256']==freeze['observer']['sources']['lab_policy.gd']
        assert len(rows)==s['runs']==receipt['n']
        assert [row['seed'] for row in rows]==list(range(s['seed0'],s['seed0']+s['runs']))
        for row in rows:
            assert row['result'] in ('win','loss','stall','error') and 'causal_samples' in row
            assert all(row[k]==s[k] for k in ('aspect','vow','route','random_build'))
            seen=set()
            for sample in row['causal_samples']:
                key=(sample['fight'],sample['role'],sample['mediator']>0)
                assert key not in seen;seen.add(key)
                a=sample['arms'];assert len(a)==4 and all(len(v)==4 for v in a)
                assert sample['interaction']==[a[3][i]-a[2][i]-a[1][i]+a[0][i] for i in range(4)]
        assert dict(collections.Counter(row['result'] for row in rows))==receipt['counts']
        cells[name]={**{k:s[k] for k in ('id','aspect','vow','route','seed0','runs')},
          'raw_sha256':receipt['output_sha256'],'receipt_sha256':sha(p),
          'rows':[resume.compact(row) for row in rows]}
        # No mutation to the original receipt or log; exact strings survive encoding.
        receipts[name]=dict(receipt);receipts[name]['observer']='@freeze.observer'
        restored=dict(receipts[name]);restored['observer']=freeze['observer']
        assert (json.dumps(restored,indent=2)+'\n')==p.read_text()
        logs[name]=(folder/f'{name}.log').read_text()
        acquisition[name]=[{k:row[k] for k in ('seed','offered','picked','played','deck','relics')} for row in rows]
    return {'status':'CLOSED_NATIVE_SUFFICIENT_STATISTICS_NOT_P9','full_raw_included':False,
      'source_types':'All these cells have locally reconciled native captures; compact statistics are not raw captures.',
      'freeze_sha256':sha(folder/'freeze.json'),
      'cells':cells,'factored_receipts':receipts,'log_texts':logs,'acquisition':acquisition}

def main():
    ap=argparse.ArgumentParser();ap.add_argument('part');ap.add_argument('names',nargs='+');args=ap.parse_args()
    folder=R/'study/studies/replication_remaining';out=R/'publication';out.mkdir(exist_ok=True)
    obj=build(folder,args.names);data=(json.dumps(obj,separators=(',',':'))+'\n').encode()
    env=primary_codec.encode(data,args.part+'.json');assert primary_codec.decode(env)==data
    common=folder/'freeze.json';target=out/'NATIVE-FREEZE.json'
    if target.exists():assert target.read_bytes()==common.read_bytes()
    else:target.write_bytes(common.read_bytes())
    path=out/(args.part+'.json');assert not path.exists();path.write_text(json.dumps(env,separators=(',',':'))+'\n')
    local=out/(args.part+'.decoded.json');local.write_bytes(data)
    print(json.dumps({'file':str(path),'encoded_bytes':path.stat().st_size,'git_blob':primary_codec.blob(path.read_bytes()),'source_sha256':env['sha256'],'cells':len(args.names),'rows':sum(c['runs'] for c in obj['cells'].values())}))
if __name__=='__main__':main()
