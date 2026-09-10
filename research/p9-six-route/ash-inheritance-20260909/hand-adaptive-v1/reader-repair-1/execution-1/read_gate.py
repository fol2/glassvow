"""Complete fixed mask/clone proof, not independent or population certification."""
from itertools import product
import json
import lzma
from pathlib import Path


def require(ok, why):
    if not ok: raise ValueError(why)


def rows(path, expected):
    path=Path(path)
    if not path.exists(): path=Path(str(path)+'.xz')
    b=lzma.decompress(path.read_bytes()) if path.suffix=='.xz' else path.read_bytes()
    data=[json.loads(line) for line in b.splitlines()]
    require(len(data)==expected+1 and data[-1]=={'kind':'terminal','cases':expected},'COMPLETE_CAPTURE')
    require([r['case'] for r in data[:-1]]==list(range(expected)),'CASE_ORDER')
    return data[:-1]


def key(r): return (r['source'],r['up'],r['aspect'],r['vow'],r['context'],r['mask'])


def visible(r): return {k:v for k,v in r.items() if k!='case'}


def check(root):
    root=Path(root)
    base=rows(root/'reference.jsonl',48)
    all_rows=rows(root/'qualified.jsonl',384)
    expected=set(product(('preparation','surge'),(False,True),(0,1),(0,5),('plain','empty','branch'),range(8)))
    require(len({key(r) for r in all_rows})==384 and {key(r) for r in all_rows}==expected,'EXACT_MATRIX')
    reference={key(r):r for r in base}
    require(set(reference)=={k for k in expected if k[-1]==7},'REFERENCE_MATRIX')
    for r in all_rows:
        f=[bool(r['mask'] & (1<<i)) for i in range(3)]
        require(r['flags']==r['exact_flags']==r['public_flags']==f,'CLONE_FLAG_RETENTION')
        require(r['readonly'] is True and r['catalogue_unchanged'] is True,'LIVE_OR_CATALOGUE_MUTATION')
        if r['mask']==7: require(visible(r)==visible(reference[key(r)]),'DEFAULT_ON_FULL_QUERY_AND_STATE_PARITY')
        s=r['source'];u=r['up'];source=r['source_data'];consumer=r['consumer_data']
        energy=(2 if u else 1) if s=='surge' else 0
        draw=(2 if s=='preparation' else 1) if f[0 if s=='preparation' else 1] else 0
        expected_effects=([{'kind':'energy','n':energy}] if energy else [])+([{'kind':'draw','n':draw}] if draw else [])
        require(source['effects']==expected_effects and source['cost']==0,'EXACT_RESOLVED_SOURCE')
        require(consumer['effects']==[{'kind':'special','id':'phantom','n':(4 if u else 3) if f[2] else 0}]
                and consumer['cost']==1,'EXACT_RESOLVED_CONSUMER')
        prefix=r['source_after']['combat'];end=r['after']['combat']
        available=r['context']!='empty'
        background=int(r['context']=='branch' and source.get('exhaust',False))
        drawn=(draw+background) if available else 0
        require([x['uid'] for x in prefix['hand']]==[10002,10003]+list(range(10105,10105-drawn,-1)),'DRAW_INSTANCE_PROVENANCE')
        require(prefix['player']['energy']==1+energy and end['player']['energy']==energy,'BASE_ENERGY_AND_PAYMENT')
        require(prefix['player']['hp']==r['before']['combat']['player']['hp'],'SOURCE_HP_UNCHANGED')
        require(len(prefix['exhaust'])==int(source.get('exhaust',False)),'EXHAUST_PRESERVED')
        loss=((4 if u else 3)*(1+drawn) if f[2] else 0)+2
        require(end['enemies'][0]['hp']==1000-loss,'NATIVE_HAND_PAYOFF')
        require(r['after']==r['exact_after'] and r['events']==r['exact_events'],'EXACT_CLONE_TRANSITION')
        require(r['public_after']['combat']['enemies'][0]['hp']==1000-loss,'PUBLIC_CLONE_NATIVE_PAYOFF')
        require(r['source_ret'] is True and r['after']['return'] is True,'LEGAL_COMMANDS')
    killed={}
    for name,missing,other in [('public-mutant','public_flags','exact_flags'),('exact-mutant','exact_flags','public_flags')]:
        data=rows(root/(name+'.jsonl'),48)
        require({key(r) for r in data}=={k for k in expected if k[-1]==0},'MUTANT_MATRIX')
        for r in data:
            require(r['flags']==r[other]==[False,False,False] and r[missing]==[True,True,True], 'NAMED_FLAG_MUTANT')
            require(r['readonly'] and r['catalogue_unchanged'],'UNRELATED_MUTANT_FAILURE')
        killed[name]=len(data)
    return {'status':'HAND_ADAPTIVE_QUERY_CLONE_QUALIFIED_NOT_CERTIFICATE',
            'qualified_cases':384,'default_on_reference_cases':48,'named_mutants_detected':killed,
            'source_energy_exhaust_and_background_draw_preserved':True,
            'all_instance_ids_not_fixed_fixture_uids':True,'all_three_masks_retained_by_both_clone_paths':True,
            'full_all_on_policy_queries_and_state_transitions_equal':True,
            'limits':['Constructed plumbing proof, not independent runtime/source oracle or population value.',
                      'Existing null preview behaviour for unsupported native specials is retained; no new preview prediction capability is claimed.',
                      'Preparation and Surge are alternative sources of one Hand family, not separate strategies.',
                      'Descriptor predictive validity, adaptive whole-run value, policy/economy and independent confirmation remain open.'],
            'new_population_outcomes':0,'new_independent_samples':0,'packages_admitted':0,'p9_certified':False}
