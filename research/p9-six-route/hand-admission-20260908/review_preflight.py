"""Post-capture author review. Frozen question, raw, probe and first reader stay intact."""
from __future__ import annotations
import json
from pathlib import Path
from read_preflight import require, analyze

CASES={
 'prep_stock':('preparation',5,3,12), 'prep_empty':('preparation',5,3,0),
 'prep_cap':('preparation',10,3,12), 'prep_branch':('preparation',5,3,12),
 'prep_modifiers':('preparation',5,3,12), 'prep_lethal':('preparation',5,3,12),
 'surge_energy':('surge',6,0,12), 'surge_access':('surge',6,0,12),
 'surge_empty':('surge',6,0,0), 'surge_branch':('surge',6,0,12), 'surge_spare':('surge',6,3,12)}

def review(raw: bytes, protocol: dict) -> dict:
    # The first reader remains frozen; this adds missing binding checks rather than relaxing it.
    result=analyze(raw,protocol)
    records=[json.loads(x) for x in raw.splitlines()]
    rows=[x for x in records if x['kind']=='row']
    native={tuple(r['spec'][k] for k in ('aspect','vow','up','label')):r for r in rows if r['mask']==-1}
    effects=0
    for row in rows:
        sp=row['spec'];label=sp['label'];key=tuple(sp[k] for k in ('aspect','vow','up','label'))
        require(type(row['mask']) is int,'mask type')
        if label.startswith('q_'):expected=('',int(label[2:])+1,3,12)
        else:expected=CASES[label]
        require(set(sp)=={'aspect','vow','up','label','producer','hand','energy','draw'},'spec schema')
        require(tuple(sp[k] for k in ('producer','hand','energy','draw'))==expected,'full fixture binding')
        require(row['initial']==native[key]['initial'],'matched common initial state')
        for step in row['steps']:
            command=step['command']
            if command.get('uid') not in (900,901) or not step['permitted']:continue
            if command['uid']==900:
                if row['mask']>=0:
                    expected_order=['draw'] if sp['producer']=='preparation' else ['energy','draw']
                    require([o.get('effect',{}).get('kind') for o in step['observations']]==expected_order,'supplier observation coverage/order')
                require(command['target'] is None,'producer target')
                start=step['before_view']['hand'].copy();start.remove(900)
                energy=step['before_view']['energy']
                for ob in step['observations']:
                    require(ob['kind']=='effect' and ob['uid']==900 and ob['card']==sp['producer'],'supplier identity')
                    fx=ob['effect'];kind=fx['kind'];count=fx['n']
                    require((sp['producer']=='preparation' and fx=={'kind':'draw','n':3 if sp['up'] else 2}) or
                            (sp['producer']=='surge' and fx in ({'kind':'draw','n':1},{'kind':'energy','n':2 if sp['up'] else 1})), 'supplier definition')
                    require(ob['before_hand']==start and ob['before_energy']==energy,'inter-effect continuity')
                    if not ob['suppressed']:
                        if kind=='draw':
                            # Exact emitted UID additions, including a consumer drawn into hand.
                            delta=ob['after_hand'][len(start):]
                            require(ob['after_hand'][:len(start)]==start and len(delta)<=count,'draw topology')
                            start=ob['after_hand']
                        if kind=='energy':energy+=count
                    require(ob['after_energy']==energy and ob['after_hand']==start,'effect accounting')
                    effects+=1
            else:
                require(command['target']==0,'consumer target')
                if row['mask']>=0:
                    p=[ob for ob in step['observations'] if ob['kind']=='phantom']
                    require(len(p)==1 and p[0]['target']==0,'consumer observation coverage')
    require(result['status']=='HAND_COMPONENT_OBSERVATION_PREFLIGHT_PASS','frozen verdict')
    return {'status':'AUTHOR_REVIEW_PASS_FOR_HAND_PREFLIGHT_ONLY','kind':'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT',
            'rows_bound':len(rows),'supplier_effect_records_checked':effects,
            'frozen_reader_unchanged':True,'new_native_runs':0,'new_independent_samples':0,'p9_certified':False,
            'findings_fixed_by_additional_checks':['Require exact fixture metadata, integer mask and common initial state for every Ash intervention arm.',
              'Bind source-specific supplier definitions, UID, target, stock and Energy effect transitions; require one Phantom observation when legal.'],
            'limits':['This is not trusted-runtime provenance, all-supplier exhaustiveness, population admission or an independent reviewer verdict.']}

if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser();p.add_argument('raw',type=Path);p.add_argument('protocol',type=Path);a=p.parse_args()
    print(json.dumps(review(a.raw.read_bytes(),json.loads(a.protocol.read_bytes())),indent=2))
