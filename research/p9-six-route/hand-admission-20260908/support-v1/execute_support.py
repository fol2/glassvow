"""Delivery-only slicing: one unchanged seed per <=120-second native process.

Four fixed-seed results are combined only after each source-bound child validates.
The scientific 128x4 assignment, policies, sampler, engine and decision stay fixed.
"""
from pathlib import Path
import json,sys
import run_support as runner
single=runner.execute

def sliced(cfg,project,engine,out):
    if cfg['runs']==1:return single(cfg,project,engine,out)
    out.mkdir();runner.save(out/'CONFIG.json',cfg)
    children=[];runs=[]
    for offset in range(cfg['runs']):
        child=dict(cfg,seed0=cfg['seed0']+offset,runs=1,id=cfg['id']+'-s'+str(cfg['seed0']+offset))
        folder=out/child['id'];receipt=single(child,project,engine,folder);children.append(receipt)
        if receipt['status']!='COMPLETE':break
        cell=json.loads((folder/'CELL.json').read_bytes());runs.extend(cell['runs'])
    complete=len(runs)==cfg['runs'] and all(r['status']=='COMPLETE' for r in children)
    if complete:runner.save(out/'CELL.json',{'policy_id':cfg['policy_id'],'policy_index':cfg['policy_index'],'vow':cfg['vow'],'route_preference':cfg['route'],'runs':runs})
    result={'status':'COMPLETE' if complete else 'INCONCLUSIVE_CAPTURE','config_id':cfg['id'],'children':children,'seeds_counted_once':[r['seed'] for r in runs],'p9_certified':False}
    runner.save(out/'EXECUTION.json',result)
    return result

if __name__=='__main__':
    runner.execute=sliced
    raise SystemExit(runner.main(Path(sys.argv[1]).resolve(),Path(sys.argv[2]).resolve(),Path(sys.argv[3]).resolve(),push='--push' in sys.argv))
