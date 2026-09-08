"""Verify the complete frozen Hand preflight. No simulator or statistical inference."""
from __future__ import annotations
import hashlib
import json
from pathlib import Path

CONTENT = '3c7b2f9dba362d19128ef82ad559d3f26e54925371d823a665767032255eadaa'
COMBAT = 'a6fd99eb53030d3cf1401153bdeceec8b86ccc2af8b7643481855c681906f2ba'
LABELS = ('prep_stock','prep_empty','prep_cap','prep_branch','prep_modifiers','prep_lethal',
          'surge_energy','surge_access','surge_empty','surge_branch','surge_spare')

def require(ok: bool, why: str) -> None:
    if not ok:
        raise ValueError(why)

def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def project_view(state: dict) -> dict:
    # Resolve the actual reflected object graph, not a second convenience view.
    objects = {}
    def index(v):
        if isinstance(v, dict):
            if 'object' in v:
                require(v['object'] not in objects, 'duplicate object id')
                objects[v['object']] = v
            for item in v.values(): index(item)
        elif isinstance(v, list):
            for item in v: index(item)
    index(state['future'])
    def resolve(v):
        return objects[v['ref']] if isinstance(v,dict) and set(v)=={'ref'} else v
    run,cb,_ = [resolve(x) for x in state['future']]
    player = resolve(cb['player']); enemy=resolve(cb['enemies'][0])
    return {'hand':[resolve(c)['uid'] for c in cb['hand']], 'energy':player['energy'],
            'turn':cb['turn'], 'hp':enemy['hp'], 'block':enemy['block'], 'over':cb['over'],
            'rng':run['rng']['rng_state'], 'player_hp':player['hp']}

def signature(row: dict) -> list:
    return [row['initial'], *[(s['permitted'],s['before'],s['after'],s['events'],s['last_ret']) for s in row['steps']]]

def consumer(row: dict) -> dict:
    return next(s for s in row['steps'] if s['command'].get('uid')==901)

def analyze(raw: bytes, protocol: dict) -> dict:
    records=[json.loads(x) for x in raw.splitlines()]
    require(records and records[0]['kind']=='header' and records[-1]['kind']=='summary','envelope')
    header=records[0]; tail=records[-1]
    require(header['content_sha256']==CONTENT and header['combat_sha256']==COMBAT,'candidate binding')
    require(header['rules_sha256']==protocol['source_sha256']['hand_rules.gd'],'intervention binding')
    require(header['probe_sha256']==protocol['source_sha256']['preflight.gd'],'probe binding')
    require(header['engine']['string']=='4.7.2-stable (official)','official engine')
    states={}; rows={}; observed_views=0; observed_effects=0; blocked=0
    for rec in records[1:-1]:
        if rec['kind']=='state':
            require(rec['sha256']==sha(rec['serialized'].encode()),'state byte hash')
            require(rec['sha256'] not in states,'duplicate state')
            states[rec['sha256']]=json.loads(rec['serialized'])
            continue
        require(rec['kind']=='row','unknown raw record')
        sp=rec['spec']; mask=rec['mask']; key=(sp['aspect'],sp['vow'],sp['up'],sp['label'],mask)
        require(type(sp['up']) is bool and key not in rows,'duplicate/context')
        require(key[0] in (0,1) and key[1] in (0,5),'aspect/vow')
        previous=rec['initial']; rows[key]=rec
        require(previous in states,'unretained initial')
        expected_commands=([900] if sp['producer'] else [])+[901,None]
        require([s['command'].get('uid') for s in rec['steps']]==expected_commands,'command coverage')
        for step in rec['steps']:
            require(step['before']==previous and step['after'] in states,'state continuity')
            b,a=states[step['before']],states[step['after']]
            require(step['before_view']==project_view(b) and step['after_view']==project_view(a),'unfaithful view')
            observed_views+=2
            require(a['queue'][:len(b['queue'])]==b['queue'] and a['queue'][len(b['queue']):]==step['events'],'event closure')
            if not step['permitted']:
                blocked+=1
                require(step['before']==step['after'] and not step['events'] and not step['observations'],'blocked mutation')
            elif step['command']['t']=='playCard':
                require(step['last_ret'] is True,'failed permitted play')
            # Independently fold enemy HP and keep post-Block unbounded loss distinct from HP removed.
            hp=max(0,step['before_view']['hp']); unclipped=0; removed=0; healed=0; poison=0
            for ev in step['events']:
                if ev['t']=='hitEnemy':
                    require(ev['idx']==0 and ev['amount']>=0,'hit target/amount')
                    amt=ev['amount']; actual=min(hp,amt); hp=max(0,hp-amt)
                    require(ev['hpAfter']==hp,'health event')
                    unclipped+=amt; removed+=actual
                    if ev.get('poison',False): poison+=actual
                elif ev['t']=='heal' and str(ev.get('who'))!='player':
                    require(ev['who']==0,'heal target'); hp+=ev['n'];healed+=ev['n']
            require(hp==max(0,step['after_view']['hp']),'health final')
            h=step['health']
            require(h['ok'] and (h['removed'],h['nominal'],h['healed'],h['poison_removed'])==(removed,unclipped,healed,poison),'health accounting units')
            for ob in step['observations']:
                observed_effects+=1
                if ob['kind']=='phantom':
                    q=len(step['before_view']['hand'])-1
                    require(ob['q_after_removal']==q and ob['uid']==901,'post-removal stock')
                    n=7 if sp['up'] else 6
                    factual=2*min(q,4)+n*max(0,q-4)
                    high_off=sp['aspect']==1 and mask&4!=0
                    require(ob['suppressed']==high_off,'payoff factor scope')
                    require(ob['factual_raw']==factual and ob['delivered_raw']==(2*min(q,4) if high_off else factual),'consumer raw law')
                else:
                    require(ob['kind']=='effect','unknown observer kind')
                    kind=ob['effect']['kind']
                    off=sp['aspect']==1 and ob['card'] in ('preparation','surge') and ((kind=='draw' and mask&1!=0) or (kind=='energy' and mask&2!=0))
                    require(ob['suppressed']==off,'producer factor scope')
                    if off:
                        require(ob['before_hand']==ob['after_hand'] and ob['before_energy']==ob['after_energy'] and ob['event_start']==ob['event_end'],'suppressed effect changed state')
            previous=step['after']
    expected={(a,v,u,label,m) for a in (0,1) for v in (0,5) for u in (False,True)
              for label in LABELS for m in range(-1,8)}
    expected|={(a,v,u,'q_'+str(q),m) for a in (0,1) for v in (0,5) for u in (False,True)
               for q in range(10) for m in (-1,0,4)}
    require(set(rows)==expected and len(rows)==1032,'complete frozen grid')
    require(tail['rows']==len(rows) and tail['states']==len(states) and tail['execution_failures']==0,'terminal coverage')
    off_equal=0; dusk_equal=0; dormant=0; effects=[]
    for a,v,u,label in sorted({k[:4] for k in rows}):
        native=rows[(a,v,u,label,-1)]; off=rows[(a,v,u,label,0)]
        require(signature(native)==signature(off),'observer changed factual trace');off_equal+=1
        if a==0:
            for k,r in rows.items():
                if k[:4]==(a,v,u,label) and k[4]>0:
                    require(signature(r)==signature(native),'other aspect not exact null');dusk_equal+=1
        if label.startswith('q_') and int(label[2:])<=4:
            require(signature(off)==signature(rows[(a,v,u,label,4)]),'below-reserve not exact null');dormant+=1
        if a!=1 or label.startswith('q_'):continue
        c={m:consumer(rows[(a,v,u,label,m)]) for m in range(8)}
        term=lambda m:c[m]['health']['removed']
        # Producer draw vs the above-reserve response; other terms and legal opportunity retained.
        interaction=term(0)-term(1)-term(4)+term(5)
        e={'vow':v,'up':u,'context':label,'consumer_permitted':{str(m):c[m]['permitted'] for m in range(8)},
           'consumer_hp_removed':{str(m):term(m) for m in range(8)},'draw_high_payoff_health_interaction':interaction}
        if label=='prep_stock':
            require(all(c[m]['permitted'] for m in range(8)) and interaction>0,'Preparation chain relevance')
        if label in ('surge_energy','surge_access','surge_empty','surge_branch'):
            require(c[0]['permitted'] and not c[2]['permitted'],'Surge Energy opportunity relevance')
        if label=='surge_access':
            require(not c[1]['permitted'],'Surge consumer access relevance')
        if label=='surge_spare':
            st=rows[(a,v,u,label,0)]['steps'][0]
            require(len(st['after_view']['hand'])==len(st['before_view']['hand']),'Surge is not inherently net stock')
        effects.append(e)
    return {'status':'HAND_COMPONENT_OBSERVATION_PREFLIGHT_PASS','rows':len(rows),'states':len(states),
      'exact_native_off_pairs':off_equal,'other_aspect_exact_null_pairs':dusk_equal,'below_reserve_exact_null_pairs':dormant,
      'reflected_views_checked':observed_views,'effect_records_checked':observed_effects,'blocked_opportunities_retained':blocked,
      'source_specific_contrasts':effects,'new_independent_samples':0,'packages_admitted':0,'p9_certified':False,
      'scope':'Finite observer/three component-intervention preflight only. Preparation draw and Surge draw/Energy alternatives; not every supplier or natural policy support.',
      'next':'Freeze complete competent multi-policy real-economy support with exact observation and unchanged signed controls; no existing-cohort rerun.',
      'limitations':['Hand size and realised action damage are observed, not inferred from aggregate co-play.',
        'The high-payoff intervention sets only n=0; the existing below-reserve floor, action costs, Exhaust and native side effects remain.',
        'Dusk is an exact-null context for the Ash-scoped research interventions, not evidence that the shared Phantom card has no Dusk effect.',
        'Constructor states are not naturally acquired decks, independent policy samples, a package certificate, a C2 or detector PASS.',
        'Negative or zero contrasts outside the preregistered relevance witnesses are retained; no universal nonnegative interaction is assumed.']}

if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser();p.add_argument('raw',type=Path);p.add_argument('protocol',type=Path)
    a=p.parse_args();print(json.dumps(analyze(a.raw.read_bytes(),json.loads(a.protocol.read_bytes())),indent=2))
