"""Read the complete command fixture capture. No simulation or candidate fitting."""
import argparse, hashlib, itertools, json
from pathlib import Path
METRICS = ('hp_removed','nominal_damage','enemy_hp_net','poison_delta','player_hp_net','energy_spent')
ROLES = ('facet','fervor','cycle','smolder','hand')
def need(ok, reason):
    if not ok: raise ValueError(reason)
def key(spec):
    return tuple(spec[k] for k in ('role','aspect','vow','up','control'))
def expected_commands(s,mask,c,rev):
    role=s['role']; n=s['producers']; uid=900 if role=='cycle' and not s['control'] else 1000
    def play(u,prod): return {'t':'playCard','uid':u,'target':None if prod and role in ('fervor','hand') else 0}
    if rev: return [play(uid,False),play(900,True)]
    out=[]
    for j in range(n):
        if mask & (1<<j): out.append(play(900+j,True))
        if role=='facet' and j==2: out.append({'t':'endTurn'})
    if role in ('cycle','hand'): out.append({'t':'endTurn'})
    if c: out.append(play(uid,False))
    return out
def hp(cb): return {e['idx']:max(0,e['hp']) for e in cb['enemies']}
def poison(cb): return sum(e['statuses'].get('poison',0) for e in cb['enemies'])
def fold(before,events,after):
    health=hp(before); removed=nominal=0
    for e in events:
        if e.get('t')=='hitEnemy':
            i=e['idx']; n=e['amount'];need(i in health and type(n) is int and n>=0,'HIT_INPUT')
            removed+=min(health[i],n);nominal+=n;health[i]=max(0,health[i]-n)
            need(e['hpAfter']==health[i],'HIT_HP')
        elif e.get('t')=='heal' and e.get('who')!='player':
            i=e['who'];n=e['n'];need(i in health and type(n) is int and n>=0,'HEAL_INPUT');health[i]+=n
    need(health==hp(after),'FINAL_HP')
    return removed,nominal

def analyze(records,protocol):
    need(records[0]['kind']=='header' and records[-1]['kind']=='summary','ENVELOPE')
    need(records[0]['candidate_sha256']==protocol['candidate_sha256'],'CANDIDATE')
    need(records[0]['probe_sha256']==protocol['files']['probe.gd']['sha256'],'PROBE')
    states={}; rows={}; initials={}; fixture_expected=set(itertools.product(ROLES,(0,1),(0,5),(False,True),(False,True)))
    for r in records[1:-1]:
        if r['kind']=='state':
            b=r['serialized'].encode(); h=hashlib.sha256(b).hexdigest()
            need(h==r['sha256'] and h not in states,'STATE_HASH_OR_DUPLICATE')
            states[h]=json.loads(r['serialized']); continue
        need(r['kind']=='row','UNKNOWN_RECORD');s=r['fixture'];k=key(s)
        need(k in fixture_expected,'FIXTURE');n=(3 if s['vow']==0 else 4) if s['role']=='facet' else 1
        need(s['producers']==n and type(r['mask']) is int and 0<=r['mask']<1<<n,'ASSIGNMENT')
        need(type(r['consumer']) is bool and type(r['reverse']) is bool,'BOOL')
        rid=(k,r['mask'],r['consumer'],r['reverse']);need(rid not in rows,'DUPLICATE_ROW');rows[rid]=r
        if k not in initials:initials[k]=r['initial']
        need(initials[k]==r['initial'],'FIXTURE_INITIAL');need(r['initial'] in states,'MISSING_INITIAL')
        expected=expected_commands(s,r['mask'],r['consumer'],r['reverse'])
        need([x['cmd'] for x in r['steps']]==expected,'COMMAND_ASSIGNMENT')
        before0=states[r['initial']][1];last=r['initial'];removed=nominal=energy=0
        for step in r['steps']:
            need(step['before']==last and step['before'] in states and step['after'] in states,'STATE_CHAIN')
            before=states[step['before']][1];after=states[step['after']][1]
            if step['cmd']['t']=='playCard':
                need(step['ret'] is True and states[step['after']][2] is True,'ILLEGAL_CARD')
                card=next((c for c in before['hand'] if c.get('uid')==step['cmd']['uid']),None)
                need(card is not None,'CARD_NOT_IN_HAND')
                plays=[e for e in step['events'] if e.get('t')=='play']
                need(len(plays)==1 and plays[0]['uid']==card['uid'] and plays[0]['id']==card['id'],'PLAY_ID')
                energy+=before['player']['energy']-after['player']['energy']
            else:
                need(step['ret'] is None and after['turn']==before['turn']+1,'END_TURN')
            a,b=fold(before,step['events'],after);removed+=a;nominal+=b;last=step['after']
        need(last==r['final'],'FINAL_STATE');final=states[last][1]
        metrics=dict(zip(METRICS,(removed,nominal,sum(hp(before0).values())-sum(hp(final).values()),poison(final)-poison(before0),before0['player']['hp']-final['player']['hp'],energy)))
        need(r['metrics']==metrics,'METRIC_RECOMPUTE')
    wanted=set()
    for k in fixture_expected:
        n=(3 if k[2]==0 else 4) if k[0]=='facet' else 1
        wanted.update((k,m,c,False) for m in range(1<<n) for c in (False,True))
        if k[0] in ('fervor','smolder'):wanted.add((k,1,True,True))
    need(set(rows)==wanted and len(rows)==672 and len(initials)==80,'INCOMPLETE_ASSIGNMENT')
    need(records[-1]=={'kind':'summary','fixtures':80,'rows':672,'states':len(states),'execution_failures':0},'SUMMARY')
    checks=[];interactions=[]
    def check(ok,name,k,value):checks.append({'pass':bool(ok),'name':name,'fixture':list(k),'value':value})
    def metric(k,m,c,reverse=False):return rows[k,m,c,reverse]['metrics']
    def interaction(k,m):
        ab,a,b,z=(metric(k,m,True),metric(k,m,False),metric(k,0,True),metric(k,0,False))
        return {x:ab[x]-a[x]-b[x]+z[x] for x in METRICS}
    for k in sorted(fixture_expected):
        role,aspect,vow,up,control=k;n=(3 if vow==0 else 4) if role=='facet' else 1;full=(1<<n)-1
        eff=interaction(k,full);interactions.append({'fixture':list(k),'interaction':eff})
        if role=='facet':
            positive=aspect==0 and not control
            check(eff['hp_removed']>0 if positive else eff['hp_removed']==0,'FACET_FULL_HEALTH',k,eff['hp_removed'])
            for m in range(full):check(interaction(k,m)['hp_removed']==0,'FACET_PROPER_SUBSET_HEALTH',k,[m,interaction(k,m)['hp_removed']])
        elif role=='cycle':check(eff['hp_removed']==0 if control else eff['hp_removed']>0,'CYCLE_INSTANCE_HEALTH',k,eff['hp_removed'])
        elif role=='fervor':
            check(eff['hp_removed']>0,'FERVOR_HEALTH',k,eff['hp_removed'])
            if not control:check(eff['hp_removed']>interaction(k[:-1]+(True,),full)['hp_removed'],'FERVOR_ABOVE_ONE_HIT',k,eff['hp_removed'])
        elif role=='hand':check(eff['hp_removed']==0 if control else eff['hp_removed']>0,'HAND_CAPACITY_HEALTH',k,eff['hp_removed'])
        else:
            check(eff['poison_delta']>0 if aspect==1 else eff['poison_delta']==0,'SMOLDER_POISON',k,eff['poison_delta'])
            check(eff['hp_removed']==0,'SMOLDER_IMMEDIATE_HEALTH',k,eff['hp_removed'])
        if role in ('fervor','smolder'):
            coord='hp_removed' if role=='fervor' else 'poison_delta'
            delta=metric(k,full,True)[coord]-metric(k,full,True,True)[coord]
            check(delta>0 if role=='fervor' or aspect==1 else delta==0,'ORDER_'+coord,k,delta)
    failures=[c for c in checks if not c['pass']]
    return {'status':'COMMAND_CONTRACT_FAIL' if failures else 'COMMAND_CONTRACT_PASS_NOT_P9','rows':len(rows),'fixtures':len(initials),'states':len(states),'checks':len(checks),'failed_checks':len(failures),'failures':failures,'interactions':interactions,'p9_certified':False,'packages_admitted':0,'new_independent_samples':0}

def load(path):
    def reject(x):raise ValueError('NONFINITE:'+x)
    return [json.loads(x,parse_constant=reject) for x in Path(path).read_text().splitlines()]
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('capture');p.add_argument('protocol');p.add_argument('output');a=p.parse_args()
    result=analyze(load(a.capture),json.loads(Path(a.protocol).read_text()));Path(a.output).write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k!='interactions'}))
    # Semantic negative is retained evidence, not a transport/reader failure.
