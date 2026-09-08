"""Read the complete fixed validation from committed publications only.

No Godot, raw-event reconstruction, model fitting or new trials. The 320 old
records remain recovered compact primary; the 704 later records remain native-
verified compact primary, not full raw backups. Run from the committed directory.
"""
from pathlib import Path
import collections,hashlib,json,sys
import numpy as np
from scipy.stats import beta
from read_mixed_validation import vectors,predict
C=Path(__file__).resolve().parent
sys.path.insert(0,str(C.parent))
import primary_codec
ROUTES={0:['facet','fervor','cycle'],1:['smolder','hand','cycle']}
ROLES=['chip_supply','echo','multihit','growth','handstock','catalyst']
ANCHOR={0:{'facet':'echo','fervor':'multihit','cycle':'growth'},1:{'smolder':'catalyst','hand':'handstock','cycle':'growth'}}
DESCRIPTOR='2cfe1d8ff00d5ff695664c597be3a93e3960f39732fa049eac82b9397184bab7'

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def interval(w,n,alpha=.05):
    return [0. if w==0 else float(beta.ppf(alpha/2,w,n-w+1)),
            1. if w==n else float(beta.ppf(1-alpha/2,w+1,n-w))]

def load_cells(root=C):
    paths=[root.parent/'closed-primary'/f'PRIMARY-{i:02}.json' for i in range(1,6)]
    later=sorted((root/'primary').glob('*.json'))+sorted((root/'primary').glob('*.ndjson'))
    assert len(later)==16,'Incomplete or unexpected publication files'
    cells={};sources={};old_count=0
    for path in paths+later:
        sources[str(path.relative_to(root.parent))]={'sha256':sha(path),'git_blob':primary_codec.blob(path.read_bytes())}
        if path in paths:
            obj=primary_codec.load(path)
            assert obj['assigned_runs']==1024 and obj['roles']==ROLES
            assert obj['freeze_sha256']=='6ed125cbf934bdeb3e3037f923e7df0a10d01cf8b1b77971cf54bc90b55ec43e'
            rows=obj['cells'];old_count+=len(rows)
        elif path.suffix=='.ndjson':rows=[json.loads(line) for line in path.read_text().splitlines()]
        else:rows=[json.loads(path.read_text())]
        for c in rows:
            assert c['id'] not in cells,'Duplicate cell'
            cells[c['id']]=c
    expected={f'a{a}-{route}-v{v}-b{b}':(a,v,route,44010000+16*b)
      for a,routes in ROUTES.items() for route in routes+['balanced'] for v in (0,5) for b in range(4)}
    assert old_count==20 and set(cells)==set(expected) and len(cells)==64
    for name,c in cells.items():
        assert tuple(c[k] for k in ('aspect','vow','route','seed0'))==expected[name]
        assert c['runs']==len(c['rows'])==16
        assert len(c['raw_sha256'])==64 and len(c['receipt_sha256'])==64
        for row in c['rows']:vectors(row)
    return cells,sources

def read(root=C):
    p=root.parent/'FROZEN-DESCRIPTOR.json';assert sha(p)==DESCRIPTOR
    model=json.loads(p.read_text())['models'];cells,sources=load_cells(root)
    grouped=collections.defaultdict(list);counts=collections.Counter()
    for c in cells.values():
        for i,row in enumerate(c['rows']):
            grouped[(c['aspect'],c['vow'],c['route'])].append((c['seed0']+i,row))
            counts[row[0]]+=1
    result={'status':'COMPLETE_PUBLISHED_FIXED_VALIDATION_NOT_P9','rows':1024,
      'counts':{k:counts.get(k,0) for k in ('win','loss','stall','error')},'seeds':[44010000,44010063],
      'descriptor_sha256':DESCRIPTOR,'content_sha256':'3c7b2f9dba362d19128ef82ad559d3f26e54925371d823a665767032255eadaa',
      'source_rows':{'recovered_compact_primary':320,'native_verified_compact_primary':704},
      'full_raw_included':False,'sources':sources,'cells':[]}
    confusion={str(a):{r:collections.Counter() for r in routes} for a,routes in ROUTES.items()}
    correct=total=samples=0
    for (a,v,route),items in sorted(grouped.items()):
        items.sort(key=lambda x:x[0]);assert [x[0] for x in items]==list(range(44010000,44010064))
        wins=sum(row[0]=='win' for _,row in items);active=collections.Counter();preds=collections.Counter()
        for _,row in items:
            vec=vectors(row);label=predict(model,a,row);preds[label]+=1;samples+=int(vec[:,0].sum())
            if route in ROUTES[a]:confusion[str(a)][route][label]+=1;correct+=label==route;total+=1
            for j,role in enumerate(ROLES):active[role]+=int(vec[j,1]>0)
        c={'aspect':a,'vow':v,'route':route,'n':64,'wins':wins,'rate':wins/64,
          'nominal_ci95':interval(wins,64),'positive_contribution_runs':dict(active),'predicted':dict(preds)}
        if route in ROUTES[a]:
            c.update(simultaneous_quality_ci95_12=interval(wins,64,.05/12),anchor_role=ANCHOR[a][route],anchor_enactment=active[ANCHOR[a][route]])
        result['cells'].append(c)
    result['classification']={'correct':correct,'total':total,'accuracy':correct/total,'unresolved_is_incorrect':True,
      'scope':'distinguishes predefined controller trajectories, not seven-direction content validity'}
    result['confusion']={a:{r:dict(c) for r,c in m.items()} for a,m in confusion.items()}
    result['sampled_decisions']=samples
    ix=np.random.default_rng(44019999).integers(0,64,size=(10000,64));gaps=[]
    for a,routes in ROUTES.items():
        for v in (0,5):
            control=np.asarray([r[0]=='win' for _,r in grouped[(a,v,'balanced')]],dtype=float)
            for route in routes:
                d=np.asarray([r[0]=='win' for _,r in grouped[(a,v,route)]],dtype=float)-control
                gaps.append({'aspect':a,'vow':v,'route':route,'gap':float(d.mean()),
                  'nominal_cluster_bootstrap95':np.quantile(d[ix].mean(axis=1),[.025,.975]).tolist()})
    result['research_control_gaps']=gaps
    result['limits']=['No model refit, simulated execution or fresh independent confirmation.',
      'A first-seed consistency replay does not recover original native events.',
      'No complete acquisition or factual-event audit can be reconstructed from compact primary.',
      'Research RandomBuild remains distinct from original signed arm2.',
      'No package admission, seven-direction detector, endpoint retention or P9 certificate.']
    return result

if __name__=='__main__':
    result=read();path=C/'PUBLISHED-VALIDATION.json'
    data=json.dumps(result,indent=2)+'\n'
    if path.exists():assert path.read_text()==data,'Existing publication differs; do not overwrite'
    else:path.write_text(data)
    print(result['rows'],result['counts'],result['classification'])
