"""Resume only missing published validation cells; never fabricate lost receipts.

Durable primary records and new native captures remain different source types.
A fixed first-seed replay checks every recovered context before reuse. No model,
content, controller, cohort, or sample-size selection occurs in this program.
"""
from pathlib import Path
import hashlib,importlib.util,json,sys
R=Path(__file__).resolve().parent
sys.path.insert(0,str(R/'study'))
import study
spec=importlib.util.spec_from_file_location('fixed',R/'study/run_replication_original.py')
fixed=importlib.util.module_from_spec(spec);spec.loader.exec_module(fixed)
ROLES=['chip_supply','echo','multihit','growth','handstock','catalyst']
DIMS=[3,0,0,0,0,2]

def compact(row):
    vectors=[[0]*6 for _ in ROLES]
    for q in row['causal_samples']:
        j=ROLES.index(q['role']);d=DIMS[j];a=q['arms']
        dc=a[3][d]-a[2][d];dm=a[3][d]-a[1][d];inter=dc-a[1][d]+a[0][d]
        assert q['interaction'][d]==inter
        for k,value in enumerate([1,int(dc>0),int(dc<0),dc,dm,inter]):vectors[j][k]+=value
    return [row['result'],len(row['fights']),[[j,*v] for j,v in enumerate(vectors) if any(v)]]

def cache():
    data=json.loads((R/'DURABLE-CACHE.json').read_text())['cells']
    all_specs={s['id']:s for s in fixed.panel()}
    for name,c in data.items():
        s=all_specs[name]
        assert all(c[k]==s[k] for k in ('aspect','vow','route','seed0','runs'))
    return data

def main():
    mode=sys.argv[1];cells=cache();all_specs=fixed.panel()
    assert study.sha(R/'replication/FROZEN-DESCRIPTOR.json')=='2cfe1d8ff00d5ff695664c597be3a93e3960f39732fa049eac82b9397184bab7'
    if mode=='bridge':
        specs=[]
        for s in all_specs:
            if s['id'] in cells:
                x=dict(s);x['runs']=1;x['id']=s['id']+'-cached-replay';specs.append(x)
        study.batch('cache_bridge',specs,workers=4,timeout=240)
        compared=[]
        for s in specs:
            raw=R/'study/studies/cache_bridge'/f'{s["id"]}.ndjson'
            manifest,rows=study.parse_rows(raw)
            original=s['id'].removesuffix('-cached-replay')
            assert compact(rows[0])==cells[original]['rows'][0],original
            compared.append({'id':original,'seed':rows[0]['seed'],'native_raw_sha256':study.sha(raw)})
        study.write(R/'CACHE-BRIDGE.json',{'purpose':'source-recovery diagnostic, not new independent trials','equal_pairs':len(compared),'all_recovered_cells_checked':len(compared)==len(cells),'pairs':compared})
        print('CACHE_BRIDGE_MATCH',len(compared),flush=True)
    elif mode=='remaining':
        bridge=json.loads((R/'CACHE-BRIDGE.json').read_text())
        assert bridge['all_recovered_cells_checked'] and bridge['equal_pairs']==len(cells)
        missing=[s for s in all_specs if s['id'] not in cells]
        assert sum(s['runs'] for s in missing)+sum(c['runs'] for c in cells.values())==1024
        study.write(R/'RESUME-ASSIGNMENT.json',{'status':'fixed missing cells, no final P9 claim','reused_primary_cells':sorted(cells),'new_capture_cells':[s['id'] for s in missing],'total_original_assignment':1024,'new_evaluations':sum(s['runs'] for s in missing),'source_snapshot':'6217709e8f8d74c9ff732ef38a21aab34c5877ef','cache_sha256':study.sha(R/'DURABLE-CACHE.json')})
        study.batch('replication_remaining',missing,workers=4,timeout=1200)
    else:raise SystemExit('bridge|remaining')
if __name__=='__main__':main()
