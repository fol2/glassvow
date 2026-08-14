"""Layer-2 CEM readout for #216. Reads island-*.ndjson + layer-1 analysis.json.

Usage: python3 tools/balance_cem_report.py ISLAND_DIR LAYER1_ANALYSIS_JSON [OUT_JSON]
"""
import json,math,os,sys,glob,statistics
from collections import Counter,defaultdict
d=sys.argv[1]; a1=json.load(open(sys.argv[2]))
cuts=a1['deckCuts']; med=a1['medians']

def thick(n):
    return 'thin' if n<=cuts['thinMax'] else ('mid' if n<=cuts['midMax'] else 'fat')
def cell_of(r):
    fs=r.get('fights') or []; n=len(fs) or 1
    a=r['aspect']
    sr=sum(x.get('shatters',0) for x in fs)/n
    mr=sum(x.get('smolderKills',0) for x in fs)/n
    sh=sr>med[a]['shattersPerFight']; sm=mr>med[a]['smolderKillsPerFight']
    lean='shatter' if sh else ('smolder' if sm else 'attrition')
    return f"{lean}:{thick(r['deck'])}"

islands=[]
for path in sorted(glob.glob(os.path.join(d,'island-*.ndjson'))):
    gens=[]; hold=[]; final=None; man=None
    with open(path) as f:
        for line in f:
            r=json.loads(line); t=r.get('t')
            if t=='manifest': man=r
            elif t=='gen': gens.append(r)
            elif t=='holdout': hold.append(r)
            elif t=='final': final=r
    if not man or not final: continue
    counts=Counter(cell_of(r) for r in hold)
    end=counts.most_common(1)[0][0] if counts else str(final['startCell'])
    islands.append({'file':os.path.basename(path),'manifest':man,'gens':gens,'hold':hold,
        'final':final,'endCell':end,'endCounts':dict(counts),
        'ceiling':final['holdoutCeiling'],'start':str(final['startCell']),
        'grid':final['grid'],'island':final['island'],'stop':final['stop'],
        'gensN':final['gens'],'gen0':final.get('gen0Best', gens[0]['genBest'] if gens else 0),
        'ms':final.get('ms',0)})

by=defaultdict(list)
for i in islands: by[i['grid']].append(i)
grids={}
for g in ['duskblade:v0','duskblade:v5','ashwarden:v0','ashwarden:v5']:
    xs=sorted(by[g], key=lambda i:i['island'])
    v=a1['verdicts'][g]; floor=v['viabilityFloor']; top=v['topRate']
    if not xs:
        grids[g]={'islands':[],'C3':False,'C4':False,'vow5Fail':False,'n':0}; continue
    best=max(i['ceiling'] for i in xs)
    stayed=[i for i in xs if i['endCell']==i['start'] and i['ceiling']+1e-12>=floor]
    close=[i for i in stayed if i['ceiling']+1e-12>=best-0.15]
    cell_ceil=defaultdict(lambda:-1.0)
    for i in xs: cell_ceil[i['endCell']]=max(cell_ceil[i['endCell']], i['ceiling'])
    vals=sorted(cell_ceil.values(), reverse=True)
    c4=not (len(vals)<2 or vals[0]-vals[1]>=0.15-1e-12)
    vow=int(g.split(':v')[1]); v5=vow==5 and best>0.90+1e-12
    g0=sorted(i['gen0'] for i in xs); mid=statistics.median(g0)
    grids[g]={'islands':[{'island':i['island'],'start':i['start'],'end':i['endCell'],
        'ceiling':i['ceiling'],'holdoutWins':i['final']['holdoutWins'],
        'holdoutRuns':i['final']['holdoutRuns'],'gens':i['gensN'],'stop':i['stop'],
        'gen0':i['gen0'],'ms':i['ms'],'curve':[(r['gen'],r['genBest'],r['bestEver']) for r in i['gens']],
        'endCounts':i['endCounts']} for i in xs],
        'viabilityFloor':floor,'layer1Top':top,'bestCeiling':best,
        'stayedViable':len(stayed),'closeToBest':len(close),
        'C3':len(stayed)>=4 and len(close)>=3,'C4':c4,
        'cellCeilings':dict(cell_ceil),'vow5Fail':v5,
        'skillHeadroom':best-mid,'gen0Median':mid,'n':len(xs)}

out={'islands':len(islands),'grids':grids,
     'vow5Fail':any(grids[g]['vow5Fail'] for g in grids),
     'C3':{g:grids[g]['C3'] for g in grids},'C4':{g:grids[g]['C4'] for g in grids}}
if len(sys.argv)>3:
    json.dump(out, open(sys.argv[3],'w'), indent=2)
print(json.dumps({g:{k:grids[g][k] for k in grids[g] if k!='islands'} for g in grids}, indent=2))
for g,x in grids.items():
    print(f"\n== {g} ==")
    print(f"C3={x['C3']} stayedViable={x.get('stayedViable')} close={x.get('closeToBest')} C4={x['C4']} vow5Fail={x['vow5Fail']} headroom={x.get('skillHeadroom')}")
    for i in x['islands']:
        print(f"  island {i['island']}: {i['start']} -> {i['end']} holdout {i['holdoutWins']}/{i['holdoutRuns']}={i['ceiling']:.4f} gens={i['gens']} stop={i['stop']} gen0={i['gen0']:.4f} ms={i['ms']}")
        print('   curve', i['curve'])
