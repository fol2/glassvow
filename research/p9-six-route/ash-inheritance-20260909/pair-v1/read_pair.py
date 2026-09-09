"""Read one fixed inherited-Ash pair support rectangle and complete BF clones.

Support uses the registered historical activation definitions on NEW captures.
It is not an unchanged empirical carry, full Hand attribution or P9 certificate.
"""
from collections import defaultdict
import hashlib
import json
import lzma
from pathlib import Path


def require(ok, why):
    if not ok: raise ValueError(why)


def sha(b): return hashlib.sha256(b).hexdigest()

def stream(path):
    path=Path(path)
    op=lzma.open if path.suffix=='.xz' else open
    with op(path,'rt',encoding='utf-8') as f:
        for n,line in enumerate(f,1):
            require(bool(line.strip()),f'EMPTY_LINE:{path}:{n}')
            yield json.loads(line)


def hp_removed(arm, target):
    before={e['idx']:e['hp'] for e in arm['before']['combat']['enemies']}
    after={e['idx']:e['hp'] for e in arm['after']['combat']['enemies']}
    require(target in before and target in after,'TARGET_IDENTITY')
    return max(0,before[target])-max(0,after[target])


def heal(arm):
    return sum(e['n'] for e in arm['events'] if e.get('t')=='heal' and e.get('who')=='player')


def clones(record):
    arms=record['clones']
    require(set(arms)=={'none','A','B','AB'},'FULL_CLONE_RECTANGLE')
    require(record['original_untouched_by_clones'] is True,'FACTUAL_MUTATION')
    require(record['factual_clone_match'] is True,'FACTUAL_PARITY')
    require(all(x['initial_equal'] is True for x in arms.values()),'CLONE_INITIAL_STATE')
    require(arms['AB']['after']==record['factual_after'] and arms['AB']['events']==record['events']
            and arms['AB']['ret']==record['ret'],'FULL_FACTUAL_PARITY')
    require(arms['AB']['before']==record['factual_before'],'FACTUAL_BEFORE')
    for name in ('none','A','B','AB'):
        expected=json.loads(json.dumps(record['factual_before']))
        if name in ('none','B'):
            expected['combat']['player']['statuses'].pop('bloodfire',None)
        require(arms[name]['before']==expected,'UNINTENDED_INTERVENTION_STATE:'+name)
    require(arms['none']['after']==arms['B']['after'] and arms['none']['events']==arms['B']['events']
            and arms['none']['ret']==arms['B']['ret'],'ZERO_STOCK_EXACT_NULL')
    if record['before']['bloodfire']==0:
        require(all(x['after']==arms['AB']['after'] and x['events']==arms['AB']['events'] and x['ret']==arms['AB']['ret'] for x in arms.values()),'DORMANT_EXACT_NULL')
    require(all(x['ret']==record['ret'] for x in arms.values()),'COMMAND_ELIGIBILITY_CHANGED')
    target=record['command']['target']
    h={k:hp_removed(v,target) for k,v in arms.items()}
    healing={k:heal(v) for k,v in arms.items()}
    interaction=lambda d:d['AB']-d['A']-d['B']+d['none']
    return {'hp_removed':h,'healed':healing,'hp_interaction':interaction(h),
            'native_hit_amounts':{k:sum(e['amount'] for e in v['events'] if e.get('t')=='hitEnemy') for k,v in arms.items()},
            'heal_interaction':interaction(healing),'positive_stock':record['before']['bloodfire']>0,
            'legal':record['ret'] is True}


def trace_summary(path, expected_keys, qualification=False):
    summaries={};counts=defaultdict(int)
    for r in stream(path):
        key=r['row_key']
        require(key in expected_keys,'UNASSIGNED_TRACE_KEY')
        if key not in summaries:
            summaries[key]={'commands':0,'bloodfire_applied':0,'bloodfire_consumed':0,'played':defaultdict(int),
                            'phantom_damage':0,'coowned_bloodfire':False,'coowned_hand':False,
                            'clones':[],'seen_fights':set()}
        s=summaries[key]
        require(r['sequence']==s['commands'],'COMMAND_SEQUENCE');s['commands']+=1
        require(r['kind']=='command' and r['original_untouched_by_clones'] is True,'TRACE_IDENTITY')
        card=r['card'];legal=r['ret'] is True
        for e in r['events']:
            if e.get('t')=='status' and e.get('id')=='bloodfire':
                n=e['n']
                if n>0:
                    require(card=='bloodRite' and legal and n==1,'UNBOUND_PRODUCER_EVENT')
                    s['bloodfire_applied']+=n
                elif n<0:
                    require(card=='leechBlade' and legal and n==-1,'UNBOUND_CONSUMER_EVENT')
                    s['bloodfire_consumed']-=n
        if not qualification:
            require(s['bloodfire_consumed']<=s['bloodfire_applied'],'SOURCE_PROVENANCE')
        if card and legal:s['played'][card]+=1
        if card=='phantomBlades' and legal:
            s['phantom_damage']+=sum(max(0,e['amount']) for e in r['events'] if e.get('t')=='hitEnemy')
        for side in ('before','after'):
            ids={c['id'] for c in r[side]['deck']}
            s['coowned_bloodfire'] |= {'bloodRite','leechBlade'}<=ids
            s['coowned_hand'] |= 'phantomBlades' in ids and bool(ids & {'preparation','surge'})
        if card=='leechBlade':
            s['clones'].append(clones(r));counts['consumer_clone_actions']+=1
        else:require(not r['clones'],'UNASSIGNED_CLONE')
        s['seen_fights'].add(r['fight'])
    require(set(summaries)==set(expected_keys),'MISSING_TRACE_RUN')
    return summaries,dict(counts)


def run_flags(outcome, s):
    deck=set(outcome['row']['deckIds']);played=s['played']
    bloodfire=({'bloodRite','leechBlade'}<=deck and s['bloodfire_applied']>0 and s['bloodfire_consumed']>0)
    hand=('phantomBlades' in deck and any(k in deck and played[k]>0 for k in ('preparation','surge'))
          and played['phantomBlades']>0 and s['phantom_damage']>0)
    return {'bloodfire':bool(bloodfire),'hand':bool(hand),
            'reachable_bloodfire':s['coowned_bloodfire'] and played['leechBlade']>0,
            'reachable_hand':s['coowned_hand'] and played['phantomBlades']>0,
            'bloodfire_incremental_hp':any(c['legal'] and c['positive_stock'] and c['hp_interaction']>0 for c in s['clones'])}


def outcome_records(path,cfg,p):
    all_rows=list(stream(path));h=all_rows[0];rows=all_rows[1:-1];last=all_rows[-1]
    require(h['kind']=='header' and h['config']==cfg,'CONFIG')
    require(h['engine']=='4.7.2-stable (official)','ENGINE')
    for name in ('content_sha256','combat_sha256','observer_sha256','probe_sha256','sources'):
        require(h[name]==p['runtime'][name],'RUNTIME_IDENTITY:'+name)
    require(len(rows)==cfg['count']*len(cfg['seeds']) and last=={'kind':'terminal','rows':len(rows)},'OUTCOME_COUNT')
    expected=[(i,seed) for i in range(cfg['first'],cfg['first']+cfg['count']) for seed in cfg['seeds']]
    require([(r['index'],r['seed']) for r in rows]==expected,'OUTCOME_IDENTITIES')
    require(len(h['policies'])==cfg['count'],'POLICY_COUNT')
    for r in rows:
        require(r['kind']=='outcome' and r['vow']==cfg['vow'] and r['row_key']==f"{cfg['vow']}:{r['index']}:{r['seed']}",'ROW_IDENTITY')
        require(r['policy']==h['policies'][r['index']-cfg['first']],'POLICY_BINDING')
        require(r['row']['policy']==r['policy'] and r['row']['aspect']=='ashwarden' and r['row']['vow']==cfg['vow'] and r['row']['seed']==r['seed'],'NATIVE_ROW_BINDING')
        require(r['observer_matches_stock'] is True if cfg['integration'] else r['observer_matches_stock'] is None,'OBSERVATION_PARITY_FLAG')
        require(r['row']['outcome'] in ('win','loss') and not r['row']['error'],'NATIVE_FAULT')
    return rows


def support_decision(policies,bounds):
    ids=set(policies)
    active={name:{i for i,v in policies.items() if v[name]} for name in ('bloodfire','hand')}
    reach={name:{i for i,v in policies.items() if v['reachable_'+name]} for name in active}
    report={name:{'active':len(active[name]),'inactive':len(ids-active[name]),'reachable':len(reach[name]),
                  'exclusive':len(active[name]-active['hand' if name=='bloodfire' else 'bloodfire'])} for name in active}
    gates={name:{'active':r['active']>=bounds['active'],'inactive':r['inactive']>=bounds['inactive'],
                 'reachable':r['reachable']>=bounds['reachable'],'exclusive':r['exclusive']>=bounds['exclusive']} for name,r in report.items()}
    return {'packages':report,'cross_active':len(active['bloodfire']&active['hand']),
            'gates':gates,'pass':all(all(g.values()) for g in gates.values())}


def analyze(folder,p,vow):
    folder=Path(folder);all_rows={};policies={};row_results=[];totals=defaultdict(int)
    for first in range(0,p['policies'],p['policies_per_cell']):
        cfg={'root':p['policy_root'],'first':first,'count':p['policies_per_cell'],
             'seeds':p['seeds'],'vow':vow,'integration':False}
        stem=f'v{vow}-{first:03d}'
        rows=outcome_records(folder/(stem+'.outcomes.jsonl.xz'),cfg,p)
        traces,counts=trace_summary(folder/(stem+'.traces.jsonl.xz'),{r['row_key'] for r in rows})
        for k,v in counts.items():totals[k]+=v
        for r in rows:
            key=r['row_key'];require(key not in all_rows,'DUPLICATE_ROW');all_rows[key]=r
            i=r['index'];canonical=json.dumps(r['policy'],sort_keys=True,separators=(',',':'))
            flags=run_flags(r,traces[key])
            if i not in policies:policies[i]={'policy':canonical,**{k:False for k in flags}}
            require(policies[i]['policy']==canonical,'POLICY_ACROSS_SEEDS')
            for k,v in flags.items():policies[i][k] |= v
            cf=traces[key]['clones']
            row_results.append({'row_key':key,'index':i,'seed':r['seed'],'outcome':r['row']['outcome'],**flags,
                                'applied':traces[key]['bloodfire_applied'],'consumed':traces[key]['bloodfire_consumed'],
                                'clone_actions':len(cf),'hp_interaction_sum':sum(c['hp_interaction'] for c in cf),
                                'heal_interaction_sum':sum(c['heal_interaction'] for c in cf)})
    require(len(policies)==p['policies'] and len({x['policy'] for x in policies.values()})==p['policies'],'UNIQUE_POLICIES')
    decision=support_decision(policies,p['support_bounds'])
    return {'status':'INHERITED_PAIR_NATURAL_SUPPORT_PASS_NOT_CERTIFICATE' if decision['pass'] else 'INHERITED_PAIR_NATURAL_SUPPORT_FAIL_IN_FIXED_POLICY_FAMILY',
            'vow':vow,'rows':len(all_rows),'policy_configurations':len(policies),**decision,
            'outcomes':dict(__import__('collections').Counter(r['row']['outcome'] for r in all_rows.values())),
            'counterfactual_checks':dict(totals),'incremental_hp_policies':sum(v['bloodfire_incremental_hp'] for v in policies.values()),
            'row_results':row_results,'policy_ids':{name:[i for i,v in policies.items() if v[name]] for name in ('bloodfire','hand')},
            'limits':['Support is not complete certificate, source/runtime oracle or P9.',
                      'Hand uses historical necessary activation, not proof its producer caused the later damage.',
                      'BF clones intervene on existing stock and consumer read path; they do not model adaptive whole-run policy response or producer removal.',
                      'Do not aggregate repeated local clone payoffs into a whole-run treatment effect.',
                      'This fixed controller-family failure is not universal package nonviability.'],
            'new_independent_package_confirmation':False,'packages_admitted':0,'p9_certified':False}
