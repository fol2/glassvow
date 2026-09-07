"""A frozen trace fingerprint diagnostic, not a seven-direction P9 detector.

Nearest centroids use only actual post-decision contribution occurrences and
sampling counts per combat. No win, policy label, card ID, seed or vow is an input.
"""
from pathlib import Path
import hashlib,json,math,sys
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
import read_causal
ROUTES={0:['facet','fervor','cycle'],1:['smolder','hand','cycle']}
ROLES=read_causal.ROLES
DIM=[3,0,0,0,0,2]
def feature(row):
    f=np.zeros(12,dtype=float)
    for item in row['causal_samples']:
        k=ROLES.index(item['role']);a=item['arms'];delta=a[3][DIM[k]]-a[2][DIM[k]]
        f[k]+=1;f[k+6]+=float(delta>0)-float(delta<0)
    return f/max(1,len(row['fights']))
def fit(data):
    model={}
    for aspect,labels in ROUTES.items():
        chosen=[r for r in data if r['aspect']==aspect and r['route'] in labels and not r['random_build']]
        x=np.asarray([feature(r) for r in chosen]);scale=x.std(axis=0)
        scale=np.maximum(scale,.05)
        means=[np.mean([feature(r)/scale for r in chosen if r['route']==label],axis=0).tolist() for label in labels]
        model[str(aspect)]={'labels':labels,'scale':scale.tolist(),'centroids':means}
    return model
def predict(model,row):
    m=model[str(row['aspect'])];f=feature(row)
    if not np.any(f[6:]>0):return 'unresolved_no_positive_contribution'
    d=((np.asarray(m['centroids'])-f/np.asarray(m['scale']))**2).sum(axis=1)
    return m['labels'][int(np.argmin(d))]
def load(folder):
    _,records,_=read_causal.reconcile(Path(folder))
    return [r for _,rows,_ in records.values() for r in rows]
if __name__=='__main__':
    train=ROOT/'study/studies/causal_screen';rows=load(train);model=fit(rows)
    out={'purpose':'frozen fingerprint predictor, not P9 detector admission',
      'training_freeze':read_causal.sha(train/'freeze.json'),
      'training_scope':'all predeclared core-route records including losses; earlier exploration',
      'features':['samples_per_combat:'+k for k in ROLES]+['signed_positive_frequency_per_combat:'+k for k in ROLES],
      'algorithm':'nearest centroid, training population standard deviation floor .05; zero positive contributions => unresolved',
      'excluded_inputs':['route','win','seed','vow','card_id'],'models':model}
    path=Path(__file__).with_name('FROZEN-DESCRIPTOR.json');read_causal.write(path,out)
    # Leave-one-seed-cluster-out is a training diagnostic, not the new holdout.
    correct=total=0
    for seed in sorted({r['seed'] for r in rows}):
        fold=fit([r for r in rows if r['seed']!=seed])
        for r in rows:
            if r['seed']==seed and r['route'] in ROUTES[r['aspect']] and not r['random_build']:
                correct+=predict(fold,r)==r['route'];total+=1
    read_causal.write(path.with_name('TRAINING-CHECK.json'),{'status':'TRAINING_ONLY','correct':correct,'total':total,'accuracy':correct/total,'model_sha256':read_causal.sha(path)})
    print('FROZEN_MODEL',read_causal.sha(path),'LOSO',correct,total)
