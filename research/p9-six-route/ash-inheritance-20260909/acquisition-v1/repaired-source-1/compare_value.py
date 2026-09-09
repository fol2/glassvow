"""Fixed paired-controller contrast, distinct from full P9 or package admission."""
import math
import random


def require(ok,why):
    if not ok:raise ValueError(why)


def probability(new_only,old_only):
    n=new_only+old_only
    return sum(math.comb(n,k) for k in range(new_only,n+1))/2**n if n else 1.0


def interval(values):
    rng=random.Random(421);n=len(values)
    draws=sorted(sum(values[rng.randrange(n)] for _ in range(n))/n for _ in range(5000))
    return [draws[int(.025*4999)],draws[int(.975*4999)]]


def compare(stock,aware,p):
    require(stock['vow']==aware['vow'] and stock['rows']==aware['rows']==512,'COMPLETE_PAIRED_RECTANGLES')
    old={r['row_key']:r for r in stock['row_results']};new={r['row_key']:r for r in aware['row_results']}
    require(set(old)==set(new) and len(old)==512,'PAIRED_IDENTITIES')
    oa=set(stock['policy_ids']['bloodfire']);na=set(aware['policy_ids']['bloodfire'])
    gained,lost=len(na-oa),len(oa-na)
    require(len(oa|na)<=128,'POLICY_COUNT')
    improvement=(len(na)-len(oa))/128
    by_policy={i:[] for i in range(128)}
    for k,r in old.items():
        nr=new[k];require((r['index'],r['seed'])==(nr['index'],nr['seed']),'ROW_PAIR')
        by_policy[r['index']].append(int(nr['outcome']=='win')-int(r['outcome']=='win'))
    require(all(len(x)==4 for x in by_policy.values()),'CLUSTER_COVERAGE')
    diffs=[sum(x)/4 for x in by_policy.values()];bounds=interval(diffs)
    win_difference=sum(diffs)/128
    gates={'paired_activation_gain':improvement>=p['value_bounds']['minimum_activation_gain'],
           'paired_activation_sign_test':probability(gained,lost)<=p['value_bounds']['one_sided_alpha_per_vow'],
           'win_point_not_worse':win_difference>=0,
           'win_noninferiority_lower_bound':bounds[0]>-p['value_bounds']['win_noninferiority_margin'],
           'inherited_pair_support':aware['pass']}
    return {'kind':'ONE_FIXED_ACQUISITION_CONTROLLER_COMPARISON','vow':stock['vow'],
            'activation_old':len(oa),'activation_new':len(na),'gained_policies':gained,'lost_policies':lost,
            'paired_activation_difference':improvement,'one_sided_exact_sign_p':probability(gained,lost),
            'win_difference':win_difference,'policy_cluster_bootstrap_interval':bounds,
            'stock_support':stock['packages'],'aware_support':aware['packages'],
            'stock_outcomes':stock['outcomes'],'aware_outcomes':aware['outcomes'],
            'gates':gates,'pass':all(gates.values()),
            'status':'ACQUISITION_CONTROLLER_VALUE_SUPPORTED_NOT_PACKAGE' if all(gates.values()) else 'FIXED_ACQUISITION_CONTROLLER_VALUE_NOT_ESTABLISHED',
            'limits':['Conditional on these four seeds and one fixed configuration family; not universal competence.',
                      'The old failed support stage is neither replaced nor extended.',
                      'Increased setup activity does not establish package viability or an unchanged C2 gap.',
                      'Current experiment has one nominated capability change; no further scalar or controller candidate is selected from this result.'],
            'packages_admitted':0,'p9_certified':False}
