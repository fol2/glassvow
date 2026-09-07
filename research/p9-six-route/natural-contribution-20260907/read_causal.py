"""Reconcile native captures; explicitly separate outcomes from sampled causal vectors."""
from pathlib import Path
import copy,hashlib,json,re,sys,collections
R=Path(__file__).resolve().parent
ROLES=['chip_supply','echo','multihit','growth','handstock','catalyst']
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def write(p,obj):Path(p).write_text(json.dumps(obj,indent=2)+'\n')
def rows(path):return [json.loads(x) for x in path.read_text().splitlines()]
def reconcile(folder):
    freeze=json.loads((folder/'freeze.json').read_text()); records={}; total=collections.Counter()
    for spec in freeze['specs']:
        name=spec['id']; receipt=json.loads((folder/f'{name}.receipt.json').read_text())
        data=rows(folder/f'{name}.ndjson'); manifest,items=data[0],data[1:]
        assert receipt['complete'] and receipt['exit_code']==0 and not receipt['diagnostics']
        for ext,key in [('.ndjson','output_sha256'),('.log','log_sha256'),('.json','config_sha256')]:
            assert sha(folder/f'{name}{ext}')==receipt[key]
        assert receipt['spec']==spec and receipt['observer']==freeze['observer']
        assert receipt['content_sha256']==freeze['observer']['content_files'][spec['content_path']]
        assert manifest['config']==spec
        assert [int(r['seed']) for r in items]==list(range(spec['seed0'],spec['seed0']+spec['runs']))
        for row in items:
            assert row['result'] in ('win','loss','stall','error')
            assert all(row[k]==spec[k] for k in ('aspect','vow','route','random_build'))
            seen=set()
            for sample in row.get('causal_samples',[]):
                kind=sample['role']; assert kind in ROLES
                key=(sample['fight'],kind,sample['mediator']>0)
                assert key not in seen;seen.add(key)
                a=sample['arms']; assert len(a)==4 and all(len(v)==4 for v in a)
                assert sample['interaction']==[a[3][i]-a[2][i]-a[1][i]+a[0][i] for i in range(4)]
                assert re.fullmatch(r'[0-9a-f]{64}',sample['before'])
            total[row['result']]+=1
        records[name]=(spec,items,receipt)
    return freeze,records,dict(total)
def strip_observation(row):
    row=copy.deepcopy(row);row.pop('causal_samples',None)
    for container in [row]+row['fights']:
        container['mechanism']={k:v for k,v in container['mechanism'].items() if not k.startswith('probe_eligible:')}
    return row
def parity(folder):
    freeze,records,counts=reconcile(folder);pairs=[]
    for name,(spec,items,receipt) in records.items():
        if spec['causal_probe']:
            control=records[name[:-1]+'0'];assert len(items)==1
            assert strip_observation(items[0])==strip_observation(control[1][0]),name
            pairs.append({'id':name[:-7], 'observed_sha':receipt['output_sha256'],
                          'control_sha':control[2]['output_sha256'], 'samples':len(items[0]['causal_samples'])})
    result={'status':'OBSERVATIONAL_PARITY_NOT_P9','equal_pairs':len(pairs),'all_complete':len(pairs)==18,
            'rows':sum(counts.values()),'counts':counts,'freeze_sha256':sha(folder/'freeze.json'),'pairs':pairs}
    write(folder/'PARITY.json',result); print(json.dumps({k:v for k,v in result.items() if k!='pairs'},indent=2))
def readout(folder):
    freeze,records,counts=reconcile(folder)
    table=[];primary=[]; samples_total=0
    for name,(spec,items,receipt) in records.items():
        effect_runs={k:0 for k in ROLES}; positive_runs={k:0 for k in ROLES};totals={k:[0]*4 for k in ROLES}
        sampled={k:0 for k in ROLES};eligible={k:0 for k in ROLES}
        for row in items:
            by={k:[0]*4 for k in ROLES};ns={k:0 for k in ROLES};ne={k:0 for k in ROLES};np={k:0 for k in ROLES}
            for sample in row['causal_samples']:
                k=sample['role'];sampled[k]+=1;ns[k]+=1;samples_total+=1
                # Keep signed effects; zero-mediator and saturation outcomes are not removed.
                for j,v in enumerate(sample['interaction']):totals[k][j]+=v;by[k][j]+=v
                target=3 if k=='chip_supply' else (2 if k=='catalyst' else 0)
                if sample['interaction'][target]!=0:ne[k]+=1
                if sample['interaction'][target]>0:np[k]+=1
            for k in ROLES:
                eligible[k]+=int(row['mechanism'].get('probe_eligible:'+k,0))
                effect_runs[k]+=int(ne[k]>0);positive_runs[k]+=int(np[k]>0)
            # Primary sufficient per-run statistics: sampling counts and all four signed effect sums.
            primary.append([name,row['seed'],int(row['result']=='win'),
                [[ns[k],ne[k],np[k],*by[k]] for k in ROLES]])
        table.append({'id':name,'n':len(items),'wins':sum(r['result']=='win' for r in items),
            'raw_sha256':receipt['output_sha256'],'effect_runs':effect_runs,'positive_runs':positive_runs,
            'sampled':sampled,'eligible':eligible,'sum_interaction':totals})
    report={'status':'NATURAL_STATE_DIAGNOSTIC_NOT_P9','rows':sum(counts.values()),'counts':counts,
      'sampled_decisions':samples_total,'counterfactual_executions':4*samples_total,
      'roles':ROLES,'dimensions':['actual_hp_removed','nominal_hit_damage','net_poison','shatters'],
      'freeze_sha256':sha(folder/'freeze.json'),'cells':table,
      'limits':['Stratified first zero/positive sample per role per combat, not all action average.',
        'Post-decision exact-state intervention, not policy adaptation or whole-run treatment effect.',
        'Repeated samples within a run are not independent observations.',
        'Poison and immediate HP are not converted into a common utility.',
        'No package, detector, retention, signed-arm or P9 admission.']}
    write(folder/'RESULTS.json',report)
    write(folder/'PRIMARY.json',{'roles':ROLES,'columns':['cell','seed','win','role_vectors'],
         'role_columns':['sample_count','effect_sample_count','positive_sample_count','hp_interaction_sum','nominal_interaction_sum','poison_interaction_sum','shatter_interaction_sum'], 'rows':primary})
    print('AUDIT',report['rows'],counts,'sampled',samples_total)
    for cell in table:
        print(cell['id'],cell['wins'], '/',cell['n'],'positive',list(cell['positive_runs'].values()))
if __name__=='__main__':
    mode=sys.argv[1];folder=Path(sys.argv[2]);(parity if mode=='parity' else readout)(folder)
