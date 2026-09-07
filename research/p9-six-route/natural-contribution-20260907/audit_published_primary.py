"""Recompute the frozen fingerprint from remotely preservable sufficient statistics.

This verifies statistical reproducibility, not the provenance of native captures.
No simulator execution, candidate selection or protected cohort is performed.
"""
from pathlib import Path
import hashlib,json,sys
import numpy as np
R=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else Path(__file__).resolve().parent
LABELS={0:['facet','fervor','cycle'],1:['smolder','hand','cycle']}
def load(name):return json.loads((R/name).read_text())
def h(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def reconstruct():
    support=load('TRAINING-SUPPORT.json');observed=[];total=0
    for aspect in (0,1):
        primary=load(f'PRIMARY-A{aspect}.json')
        assert primary['roles']==support['roles'] and primary['n_per_cell']==16
        for cell,raw_hash,rows in primary['cells']:
            extra=support['cells'][cell]
            assert extra['raw_sha256']==raw_hash and len(rows)==len(extra['combats'])==16
            assert sum(row[0] for row in rows)==extra['wins']
            for index,((win,sparse),combats) in enumerate(zip(rows,extra['combats'])):
                assert win in (0,1) and isinstance(combats,int) and combats>=1
                f=np.zeros(12);seen=set()
                for j,n,pos,neg,dc,dm,inter in sparse:
                    assert j not in seen and 0<=j<6;seen.add(j)
                    assert 0<=pos+neg<=n<=2*combats
                    f[j]=n;f[j+6]=pos-neg
                observed.append((aspect,extra['route'],f/max(1,combats)))
                total+=1
    assert total==288
    model={}
    for aspect,labels in LABELS.items():
        chosen=[(route,f) for a,route,f in observed if a==aspect and route in labels]
        x=np.asarray([f for _,f in chosen]);scale=np.maximum(x.std(axis=0),.05)
        means=[np.mean([f/scale for route,f in chosen if route==label],axis=0).tolist() for label in labels]
        model[str(aspect)]={'labels':labels,'scale':scale.tolist(),'centroids':means}
    model_path=R/'replication/FROZEN-DESCRIPTOR.json'
    if not model_path.is_file():model_path=R/'FROZEN-DESCRIPTOR.json'
    expected=json.loads(model_path.read_text())
    assert model==expected['models'],'Frozen model differs from published sufficient statistics'
    return {'status':'PUBLISHED_STATISTICS_RECOMPUTE_PASS_NOT_P9','run_records':total,
      'training_records':192,'models_exact_equal':True,'descriptor_sha256':h(model_path),
      'inputs':{name:h(R/name) for name in ('PRIMARY-A0.json','PRIMARY-A1.json','TRAINING-SUPPORT.json')},
      'boundary':'Per-run contribution and combat-count statistics reproduce the fitted model. Native event/clone correctness still requires original captures and tests.'}
if __name__=='__main__':
    result=reconstruct();text=json.dumps(result,indent=2)+'\n'
    (R/'STATISTICS-AUDIT.json').write_text(text);print(text,end='')
