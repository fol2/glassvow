"""Frozen validation over explicit compact/native sources; never fit or extend N.

The compact features/predictions are checked against the unchanged native
implementation for every newly captured row. Old raw/acquisition is not invented.
"""
from pathlib import Path
import collections,copy,hashlib,json,sys
import numpy as np
R=Path(__file__).resolve().parent


def vectors(compact):
    out=np.zeros((6,6),dtype=np.int64);seen=set()
    assert compact[0] in ('win','loss','stall','error') and isinstance(compact[1],int) and compact[1]>=0
    for sparse in compact[2]:
        assert len(sparse)==7
        j=sparse[0];assert 0<=j<6 and j not in seen;seen.add(j)
        assert all(isinstance(x,int) for x in sparse)
        out[j]=sparse[1:]
        assert out[j,0]>=out[j,1]+out[j,2]>=0 and out[j,1]>=0 and out[j,2]>=0
    return out

def feature(compact):
    v=vectors(compact)
    return np.concatenate([v[:,0],v[:,1]-v[:,2]]).astype(float)/max(1,compact[1])

def predict(model,aspect,compact):
    m=model[str(aspect)];f=feature(compact)
    if not np.any(f[6:]>0):return 'unresolved_no_positive_contribution'
    d=((np.asarray(m['centroids'])-f/np.asarray(m['scale']))**2).sum(axis=1)
    return m['labels'][int(np.argmin(d))]

def read():
    sys.path.insert(0,str(R/'replication'))
    import descriptor,read_validation as frozen
    import resume_validation as resume
    import checkpoint_closed as checkpoint
    import read_causal as audit
    descriptor_path=R/'replication/FROZEN-DESCRIPTOR.json'
    assert audit.sha(descriptor_path)=='2cfe1d8ff00d5ff695664c597be3a93e3960f39732fa049eac82b9397184bab7'
    model=json.loads(descriptor_path.read_text())['models']
    old=resume.cache();folder=R/'study/studies/replication_remaining'
    freeze,records,native_counts=audit.reconcile(folder)
    checked=checkpoint.build(folder,list(records));new=checked['cells']
    assert not set(old)&set(new)
    cells={**old,**new};specs={s['id']:s for s in resume.fixed.panel()}
    assert set(cells)==set(specs) and len(cells)==64
    assert sum(c['runs'] for c in old.values())==320 and sum(c['runs'] for c in new.values())==704
    parity=0
    for name,(spec,rows,receipt) in records.items():
        for i,row in enumerate(rows):
            compact=new[name]['rows'][i]
            assert np.array_equal(feature(compact),descriptor.feature(row))
            pred=predict(model,spec['aspect'],compact)
            assert pred==descriptor.predict(model,row)
            mutant=copy.deepcopy(row);mutant.update(route='erased',seed=-1,result='erased')
            for q in mutant['causal_samples']:q['card']='erased'
            assert descriptor.predict(model,mutant)==pred
            parity+=1
    assert parity==704
    grouped=collections.defaultdict(list);counts=collections.Counter();primary=[];total_samples=0
    binding={}
    for name,c in cells.items():
        spec=specs[name]
        assert all(c[k]==spec[k] for k in ('id','aspect','vow','route','seed0','runs'))
        assert len(c['rows'])==c['runs']==16
        binding[name]={'source':'new_native_capture' if name in new else 'recovered_compact_primary',
          'raw_sha256':c['raw_sha256'],'receipt_sha256':c.get('receipt_sha256')}
        for i,row in enumerate(c['rows']):
            vectors(row);counts[row[0]]+=1
            grouped[(c['aspect'],c['vow'],c['route'])].append((c['seed0']+i,row,name))
    assert len(grouped)==16 and sum(counts.values())==1024
    result={'status':'HELD_OUT_TRACE_AND_QUALITY_VALIDATION_NOT_P9','rows':1024,
      'counts':{k:counts.get(k,0) for k in ('win','loss','stall','error')},'seeds':[44010000,44010063],'clusters':64,
      'content_sha256':'3c7b2f9dba362d19128ef82ad559d3f26e54925371d823a665767032255eadaa',
      'descriptor_sha256':audit.sha(descriptor_path),'native_freeze_sha256':audit.sha(folder/'freeze.json'),
      'recovered_cache_sha256':audit.sha(R/'DURABLE-CACHE.json'),
      'source_rows':{'recovered_compact_primary':320,'new_native_capture':704},
      'compact_native_estimator_parity_rows':parity,'raw_sha256':binding,
      'quality_interval':'Clopper-Pearson, alpha=.05/12 for the 12 core cells; simultaneous coverage by union bound under binomial seed-sampling model',
      'roles':descriptor.ROLES,'cells':[],'confusion':{},
      'primary_columns':['aspect','vow','route','seed','win','predicted_label','combats','sparse_role_vectors'],
      'vector_columns':['role_index','samples','consumer_positive','consumer_negative','consumer_effect','mediator_effect','interaction']}
    correct=total=0
    confusion={str(a):{r:collections.Counter() for r in labels} for a,labels in descriptor.ROUTES.items()}
    for (a,v,route),items in sorted(grouped.items()):
        items.sort(key=lambda x:x[0]);assert [x[0] for x in items]==list(range(44010000,44010064))
        wins=sum(x[1][0]=='win' for x in items);active=collections.Counter();preds=collections.Counter()
        for seed,row,name in items:
            pred=predict(model,a,row);preds[pred]+=1;vec=vectors(row)
            if route in descriptor.ROUTES[a]:
                confusion[str(a)][route][pred]+=1;correct+=pred==route;total+=1
            total_samples+=int(vec[:,0].sum())
            for j,role in enumerate(descriptor.ROLES):active[role]+=int(vec[j,1]>0)
            primary.append([a,v,route,seed,int(row[0]=='win'),pred,row[1],row[2]])
        cell={'aspect':a,'vow':v,'route':route,'n':64,'wins':wins,'rate':wins/64,
          'nominal_ci95':frozen.interval(wins,64),'positive_contribution_runs':dict(active),'predicted':dict(preds)}
        if route in descriptor.ROUTES[a]:
            cell['simultaneous_quality_ci95_12']=frozen.interval(wins,64,.05/12)
            cell['anchor_role']=frozen.ANCHOR[a][route];cell['anchor_enactment']=active[cell['anchor_role']]
        result['cells'].append(cell)
    result['confusion']={a:{r:dict(c) for r,c in m.items()} for a,m in confusion.items()}
    result['classification']={'correct':correct,'total':total,'accuracy':correct/total,'unresolved_is_incorrect':True,
      'scope':'distinguishes predefined controller trajectories, not seven-direction content validity'}
    result['sampled_decisions']=total_samples
    rng=np.random.default_rng(44019999);indices=rng.integers(0,64,size=(10000,64));gaps=[]
    for a,labels in descriptor.ROUTES.items():
        for v in (0,5):
            control=np.asarray([x[1][0]=='win' for x in grouped[(a,v,'balanced')]],dtype=float)
            for route in labels:
                y=np.asarray([x[1][0]=='win' for x in grouped[(a,v,route)]],dtype=float)
                d=y-control;b=d[indices].mean(axis=1)
                gaps.append({'aspect':a,'vow':v,'route':route,'gap':float(d.mean()),
                  'nominal_cluster_bootstrap95':np.quantile(b,[.025,.975]).tolist()})
    result['research_control_gaps']=gaps
    acq=collections.defaultdict(lambda:{'native_rows':0,'offered':collections.Counter(),'picked':collections.Counter(),'played':collections.Counter()})
    for name,rows in checked['acquisition'].items():
        c=new[name];k=f"a{c['aspect']}-{c['route']}-v{c['vow']}";acq[k]['native_rows']+=len(rows)
        for row in rows:
            for field in ('offered','picked','played'):acq[k][field].update(row[field])
    result['natural_acquisition']={'covered_native_rows':704,'unavailable_original_rows':320,
      'limits':'Counts only newly captured rows; not extrapolated to old compact records. Normal acquisition paths, no injected ideal decks.',
      'cells':dict(acq)}
    result['limits']=['No content or policy retuning, model refit, selection on partial chunks, or sample-size extension.',
      'Reproduced previously exposed assignments are not fresh independent confirmation.',
      'First-seed cache replay is consistency evidence, not recovery of all original raw events.',
      'Native captures exist for 704 rows; only sufficient statistics remain for 320 original rows.',
      'Inference assumes assigned seed clusters represent the intended run distribution.',
      'Local contribution, trajectory recognition and whole-run viability are different claims.',
      'Balanced research controls do not replace signed arm2; no P9 threshold is inferred or relaxed.',
      'No package admission, seven-direction detector, endpoint retention, lifecycle or product integration.']
    out=R/'mixed';out.mkdir(exist_ok=True)
    audit.write(out/'VALIDATION.json',result)
    audit.write(out/'VALIDATION-PRIMARY.json',{'roles':descriptor.ROLES,'columns':result['primary_columns'],
      'vector_columns':result['vector_columns'],'rows':primary})
    print('VALIDATION',dict(counts),'fingerprint',correct,total,'sampled',total_samples)
    for c in result['cells']:print(c['aspect'],c['vow'],c['route'],c['wins'],c.get('anchor_enactment'),c['predicted'])
if __name__=='__main__':read()
