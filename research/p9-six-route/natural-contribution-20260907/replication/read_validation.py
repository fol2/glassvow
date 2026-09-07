"""Fixed held-out readout: all runs retained; no post-result model fitting."""
from pathlib import Path
import collections,copy,hashlib,json,sys
import numpy as np
from scipy.stats import beta
import descriptor
R=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(R))
import read_causal as audit
ROUTES=descriptor.ROUTES
ANCHOR={0:{'facet':'echo','fervor':'multihit','cycle':'growth'},1:{'smolder':'catalyst','hand':'handstock','cycle':'growth'}}
def interval(w,n,alpha=.05):
    return [0.0 if w==0 else float(beta.ppf(alpha/2,w,n-w+1)),
            1.0 if w==n else float(beta.ppf(1-alpha/2,w+1,n-w))]
def read():
    p=Path(__file__).with_name('FROZEN-DESCRIPTOR.json')
    assert audit.sha(p)=='2cfe1d8ff00d5ff695664c597be3a93e3960f39732fa049eac82b9397184bab7'
    model=json.loads(p.read_text())['models']
    folder=R/'study/studies/causal_replication'
    freeze,records,counts=audit.reconcile(folder)
    grouped=collections.defaultdict(list);binding={};total_samples=0;primary=[]
    for name,(spec,rows,receipt) in records.items():
        key=(spec['aspect'],spec['vow'],spec['route'])
        grouped[key].extend(rows);binding[name]=receipt['output_sha256']
    assert len(grouped)==16 and sum(counts.values())==1024
    result={'status':'HELD_OUT_TRACE_AND_QUALITY_VALIDATION_NOT_P9','rows':1024,
      'counts':{k:counts.get(k,0) for k in ('win','loss','stall','error')},
      'seeds':[44010000,44010063],'clusters':64,'content_sha256':'3c7b2f9dba362d19128ef82ad559d3f26e54925371d823a665767032255eadaa',
      'freeze_sha256':audit.sha(folder/'freeze.json'),'descriptor_sha256':audit.sha(p),
      'quality_interval':'Clopper-Pearson, alpha=.05/12 for the12 core cells; simultaneous coverage by union bound under binomial seed-sampling model',
      'cells':[],'confusion':{},'primary_columns':['aspect','vow','route','seed','win','predicted_label','combats','sparse_role_vectors'],
      'vector_columns':['role_index','samples','consumer_positive','consumer_negative','consumer_effect','mediator_effect','interaction'],
      'roles':descriptor.ROLES,'raw_sha256':binding}
    correct=total=0
    confusion={str(a):{r:collections.Counter() for r in labels} for a,labels in ROUTES.items()}
    for (a,v,route),items in sorted(grouped.items()):
        items.sort(key=lambda r:r['seed']);assert [r['seed'] for r in items]==list(range(44010000,44010064))
        wins=sum(r['result']=='win' for r in items);active=collections.Counter();preds=collections.Counter()
        for row in items:
            prediction=descriptor.predict(model,row);preds[prediction]+=1
            if route in ROUTES[a]:
                confusion[str(a)][route][prediction]+=1
                correct+=prediction==route;total+=1
            # Verify identifiers, outcome and seed cannot alter predictions.
            mutant=copy.deepcopy(row);mutant['route']='erased';mutant['seed']=-1;mutant['result']='erased'
            for q in mutant['causal_samples']:q['card']='erased'
            assert descriptor.predict(model,mutant)==prediction
            vectors=np.zeros((6,6),dtype=np.int64)
            for q in row['causal_samples']:
                j=descriptor.ROLES.index(q['role']);d=descriptor.DIM[j];arms=q['arms']
                dc=arms[3][d]-arms[2][d];dm=arms[3][d]-arms[1][d];inter=dc-arms[1][d]+arms[0][d]
                vectors[j]+=np.asarray([1,int(dc>0),int(dc<0),dc,dm,inter])
                total_samples+=1
            for j,role in enumerate(descriptor.ROLES):active[role]+=int(vectors[j,1]>0)
            sparse=[[j,*vec.tolist()] for j,vec in enumerate(vectors) if np.any(vec)]
            primary.append([a,v,route,row['seed'],int(row['result']=='win'),prediction,len(row['fights']),sparse])
        cell={'aspect':a,'vow':v,'route':route,'n':64,'wins':wins,'rate':wins/64,
              'nominal_ci95':interval(wins,64),'positive_contribution_runs':dict(active),'predicted':dict(preds)}
        if route in ROUTES[a]:
            cell['simultaneous_quality_ci95_12']=interval(wins,64,.05/12)
            anchor=ANCHOR[a][route];cell['anchor_role']=anchor;cell['anchor_enactment']=active[anchor]
        result['cells'].append(cell)
    result['confusion']={a:{r:dict(c) for r,c in m.items()} for a,m in confusion.items()}
    result['classification']={'correct':correct,'total':total,'accuracy':correct/total,'unresolved_is_incorrect':True,'scope':'distinguishes predefined controller trajectories, not seven-direction content validity'}
    result['sampled_decisions']=total_samples
    # Same seed indexes stay paired; intervals resample entire seeds, never individual probes.
    rng=np.random.default_rng(44019999);indices=rng.integers(0,64,size=(10000,64));gaps=[]
    for a,labels in ROUTES.items():
        for v in (0,5):
            control=np.asarray([r['result']=='win' for r in sorted(grouped[(a,v,'balanced')],key=lambda r:r['seed'])],dtype=float)
            for route in labels:
                y=np.asarray([r['result']=='win' for r in sorted(grouped[(a,v,route)],key=lambda r:r['seed'])],dtype=float)
                d=y-control;b=d[indices].mean(axis=1)
                gaps.append({'aspect':a,'vow':v,'route':route,'gap':float(d.mean()),'nominal_cluster_bootstrap95':np.quantile(b,[.025,.975]).tolist()})
    result['research_control_gaps']=gaps
    result['limits']=['No content or policy retuning on this cohort; earlier training rows remain separate.',
      'Binomial/cluster inference assumes the assigned seed sample represents the intended run distribution.',
      'A named policy is not an admitted package; local effects and whole-run viability are distinct.',
      'The predictor sees causal-role frequencies, not seven causal content-mutation classes.',
      'Balanced research control is not signed arm2. No acceptance threshold is relaxed.',
      'No unrestricted optimisation, detector admission, lifecycle or exact product integration.']
    audit.write(folder/'VALIDATION.json',result)
    audit.write(folder/'VALIDATION-PRIMARY.json',{'roles':descriptor.ROLES,'columns':result['primary_columns'],'vector_columns':result['vector_columns'],'rows':primary})
    print('VALIDATION',counts,'fingerprint',correct,total)
    for c in result['cells']:print(c['aspect'],c['vow'],c['route'],c['wins'],c.get('anchor_enactment'),c['predicted'])
if __name__=='__main__':read()
