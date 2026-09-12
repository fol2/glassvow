"""Landscape readout for #215 layer 1 (docs/balance/2026-08-14-strategy-landscape.md).

Usage: python3 tools/balance_landscape.py MERGED_NDJSON CONTROLS_ANALYSIS_JSON OUT_JSON [--frozen-axes]
MERGED_NDJSON is the merged sweep from tools/balance_sweep.gd (manifest line first);
CONTROLS_ANALYSIS_JSON holds per-arm winRate rows for the four control arms.
Re-run on the RC content SHA as the rc-bar pillar #213 requires.
#454 mini-landscapes must pass --frozen-axes so deck cuts, medians and tie order stay the #215 freeze.
"""
import json,math,statistics,sys
from pathlib import Path
from collections import defaultdict,Counter
frozen='--frozen-axes' in sys.argv[1:]
argv=[a for a in sys.argv[1:] if a!='--frozen-axes']
p=argv[0]
controls=json.load(open(argv[1]))
arm2={(r['aspect'],r['vow']):r['winRate'] for r in controls if r['arm']==2}
decks=[]; rates={'duskblade':([],[]),'ashwarden':([],[])}
with open(p) as f:
    next(f)
    for line in f:
        r=json.loads(line); fs=r['fights']; n=len(fs)
        decks.append(r['deck'])
        rates[r['aspect']][0].append(sum(x['shatters'] for x in fs)/n)
        rates[r['aspect']][1].append(sum(x['smolderKills'] for x in fs)/n)
decks.sort(); n=len(decks)
if frozen:
    axes=json.load(open(Path(__file__).resolve().parents[1]/'docs/balance/421-content-search-seeds-v1.json'))['frozenLandscape']
    low=axes['deckCuts']['thinMax']; high=axes['deckCuts']['midMax']; medians=axes['medians']
else:
    low=decks[(n-1)//3]; high=decks[(2*(n-1))//3]
    medians={a:{'shattersPerFight':statistics.median(x[0]),'smolderKillsPerFight':statistics.median(x[1])} for a,x in rates.items()}

def thick(d): return 'thin' if d<=low else ('mid' if d<=high else 'fat')
def wilson(w,n):
    z=1.959963984540054;p=w/n;den=1+z*z/n;c=(p+z*z/(2*n))/den;m=z*math.sqrt((p*(1-p)+z*z/(4*n))/n)/den
    return [c-m,c+m]
def flat(d,p=''):
    out={}
    for k,v in d.items():
        path=f'{p}.{k}' if p else k
        if isinstance(v,dict): out.update(flat(v,path))
        elif isinstance(v,(int,float)): out[path]=float(v)
    return out
cells=defaultdict(lambda:{'runs':0,'wins':0,'policies':set()})
policy_counts=defaultdict(lambda:[0,0])
policies={}; both=Counter(); outcomes=Counter()
with open(p) as f:
    next(f)
    for line in f:
        r=json.loads(line); a=r['aspect']; v=r['vow']; i=r['policyIndex']; fs=r['fights']; nf=len(fs)
        sr=sum(x['shatters'] for x in fs)/nf; mr=sum(x['smolderKills'] for x in fs)/nf
        sh=sr>medians[a]['shattersPerFight']; sm=mr>medians[a]['smolderKillsPerFight']
        if sh and sm: both[(a,v)]+=1
        lean='shatter' if sh else ('smolder' if sm else 'attrition')
        key=(a,v,lean,thick(r['deck'])); c=cells[key]; c['runs']+=1; c['wins']+=r['outcome']=='win'; c['policies'].add(i)
        pc=policy_counts[(a,v,i)]; pc[0]+=r['outcome']=='win'; pc[1]+=1
        if i not in policies: policies[i]=flat(r['policy'])
        outcomes[r['outcome']]+=1
result={'runs':sum(outcomes.values()),'outcomes':dict(outcomes),'deckCuts':{'thinMax':low,'midMax':high,'min':min(decks),'max':max(decks)},'medians':medians,'bothHighRuns':{f'{a}:v{v}':x for (a,v),x in both.items()},'grids':{},'verdicts':{},'audit':{}}
for a in ['duskblade','ashwarden']:
  for v in [0,5]:
    gkey=f'{a}:v{v}'; grid={}
    for lean in ['shatter','smolder','attrition']:
      for t in ['thin','mid','fat']:
        c=cells[(a,v,lean,t)]; runs=c['runs']; wins=c['wins']; rate=wins/runs if runs else 0
        grid[f'{lean}:{t}']={'policies':len(c['policies']),'runs':runs,'wins':wins,'winRate':rate,'wilson95':wilson(wins,runs) if runs else [0,0],'valid':len(c['policies'])>=20 and runs>=400}
    result['grids'][gkey]=grid
    top_name,top=max(grid.items(),key=lambda x:x[1]['winRate']); top_rate=top['winRate']; floor=(arm2[(a,v)]+top_rate)/2
    within=[k for k,x in grid.items() if x['winRate']>=top_rate-.10]
    viable=[k for k,x in grid.items() if x['winRate']>=floor]
    undersampled=[k for k in viable if not grid[k]['valid']]
    rates_by_policy=[(w/n,i,w,n) for (aa,vv,i),(w,n) in policy_counts.items() if aa==a and vv==v]
    rates_by_policy.sort(key=lambda x:(-x[0],x[1])); top_p=rates_by_policy[:200]; rest=rates_by_policy[200:]
    maxp=top_p[0]
    result['verdicts'][gkey]={'topCell':top_name,'topRate':top_rate,'within10pp':within,'viabilityFloor':floor,'viableCells':viable,'arm2Rate':arm2[(a,v)],'arm2Gap':top_rate-arm2[(a,v)],'C1a':len(within)>=3,'C1b':len(viable)>=4,'C2':top_rate-arm2[(a,v)]>=.35 and arm2[(a,v)]<.5,'underSampledHigh':undersampled,'maxPolicy':{'policyIndex':maxp[1],'winRate':maxp[0],'wins':maxp[2],'runs':maxp[3]}}
    top_ids=[x[1] for x in top_p]; rest_ids=[x[1] for x in rest]
    magnitude=[]; thresholds=[]
    ranges={'cardDecline':40,'removalAppetite':24,'removalMinCopies':2,'shopMinRatio':.11,'restHpPct':65,'potionHealMissing':35,'routeLowHpPct':65,'shopGoldLow':90,'shopGoldHigh':150}
    for path in policies[0]:
        tm=statistics.median(policies[i][path] for i in top_ids); rm=statistics.median(policies[i][path] for i in rest_ids)
        if path in ranges:
            thresholds.append({'path':path,'topMedian':tm,'restMedian':rm,'difference':tm-rm,'rangeFraction':(tm-rm)/ranges[path]})
        elif rm>0 and tm>0:
            magnitude.append({'path':path,'topMedian':tm,'restMedian':rm,'ratio':tm/rm})
    magnitude.sort(key=lambda x:abs(math.log(x['ratio'],2)),reverse=True)
    thresholds.sort(key=lambda x:abs(x['rangeFraction']),reverse=True)
    result['audit'][gkey]={'topPolicies':200,'cutoffWinRate':top_p[-1][0],'magnitude':magnitude[:5],'thresholds':thresholds[:5]}
json.dump(result,open(argv[2],'w'),indent=2)
print(json.dumps({k:result[k] for k in ['runs','outcomes','deckCuts','medians','bothHighRuns']},indent=2))
for k,v in result['verdicts'].items(): print(k,v)
for k,v in result['audit'].items(): print('AUDIT',k,v)
