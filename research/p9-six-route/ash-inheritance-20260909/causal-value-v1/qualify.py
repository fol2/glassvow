"""Full-prefix base utility and actual-clone flags; scoped new plumbing proof."""
import copy
import json
from pathlib import Path
from read_causal import require, WORLDS


def source_hp_after(initial_hp):
    """The 3-point self-hit is retained; native lose_combat clamps state HP to zero."""
    require(type(initial_hp) is int and initial_hp > 0, 'INITIAL_HP')
    return max(0, initial_hp - 3)


def records(path):
    data=[json.loads(s) for s in Path(path).read_bytes().splitlines()]
    require(data[-1]=={'kind':'terminal','cases':32} and len(data)==33,'GATE_COVERAGE')
    require([r['index'] for r in data[:-1]]==list(range(32)),'GATE_INDICES')
    return data[:-1]


def erase_added_status(state):
    out=copy.deepcopy(state)
    out['combat']['player']['statuses'].pop('bloodfire',None)
    out['combat']['queue']=[e for e in out['combat']['queue']
                            if not(e.get('t')=='status' and e.get('id')=='bloodfire')]
    return out


def check(folder,reader):
    folder=Path(folder)
    rows={w:records(folder/(w+'.jsonl')) for w in WORLDS}
    clone_count=0
    for world,items in rows.items():
        a,b=[x=='1' for x in world]
        traces=list(reader.stream(folder/(world+'.traces.jsonl')))
        require(len(traces)==96,'THREE_COMMANDS_PER_CASE')
        for r in traces:
            require(r['original_untouched_by_clones'] is True,'FACTUAL_MUTATION')
            if r['card']=='leechBlade':
                reader.clones(r);clone_count+=1
        for row in items:
            k=row['index'];before=row['before'];source=row['source_after'];end=row['consumer_after']
            require(row['world']==world and row['flags']=={'producer':a,'consumer':b},'WORLD_FLAGS')
            ref=rows['00'][k]
            require(all(row[n]==ref[n] for n in ('index','aspect','vow','upgraded','initial_hp','enemy_block','before')),'MATCHED_FIXTURE')
            alive=row['initial_hp']>3
            require(source['combat']['player']['hp']==source_hp_after(row['initial_hp']),'BASE_HP_UTILITY')
            require(sum(e['amount'] for e in row['source_events'] if e.get('t')=='hitPlayer' and e.get('source')=='self')==3,'DECLARED_SELF_HIT')
            require(source['combat']['player']['energy']==((3 if row['upgraded'] else 2) if alive else 0),'BASE_ENERGY_UTILITY')
            require(source['return'] is True,'SOURCE_COMMAND_LEGAL')
            expected=int(a and row['aspect']==1 and alive)
            require(source['combat']['player']['statuses'].get('bloodfire',0)==expected,'SOURCE_MEDIATOR')
            require(erase_added_status(source)==erase_added_status(ref['source_after']),'SOURCE_BASE_EFFECTS_CHANGED')
            require(source==rows[world[0]+'0'][k]['source_after'],'CONSUMER_FLAG_ALTERS_PRODUCER')
            n=13 if row['upgraded'] else 9
            boost=(12 if row['upgraded'] else 10) if expected and b else 0
            loss=max(0,n+boost-row['enemy_block']) if alive else 0
            require(end['combat']['enemies'][0]['hp']==100-loss,'NATIVE_CONSUMER_PAYOFF')
            require(end['return'] is alive,'CONSUMER_LEGALITY')
            expected_energy=(1 if row['upgraded'] else 0) if alive else 0
            require(end['combat']['player']['energy']==expected_energy,'CONSUMER_COST')
            require(end['combat']['player']['statuses'].get('bloodfire',0)==expected-int(bool(expected and b)),'ONE_STACK_CONSUMPTION')
            if row['aspect']==0:
                require(end==ref['consumer_after'] and row['consumer_events']==ref['consumer_events'],'DUSK_NULL')
            if not a:
                require(end==rows['00'][k]['consumer_after'] and row['consumer_events']==rows['00'][k]['consumer_events'],'ZERO_SOURCE_NULL')
    return {'status':'WHOLE_RUN_ABLATION_PLUMBING_PASS','constructed_cases':128,'consumer_clone_rectangles':clone_count,
            'base_source_utility':'Lose3HP then gain2/3Energy if alive; no draw. Preserved across all masks.',
            'scope':'New per-world observer/clone routing and complete source prefix separation only; old360-role qualification is not replayed or newly claimed.',
            'new_independent_samples':0,'packages_admitted':0,'p9_certified':False}
