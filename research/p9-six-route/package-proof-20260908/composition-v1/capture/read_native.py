"""Read complete native traces; never turns a differing label into novelty."""
from __future__ import annotations
from pathlib import Path
import hashlib
import json
import sys


def require(ok: bool, reason: str) -> None:
    if not ok:
        raise ValueError(reason)


def key(spec: dict) -> tuple:
    return spec['aspect'],spec['vow'],spec['up'],spec['environment']


def read(path: Path) -> dict:
    data=path.read_bytes()
    records=[json.loads(line) for line in data.splitlines()]
    require(len(records)==130,'ROW_COUNT')
    require(records[0]['kind']=='header' and records[-1]=={'kind':'summary','rows':128,'failed':False},'TERMINAL')
    header=records[0]
    require(header['content_sha256']=='3c7b2f9dba362d19128ef82ad559d3f26e54925371d823a665767032255eadaa','CONTENT')
    groups={}
    for row in records[1:-1]:
        ident=row['kind'],key(row['spec']),row.get('producer',row.get('expanded'))
        require(ident not in groups,'DUPLICATE')
        groups[ident]=row
        for step in row['steps']:
            require(step['cmd']['t']!='playCard' or step['ret'] is True,'ILLEGAL_COMMAND')
            require(step['after']['queue']==step['before']['queue']+step['events'],'QUEUE_CONSERVATION')
        for a,b in zip(row['steps'],row['steps'][1:]):
            require(a['after']==b['before'],'HIDDEN_STATE_CHANGE')
    facets=[]; cycles=[]
    for aspect in [0,1]:
      for vow in [0,5]:
       for up in [False,True]:
        for env in ['fresh','two_short']:
            k=aspect,vow,up,env
            rows=[groups['facet',k,i] for i in range(3)]
            initial=[r['steps'][0]['before'] for r in rows]
            require(initial[0]==initial[1]==initial[2],'UNEQUAL_INITIAL_STATE')
            views=[r['steps'][0]['view'] for r in rows]
            # Distinguishing observables contain no card names or IDs.
            if aspect==0 and env=='two_short':
                require([v['staggered'] for v in views]==[True,False,False],'NO_STAGGER_DISTINGUISHER')
            if aspect==1:
                require(not any(v['staggered'] for v in views),'ASH_STUN')
            if env=='fresh' or aspect==1:
                require(views[0]['cracked']==0 and all(v['cracked']>0 for v in views[1:]),'NO_CRACKED_DISTINGUISHER')
            facets.append({'aspect':aspect,'vow':vow,'up':up,'environment':env,
                           'producer_views':views,
                           'pre_consumer_echo':[v['staggered'] or v['cracked']>0 for v in views],
                           'full_state_initial_equal':True})
        for env in ['empty','stock','reshuffle','lethal','thorns']:
            k=aspect,vow,up,env
            a,b=groups['cycle',k,False],groups['cycle',k,True]
            require(a['steps']==b['steps'],'UNROLL_CHANGED_FULL_TRACE')
            first=a['steps'][0]
            require(not any(e.get('t')=='draw' and e.get('uid')==900 for e in first['events']),'SELF_DRAW')
            if env in ['lethal','thorns']:
                require(first['view']['over'] and not any(e.get('t')=='draw' for e in first['events']),'DEATH_GUARD')
            if env=='empty':
                require(900 in a['steps'][1]['view']['hand'],'NEXT_TURN_RETURN')
            cycles.append({'aspect':aspect,'vow':vow,'up':up,'environment':env,
                           'full_trace_equal':True,'steps':len(a['steps']),
                           'same_action_self_draw':False,'first_view':first['view']})
    return {'status':'NAMED_FACET_ALIASES_REFUTED_AND_CYCLE_UNROLL_CONFIRMED',
            'raw_bytes':len(data),'raw_sha256':hashlib.sha256(data).hexdigest(),
            'native_run_outcomes':0,'constructed_traces':128,
            'facet_common_contexts':16,'facet_traces':48,
            'cycle_full_trace_equalities':40,'cycle_traces':80,
            'facet':facets,'cycle':cycles,
            'limits':['Refutes exact old-producer aliases in the declared common context, not every closed-family union.',
                      'Counterexamples plus exact source loop expansion, not a newly trained abstract transition model.',
                      'All full states, native events, costs, ordering and RNG are retained in raw.',
                      'No claim that constructed initial chip states occur with adequate natural population support.',
                      'No closed experiment is rerun; no prior terminal or admission metric is changed.'],
            'packages_admitted':0,'p9_certified':False}

if __name__=='__main__':
    if len(sys.argv)!=2:raise SystemExit('usage: read_native.py RAW_NDJSON')
    print(json.dumps(read(Path(sys.argv[1])),indent=2))
