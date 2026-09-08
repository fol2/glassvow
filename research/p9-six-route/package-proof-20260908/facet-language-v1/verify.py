"""Fail-closed FIFO/minimal-word certificate reader. Does not execute Godot."""
import hashlib,json,sys
from pathlib import Path

def need(ok,why):
    if not ok: raise ValueError(why)
def sha(b): return hashlib.sha256(b).hexdigest()
def key(case): return (case['vow'],case['up'])
def prefix(state,depth):
    cb=state[1]; commands=[]
    if cb['over'] or depth>=9:return commands
    if cb['player']['energy']>=1:
        for c in sorted(cb['hand'],key=lambda c:c['uid']):
            if c['id'] not in ('chisel','defend'):continue
            if c['id']=='chisel' and cb['enemies'][0]['hp']<=0:continue
            commands.append(dict(t='playCard',uid=c['uid'],target=0 if c['id']=='chisel' else None))
    if cb['turn']<4: commands.append(dict(t='endTurn'))
    return commands

def enabled(state):
    run,cb,_=state
    return (not cb['over'] and cb['player']['energy']>=1 and cb['enemies'][0]['hp']>0 and
        any(c['uid']==1000 for c in cb['hand']) and run['stats'].get('shatters',0)>0 and
        (cb['enemies'][0]['staggered'] or cb['enemies'][0]['statuses'].get('vulnerable',0)>0))

def accounting(before,events,after):
    hp={e['idx']:max(0,e['hp']) for e in before[1]['enemies']}; nominal=removed=0
    for e in events:
        if e['t']=='hitEnemy':
            n=e['amount'];i=e['idx'];need(type(n)is int and n>=0 and i in hp,'HIT_DOMAIN')
            nominal+=n;removed+=min(hp[i],n);hp[i]=max(0,hp[i]-n);need(hp[i]==e['hpAfter'],'HIT_HP')
        elif e['t']=='heal' and e.get('who')!='player':hp[e['who']]+=e['n']
    need(hp=={e['idx']:max(0,e['hp']) for e in after[1]['enemies']},'FINAL_HP')
    return removed,nominal

def verify(records,initials,script_sha):
    header=records[0];need(header['kind']=='header','HEADER')
    need(header['script_sha256']==script_sha,'SCRIPT')
    need(header['content_sha256']=='3c7b2f9dba362d19128ef82ad559d3f26e54925371d823a665767032255eadaa','CONTENT')
    need((header['max_depth'],header['max_turn'],header['max_nodes_per_case'])==(10,4,20000),'BOUNDS')
    states={}; cases={}; outputs=[]; count=0
    for r in records[1:-1]:
        kind=r['kind']
        if kind=='state':
            h=r['sha256'];need(h==sha(r['serialized'].encode()) and h not in states,'STATE_IDENTITY')
            states[h]=json.loads(r['serialized']);continue
        k=key(r['case']);init=r['case']['initial'];need(init==initials[k],'OLD_FIXTURE_IDENTITY')
        if kind=='case':
            need(k not in cases,'DUPLICATE_CASE')
            cases[k]=dict(queue=[(r['root_id'],init,0,[])],seen={init:r['root_id']},cursor=0,terminal=False,winning=None)
            count+=1;continue
        need(k in cases,'CASE_ORDER');case=cases[k]
        if kind=='result':
            need(not case['terminal'],'DUPLICATE_RESULT');case['terminal']=True
            need(r['expanded']==case['cursor'] and r['discovered']==len(case['queue']),'QUEUE_COUNTS')
            if r['status']=='BOUNDED_MINIMUM_WORD_FOUND':
                w=case['winning'];need(w is not None,'NO_WINNER')
                path=w['path']+[dict(t='playCard',uid=1000,target=0)]
                need(r['path']==path and r['minimum_commands']==len(path)<=10,'WORD_LENGTH')
                need(r['winning_id']==w['id'] and r['extra_hp']==w['extra_hp'],'WINNER_ID')
                direct=r['direct_replay'];need([x['cmd'] for x in direct['steps']]==path,'REPLAY_WORD')
                last=init
                expected=w['steps']+[dict(cmd=path[-1],before=w['state'],after=w['probe']['arms'][0]['after'],events=w['probe']['arms'][0]['events'],ret=True)]
                need(direct['steps']==expected,'DIRECT_REPLAY_PARITY')
                for s in direct['steps']:
                    need(s['before']==last,'REPLAY_CHAIN');last=s['after']
                need(last==direct['final']==w['probe']['arms'][0]['after'],'REPLAY_FINAL')
                outputs.append(dict(vow=k[0],up=k[1],status=r['status'],minimum_commands=len(path),path=path,
                    extra_hp=r['extra_hp'],prefix_shatters=states[w['state']][0]['stats'].get('shatters',0),expanded=r['expanded'],discovered=r['discovered']))
            elif r['status']=='NO_WORD_IN_BOUNDED_GRAMMAR':
                need(case['winning'] is None and case['cursor']==len(case['queue']),'INCOMPLETE_EXHAUSTION')
                outputs.append(dict(vow=k[0],up=k[1],status=r['status']))
            else:
                need(r['status']=='INCONCLUSIVE_NODE_CAP' and len(case['queue'])>20000,'UNKNOWN_TERMINAL')
                outputs.append(dict(vow=k[0],up=k[1],status=r['status']))
            continue
        need(kind=='node' and not case['terminal'] and case['winning'] is None,'NODE_ORDER')
        nid,h,depth,steps=case['queue'][case['cursor']];case['cursor']+=1
        need((r['id'],r['state'],r['depth'])==(nid,h,depth),'FIFO_COVERAGE')
        state=states[h];probe=r['terminal'];need(bool(probe)==bool(enabled(state)),'GOAL_ELIGIBILITY')
        extra=0
        if probe:
            need(probe['cmd']==dict(t='playCard',uid=1000,target=0),'CONSUMER')
            need([a['erase_echo'] for a in probe['arms']]==[False,True],'ARMS')
            for arm in probe['arms']:
                need(arm['ret'] is True and states[arm['after']][2] is True,'TERMINAL_RETURN')
                hp,n=accounting(state,arm['events'],states[arm['after']])
                need((hp,n)==(arm['accounting']['removed'],arm['accounting']['nominal']),'TERMINAL_ARITHMETIC')
            extra=probe['arms'][0]['accounting']['removed']-probe['arms'][1]['accounting']['removed']
            need(extra==probe['extra_hp'],'CONTRAST')
        need(r['winning']==bool(probe and extra>0),'WIN_PREDICATE')
        if r['winning']:
            need(r['commands']==r['edges']==[],'WINNER_HAS_CHILDREN')
            case['winning']=dict(id=nid,state=h,path=[x['cmd'] for x in steps],steps=steps,probe=probe,extra_hp=extra)
            continue
        commands=prefix(state,depth);need(r['commands']==commands and [x['cmd'] for x in r['edges']]==commands,'LEGAL_LANGUAGE_COVERAGE')
        for edge in r['edges']:
            after=states[edge['state']];cmd=edge['cmd']
            need(cmd['t']!='playCard' or edge['ret'] is True,'ILLEGAL_EDGE')
            need(cmd['t']!='endTurn' or after[1]['turn']==state[1]['turn']+1,'TURN_EDGE')
            hp,n=accounting(state,edge['events'],after)
            need((hp,n)==(edge['accounting']['removed'],edge['accounting']['nominal']),'EDGE_ARITHMETIC')
            fresh=edge['state'] not in case['seen'];need(edge['fresh']==fresh,'FRESHNESS')
            if fresh:
                need(edge['to'] not in case['seen'].values(),'DUPLICATE_ID')
                case['seen'][edge['state']]=edge['to']
                s=dict(cmd=cmd,before=h,after=edge['state'],events=edge['events'],ret=edge['ret'])
                case['queue'].append((edge['to'],edge['state'],depth+1,steps+[s]))
            else:need(edge['to']==case['seen'][edge['state']],'MERGED_ID')
    need(set(cases)=={(v,u) for v in (0,5) for u in (False,True)} and all(c['terminal'] for c in cases.values()),'CASE_COVERAGE')
    need(records[-1]['kind']=='summary' and records[-1]['cases']==4 and records[-1]['states']==len(states),'SUMMARY')
    need(records[-1]['allocated_nodes']==sum(len(c['queue']) for c in cases.values()),'ALLOCATIONS')
    return dict(status='BOUNDED_LANGUAGE_CERTIFICATES_NOT_PACKAGE_ADMISSION',cases=outputs,states=len(states),
        new_independent_samples=0,packages_admitted=0,p9_certified=False,
        limits=['Exact four pre-existing controlled states, not natural acquisition or population frequency.',
                'Minimum legal command count within the specified producer/defend/endTurn grammar and limits, not a global optimum.',
                'This source-bound certificate is author-self-reviewed, not an independent runtime oracle or full canonical-family admission.',
                'The old 672-row COMMAND_CONTRACT_FAIL remains unchanged.'])

if __name__=='__main__':
    raw=Path(sys.argv[1]).read_bytes(); records=[json.loads(s) for s in raw.splitlines()]
    initial_rows=json.loads(Path(sys.argv[2]).read_text());initials={(r['vow'],r['up']):r['initial'] for r in initial_rows}
    result=verify(records,initials,sha(Path(sys.argv[3]).read_bytes()))
    Path(sys.argv[4]).write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))
