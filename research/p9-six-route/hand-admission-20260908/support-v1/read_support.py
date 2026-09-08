"""Read full retained native evidence; no new game, fitting, or unseen-row inference."""
from __future__ import annotations
from collections import Counter
import hashlib,json,lzma
from pathlib import Path
from cohort import CONTENT,SEEDS,policies,identity

def require(value,why):
    if not value:raise ValueError(why)
def sha(data):return hashlib.sha256(data).hexdigest()
def records(path):
    p=Path(path)
    with (lzma.open(p,'rb') if p.suffix=='.xz' else p.open('rb')) as f:
        for line in f:
            if line.strip():yield json.loads(line),line.rstrip(b'\r\n')
def future(state):
    index={}
    def visit(v):
        if isinstance(v,dict):
            if 'object' in v:
                require(v['object'] not in index,'duplicate reflected object');index[v['object']]=v
            for q in v.values():visit(q)
        elif isinstance(v,list):
            for q in v:visit(q)
    visit(state['future'])
    def resolve(v):return index[v['ref']] if isinstance(v,dict) and set(v)=={'ref'} else v
    run,cb,ret=map(resolve,state['future'])
    return run,cb,ret,resolve

def validate_transition(before,after,events,health=None):
    b_run,b,_,br=future(before);a_run,a,_,ar=future(after)
    require(after['queue']==before['queue']+events,'event closure')
    hp={br(e)['idx']:max(0,br(e)['hp']) for e in b['enemies']}
    final={ar(e)['idx']:max(0,ar(e)['hp']) for e in a['enemies']}
    nominal=removed=poison=healed=0
    for ev in events:
        if ev['t']=='hitEnemy':
            k=ev['idx'];amount=ev['amount'];require(k in hp and amount>=0,'hit accounting')
            actual=min(hp[k],amount);hp[k]=max(0,hp[k]-amount)
            require(hp[k]==ev['hpAfter'],'event health state')
            nominal+=amount;removed+=actual
            if ev.get('poison',False):poison+=actual
        elif ev['t']=='heal' and str(ev.get('who'))!='player':
            k=ev['who'];require(k in hp and ev['n']>=0,'heal accounting');hp[k]+=ev['n'];healed+=ev['n']
    require(hp==final,'health final')
    if health is not None:require(health=={'ok':True,'nominal':nominal,'removed':removed,'poison_removed':poison,'healed':healed},'health units')

def complete_chain(record):
    """Classify only recorded paths; an illegal branch has UNKNOWN damage, not zero."""
    direct=record['direct']
    delta=direct[0]['health']['removed']-direct[1]['health']['removed']
    require(record['high_health_contribution']==delta,'direct contribution')
    arms=record['prefix_arms']
    if delta<=0 or not arms:return 'NO_POSITIVE_COMPLETE_HISTORICAL_CHAIN'
    require(len(arms)==8 and [a['mask'] for a in arms]==list(range(8)),'factorial coverage')
    selected=[arms[m] for m in (0,3,4,7)]
    if all(x['complete'] for x in selected):
        y=[x['steps'][-1]['health']['removed'] for x in selected]
        if y[0]-y[1]-y[2]+y[3]>0:return 'POSITIVE_SOURCE_BY_HIGH_PAYOFF_HEALTH_INTERACTION'
        return 'NO_POSITIVE_COMPLETE_HISTORICAL_CHAIN'
    if not arms[3]['complete']:
        return 'SOURCE_REQUIRED_FOR_RECORDED_COMMAND_OPPORTUNITY'
    return 'UNRESOLVED_PREFIX_DAMAGE_CONTRAST'

def read_cell(endpoints,trace,config):
    ends=list(records(endpoints));header=ends[0][0]
    require(header['kind']=='header' and header['config']==config,'config identity')
    for field,name in [('runner_sha256','support_runner.gd'),('game_sha256','hand_game.gd')]:
        require(header[field]==sha((Path(__file__).parent/name).read_bytes()),'bound native source:'+name)
    require(header['engine']['string']=='4.7.2-stable (official)' and header['content_sha256']==CONTENT,'runtime/content')
    require(len(ends)==config['runs']+1,'endpoint coverage')
    targets={config['id']+':'+str(x['seed']):(x,sha(b)) for x,b in ends[1:]}
    require([x['seed'] for x,_ in ends[1:]]==list(range(config['seed0'],config['seed0']+config['runs'])),'seed order')
    for x,_ in ends[1:]:
        require(x['policy_id']==config['policy_id'] and x['policy_parameters']==config['params'],'policy binding')
        require(x['aspect']==config['aspect'] and x['vow']==config['vow'] and x['route']==config['route'],'context')
        require(x['result'] in ('win','loss','error','stall'),'outcome')
    current=None;states={};sequence=[];consumers=[];stats=Counter();done={};pending={};last_by_fight={}
    def state(h):require(h in states,'missing full state');return states[h]
    def steps_ok(steps,initial,complete):
        prev=initial
        for i,s in enumerate(steps):
            require(s['before']==prev,'shadow continuity');state(prev);state(s['after'])
            if not s['permitted']:
                require(i==len(steps)-1 and not complete and s['after']==s['before'],'blocked path')
            else:
                validate_transition(state(s['before']),state(s['after']),s['events'],s['health'])
                if s['command']['t'] in ('playCard','usePotion'):require(s['ret'] is True,'shadow command legality')
            prev=s['after']
        return prev
    for item,_ in records(trace):
        k=item['row_key'];require(k in targets,'unassigned trace')
        if current!=k:
            require(current is None or current in done,'unfinished trace row')
            require(k not in done,'reopened trace row')
            current=k;states={};sequence=[];consumers=[];stats=Counter();pending={};last_by_fight={}
        kind=item['kind']
        if kind=='fault':raise ValueError('native observer fault:'+item['reason'])
        if kind=='state':
            h=item['sha256'];require(h not in states and sha(item['serialized'].encode())==h,'state binding')
            states[h]=json.loads(item['serialized'])
            rr,_,_,_=future(states[h]);require(rr['seed']==targets[k][0]['seed'] and rr['aspect']==config['aspect'] and rr['vow']==config['vow'],'reflected input binding')
            continue
        if kind=='fight_start':
            state(item['initial']);last_by_fight[item['fight']]=item['initial'];continue
        if kind=='consumer':
            key=(item['fight'],item['before'],item['after']);require(key not in pending,'duplicate consumer')
            _,cb,_,resolve=future(state(item['before']))
            require(item['q']==len(cb['hand'])-1 and 0<=item['q']<=9,'actual hand stock')
            cards=[resolve(c) for c in cb['hand']]
            c=next(c for c in cards if c['uid']==item['command']['uid'])
            require(c['id']=='phantomBlades' and c['up']==item['up'],'consumer UID')
            d=item['direct'];require(len(d)==2 and [x['mask'] for x in d]==[0,4],'direct factors')
            for branch in d:
                require(branch['initial']==item['before'],'direct common input')
                validate_transition(state(branch['initial']),state(branch['final']),branch['events'],branch['health'])
            for arm in item['prefix_arms']:
                require(arm['initial']==item['prefix_arms'][0]['initial'],'prefix common input')
                require([s['command'] for s in arm['steps']]==item['prefix_commands'][:len(arm['steps'])],'prefix command binding')
                require(steps_ok(arm['steps'],arm['initial'],arm['complete'])==arm['final'],'prefix final')
                if arm['complete']:require(len(arm['steps'])==len(item['prefix_commands']),'complete prefix')
                require(arm['events']==[ev for s in arm['steps'] if s['permitted'] for ev in s['events']],'prefix event coverage')
            pending[key]=item;continue
        if kind=='command':
            require(last_by_fight[item['fight']]==item['before'],'factual command continuity')
            validate_transition(state(item['before']),state(item['after']),item['events'],item['health'])
            last_by_fight[item['fight']]=item['after'];sequence.append(item)
            cid=item['card']
            if cid in ('preparation','surge'):stats['supplier_plays:'+cid]+=1
            if cid=='phantomBlades':
                key=(item['fight'],item['before'],item['after']);require(key in pending,'missing consumer record')
                c=pending.pop(key);require(c['command']==item['command'],'consumer command')
                d=c['direct'][0];require(d['final']==item['after'] and d['events']==item['events'] and d['ret']==item['ret'],'direct factual parity')
                if c['prefix_arms']:
                    f=c['prefix_arms'][0];require(f['complete'] and f['final']==item['after'],'prefix factual final')
                    start=next(i for i,x in enumerate(sequence) if x['before']==f['initial'])
                    actual=sequence[start:]
                    require([x['command'] for x in actual]==c['prefix_commands'],'actual historical sequence')
                    require([e for x in actual for e in x['events']]==f['events'],'prefix factual events')
                stats['phantom_plays']+=1
                if c['high_health_contribution']>0:stats['positive_high_payoff_plays']+=1
                consumers.append({'fight':c['fight'],'q':c['q'],'classification':complete_chain(c),
                  'high_health_contribution':c['high_health_contribution'],'raw_reference':key})
            continue
        require(kind=='row_end','unknown record')
        endpoint,digest=targets[k]
        require(not pending and item['endpoint_sha256']==digest,'complete endpoint binding')
        if config.get('hand_observer',True):require(len(last_by_fight)==len(endpoint['fights']),'factual fight coverage')
        require(dict(stats)==item['counters']==endpoint['hand_counters'],'observer counter reconstruction')
        final_ids={s.rstrip('+') for s in endpoint['deck']}
        final_pair='phantomBlades' in final_ids and bool(final_ids&{'preparation','surge'})
        causal=any(c['classification'] in ('POSITIVE_SOURCE_BY_HIGH_PAYOFF_HEALTH_INTERACTION','SOURCE_REQUIRED_FOR_RECORDED_COMMAND_OPPORTUNITY') for c in consumers)
        done[k]={'seed':endpoint['seed'],'result':endpoint['result'],'final_pair':final_pair,
                 'historical_chain_active':final_pair and causal,'positive_high_payoff':stats['positive_high_payoff_plays']>0,
                 'consumer_reached':stats['phantom_plays']>0,'consumers':consumers,
                 'decision_trace_sha256':identity([x['command'] for x in sequence]),'state_count':len(states)}
    require(set(done)==set(targets),'complete trace coverage')
    return {'policy_id':config['policy_id'],'policy_index':config['policy_index'],'vow':config['vow'],'route_preference':config['route'],'runs':list(done.values())}

def summarize(cells):
    require(len(cells)==128 and len({c['policy_id'] for c in cells})==128,'128 actual parameter vectors')
    require(len({c['vow'] for c in cells})==1,'one vow stage')
    expected={p['policy_id'] for p in policies()};require({c['policy_id'] for c in cells}==expected,'frozen policy coverage')
    active=[];inactive=[];ambiguous=[];reachable=[];won_active=[]
    for c in cells:
        require([r['seed'] for r in c['runs']]==list(SEEDS),'four assigned seeds')
        p=c['policy_index'];runs=c['runs']
        if any(r['historical_chain_active'] for r in runs):active.append(p)
        elif not any(r['positive_high_payoff'] for r in runs):inactive.append(p)
        else:ambiguous.append(p)
        if any(r['final_pair'] and r['consumer_reached'] for r in runs):reachable.append(p)
        if any(r['historical_chain_active'] and r['result']=='win' for r in runs):won_active.append(p)
    outcomes=Counter(r['result'] for c in cells for r in c['runs'])
    gates={'active':len(active)>=32,'inactive':len(inactive)>=32,'reachable':len(reachable)>=16,
           'fault_free':outcomes['error']==0 and outcomes['stall']==0}
    return {'status':'HAND_NATURAL_SUPPORT_GATE_PASS_NOT_PACKAGE_ADMISSION' if all(gates.values()) else 'HAND_NATURAL_SUPPORT_GATE_FAIL_IN_FIXED_POLICY_FAMILY',
            'vow':cells[0]['vow'],'policies':128,'rows':512,'outcomes':dict(outcomes),
            'active':active,'inactive':inactive,'ambiguous':ambiguous,'reachable':reachable,'active_with_win_descriptive':won_active,
            'gates':gates,'trajectory_classes':len({tuple(r['decision_trace_sha256'] for r in c['runs']) for c in cells}),
            'scope':'Fixed existing-public-controller family and four seeds only; inactive means no observed above-reserve positive health contribution, not universal inactivity. Blocked counterfactual damage remains unknown.',
            'packages_admitted':0,'p9_certified':False,
            'remaining':['Independent complementarity and behavioural confirmation; exact signed RandomBuild/duration/ceiling guardrails; full package peer separation; detector/retention/integration.']}
