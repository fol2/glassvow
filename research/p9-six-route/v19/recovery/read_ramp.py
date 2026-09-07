"""Reconcile every frozen raw row and describe the 2x2 stock-payoff experiment.
No policy label, nominal interval or sampled maximum is a P9 certificate.
"""
from pathlib import Path
import collections, hashlib, json, math, sys
import numpy as np
R=Path(__file__).resolve().parent

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def wilson(w,n):
    z=1.959963984540054;p=w/n;d=1+z*z/n
    m=(p+z*z/(2*n))/d;h=z*math.sqrt(p*(1-p)/n+z*z/(4*n*n))/d
    return [m-h,m+h]

def audit(folder):
    f=json.loads((folder/'freeze.json').read_text());raw={};stats=[]
    assert f['purpose']=='EXPLORATION_NOT_P9'
    for s in f['specs']:
        k=s['id'];assert k not in raw
        r=json.loads((folder/(k+'.receipt.json')).read_text())
        assert r['spec']==s and r['observer']==f['observer'] and r['complete'] and r['exit_code']==0
        for ext,name in [('.ndjson','output_sha256'),('.log','log_sha256'),('.json','config_sha256')]:
            assert sha(folder/(k+ext))==r[name],(k,name)
        assert json.loads((folder/(k+'.json')).read_text())==s
        assert r['content_sha256']==f['observer']['content_files'][s['content_path']]
        objects=[json.loads(v) for v in (folder/(k+'.ndjson')).read_text().splitlines()]
        m,rows=objects[0],objects[1:]
        assert m['config']==s and m['content_sha256']==r['content_sha256']
        assert m['policy_sha256']==f['observer']['sources']['lab_policy.gd']
        assert m['driver_sha256']==f['observer']['sources']['lab_runner.gd']
        assert (m['engine']['major'],m['engine']['minor'],m['engine']['patch'],m['engine']['status'])==(4,7,2,'stable')
        assert [x['seed'] for x in rows]==list(range(s['seed0'],s['seed0']+s['runs']))
        for x in rows:
            assert x['kind']=='row' and x['result'] in ['win','loss','stall','error']
            assert all(x[t]==s[t] for t in ['aspect','vow','route','random_build','random_play'])
            if x['result']=='win':
                assert x['act']==3 and x['hp']>0 and x['fights'][-1]['kind']=='boss' and x['fights'][-1]['result']=='win'
            mk=x['mechanism']
            assert sum(v for a,v in mk.items() if a.startswith('actual_hp_removed:'))==mk.get('actual_hp_removed_total',0)
        log=(folder/(k+'.log')).read_text()
        assert not any('ERROR' in line or line.startswith(('LAB_','Error:')) for line in log.splitlines())
        co=collections.Counter(x['result'] for x in rows)
        assert dict(co)==r['counts'] and len(rows)==r['n']
        mk=collections.Counter();acq=collections.Counter();offers=collections.Counter();used=collections.Counter()
        for x in rows:
            mk.update(x['mechanism'])
            acq.update({a:1 for a,n in x['picked'].items() if n})
            offers.update({a:1 for a,n in x['offered'].items() if n})
            used.update({a:1 for a,n in x['played'].items() if n})
        total=mk.get('actual_hp_removed_total',0)
        raw[k]=rows
        stats.append({'id':k,'recipe':Path(s['content_path']).stem,'aspect':s['aspect'],'vow':s['vow'],'route':s['route'],'random_build':s['random_build'],
          'n':len(rows),'wins':co['win'],'counts':dict(co),'rate':co['win']/len(rows),'nominal_wilson95':wilson(co['win'],len(rows)),
          'native_seconds':r['seconds'],'acquired_runs':dict(acq),'offered_runs':dict(offers),'used_runs':dict(used),
          'mechanism':dict(mk),'poison_health_fraction':mk.get('poison_hp_removed',0)/max(1,total),
          'health_source_fractions':{a.split(':',1)[1]:v/max(1,total) for a,v in mk.items() if a.startswith('actual_hp_removed:')},
          'mean_turns_per_run':sum(sum(t['turns'] for t in x['fights']) for x in rows)/len(rows)})
    total=sum((collections.Counter(s['counts']) for s in stats),collections.Counter())
    return {'status':'RAW_RECONCILED_EXPLORATION_NOT_P9','freeze_sha256':sha(folder/'freeze.json'),'rows':sum(s['n'] for s in stats),'counts':dict(total),'cells':stats},raw

def describe(report,raw):
    recipes=['hard_consumer_hard_ward','hard_consumer_smooth_ward','smooth_consumer_hard_ward','smooth_consumer_smooth_ward']
    grouped={}
    for s in report['cells']:grouped.setdefault((s['recipe'],s['aspect'],s['vow']),[]).append(s)
    diagnostics=[]
    for (recipe,a,v),group in sorted(grouped.items()):
        rb=[s for s in group if s['random_build']];p=[s for s in group if not s['random_build']]
        if not p or not rb:continue
        top=max(s['rate'] for s in p);random=max(s['rate'] for s in rb);floor=(top+random)/2
        diagnostics.append({'recipe':recipe,'aspect':a,'vow':v,'sampled_top':top,'random_screen':random,'top_gap':top-random,
            'weakest_midpoint_margin':min(s['rate'] for s in p)-floor,'sampled_spread':max(s['rate'] for s in p)-min(s['rate'] for s in p),
            'minimum_diagnostic_margin':min(top-random-.35,.5-random,min(s['rate'] for s in p)-floor)})
    effects=[]
    for a,rs in [(0,['facet','fervor','cycle','balanced']),(1,['smolder','hand','ember','balanced'])]:
        for v in [0,5]:
            for route in rs:
                suffix=f'-a{a}-{route}-v{v}'+('-RB' if route=='balanced' else '')
                values=[];seeds=None
                for name in recipes:
                    rows=raw[name+suffix]
                    ss=[x['seed'] for x in rows]
                    if seeds is None:seeds=ss
                    assert seeds==ss
                    values.append(np.array([int(x['result']=='win') for x in rows]))
                A,B,C,D=values
                for label,d in [('consumer',((C-A)+(D-B))/2),('ward',((B-A)+(D-C))/2),('interaction',D-C-B+A)]:
                    rng=np.random.default_rng(9125);n=len(d)
                    boot=d[rng.integers(0,n,(10000,n))].mean(axis=1)
                    effects.append({'aspect':a,'vow':v,'route':route,'effect':label,'estimate':float(d.mean()),
                        'seed_clusters':n,'nominal_cluster_bootstrap95':np.quantile(boot,[.025,.975]).tolist()})
    report['diagnostics']=diagnostics;report['factorial_effects']=effects
    report['limitations']=['Exploratory nominal inference; no corrected six-package admission.',
      'Same assigned seed is not identical downstream RNG. Contexts/controllers share seed clusters.',
      'Balanced RandomBuild is not the signed P9 acceptance arm.',
      'A source-health fraction is descriptive, not an isolated mediation effect.',
      'Stock-eight anchoring is not global-power neutrality; native Ember cap is 9/12.',
      'No fresh optimisation/retention, detector, lifecycle or exact merged P9 receipt.']
    return report

if __name__=='__main__':
    folder=R/'studies'/sys.argv[1]
    report,raw=audit(folder)
    if sys.argv[1]=='ramp_screen':report=describe(report,raw)
    (folder/'audit.json').write_text(json.dumps(report,indent=2)+'\n')
    print('AUDIT',report['rows'],report['counts'],'CELLS',len(report['cells']))
    for d in report.get('diagnostics',[]):print(d['recipe'],d['aspect'],d['vow'],d['sampled_top'],d['random_screen'],round(d['minimum_diagnostic_margin'],4))
