"""Reuse already-decided Hand consumer contrasts; no games or new inference.

The conditional theorem concerns source-only redefinitions with identical 11/10
semantics, policy, assignment and readout. It does not reject new content,
progression contexts, independently specified policies or different estimands.
"""
from __future__ import annotations
import hashlib
import itertools
import json
import math
from pathlib import Path
import re
import sys
import tarfile
import unittest

ROOT = Path('research/p9-six-route')
BASE = ROOT/'ash-inheritance-20260909'
HERE = BASE/'nightsight-opportunity-v1'
STUDIES = {
    'linear': (BASE/'hand-value-v1', '150b9f0e849cfec053a4457f8ca534d42cba0c53',
               'COMPLETE_HAND_ADAPTIVE_VALUE_COLD_READBACK'),
    'two_slope': (BASE/'hand-two-slope-v1/adaptive-value-v1',
                  '5d738f65e6302dd33a8b5c2a22d60e38bca6c471',
                  'COMPLETE_TWO_SLOPE_ADAPTIVE_VALUE_COLD_READBACK'),
}
PRESERVED_AXES = ('content', 'all_source_on_semantics', 'consumer_off_semantics',
                  'policy', 'initial_profile', 'assignment', 'readout')


def require(ok, why):
    if not ok: raise ValueError(why)


def sha(b): return hashlib.sha256(b).hexdigest()
def blob(b): return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def load(p): return json.loads(p.read_bytes())
def save(p, x): p.write_text(json.dumps(x, indent=2, sort_keys=True)+'\n')


def same_consumer_experiment(old, proposed):
    """Identity gate, not semantic equivalence inferred from matching labels."""
    require(set(old)==set(proposed)==set(PRESERVED_AXES), 'IDENTITY_SCHEMA')
    require(all(isinstance(old[k], str) and old[k] and
                isinstance(proposed[k], str) and proposed[k] for k in old), 'IDENTITY_VALUES')
    return all(old[k]==proposed[k] for k in PRESERVED_AXES)


def consumer_gate(stage):
    require(stage['rows_per_world']==512 and stage['policy_configurations']==128
            and stage['distinct_seed_blocks']==256, 'FIXED_ASSIGNMENT')
    wins=stage['wins']; c=stage['contrasts']['consumer']
    require(set(wins)=={'00','01','10','11'} and
            all(type(x) is int and 0<=x<=512 for x in wins.values()), 'WIN_TYPES')
    point=(wins['11']-wins['10'])/512
    require(c['point']==point, 'CONTRAST_ARITHMETIC')
    lo,hi=c['interval']
    require(all(type(x) in (int,float) and math.isfinite(x) for x in (lo,hi))
            and lo<=hi, 'INTERVAL')
    require(c['positive_lower_bound'] is (lo>0), 'FROZEN_SIGN')
    require(stage['resource_pass'] is True and
            all(math.isfinite(x) and 0<=x<=3600 for x in stage['cpu_seconds'].values()), 'RESOURCES')
    return {'wins_11':wins['11'], 'wins_10':wins['10'], 'point':point,
            'frozen_interval':c['interval'], 'passes_frozen_consumer_requirement':lo>0}


def funcs(s):
    ms=list(re.finditer(r'^(?:static )?func (\w+)\(',s,re.M))
    return {m[1]:s[m.start():ms[i+1].start() if i+1<len(ms) else len(s)]
            for i,m in enumerate(ms)}


def consume_inputs(repo, root, records):
    manifest=load(root/'FILES.json'); index={x['path']:x for x in manifest}
    require(len(index)==len(manifest), 'DUPLICATE_INPUT_PATH')
    for name in ('TERMINAL.json','SOURCE-MANIFEST.json','runtime-source.tar.xz'):
        b=(root/name).read_bytes(); rec=index[name]
        require(len(b)==rec['bytes'] and sha(b)==rec['sha256'], 'INPUT_BYTES:'+name)
        records.append({**rec, 'path':str((root/name).relative_to(repo))})
    return load(root/'SOURCE-MANIFEST.json')


def pair_source_binding(capture, manifests):
    a,b=manifests['10'],manifests['11']
    require(set(a)==set(b), 'SOURCE_COVERAGE')
    differences=[n for n in a if a[n]!=b[n]]
    require(differences==['observed_game.gd'], 'PAIR_SEMANTIC_DELTA')
    with tarfile.open(capture/'runtime-source.tar.xz','r:xz') as tf:
        source={}
        for world in ('10','11'):
            m=tf.getmember(world+'/observed_game.gd'); require(m.isfile(), 'REGULAR_SOURCE')
            data=tf.extractfile(m).read(); rec=manifests[world]['observed_game.gd']
            require(len(data)==rec['bytes'] and sha(data)==rec['sha256'], 'OBSERVER_BYTES')
            source[world]=data.decode()
        transformed=source['11']
        for old,new in [('rules.set("hand_phantom_enabled", true)',
                         'rules.set("hand_phantom_enabled", false)'),
                        ('rules.get("hand_phantom_enabled") == true',
                         'rules.get("hand_phantom_enabled") == false')]:
            require(transformed.count(old)==1, 'CONSUMER_ASSIGNMENT_ANCHOR')
            transformed=transformed.replace(old,new,1)
        require(transformed==source['10'], 'ONLY_CONSUMER_FLAG_DIFFERS')
        for s in source.values():
            for flag in ('hand_preparation_enabled','hand_surge_enabled'):
                require('rules.set("'+flag+'", true)' in s and
                        'rules.get("'+flag+'") == true' in s, 'BOTH_SOURCE_GROUPS_ON')
    return {'all_nonobserver_sources_equal':True,
            'only_pair_observer_delta':'consumer construction/check boolean',
            'source_group_enabled_in_both':True,
            'observer_identity':{w:manifests[w]['observed_game.gd'] for w in ('10','11')}}


def eligibility(repo, manifests, records):
    study=repo/STUDIES['two_slope'][0]/'execution-1'
    availability=repo/HERE/'availability-1'
    proof=load(availability/'REMOTE-READBACK.json')
    require(proof['all_bytes_equal'] is True and proof['source_proof_reproduced'] is True,
            'UNVERIFIED_AVAILABILITY')
    data=load(availability/'RESULTS.json')
    require(data['status']=='NIGHTSIGHT_EXCLUDED_FROM_BOUND_INITIAL_POOL', 'AVAILABILITY_STATE')
    with tarfile.open(study/'runtime-source.tar.xz','r:xz') as tf:
        src={}
        for name in ('content/full-content.json','domain/state/run_state.gd'):
            raw=tf.extractfile('reference/'+name).read(); rec=manifests['reference'][name]
            require(len(raw)==rec['bytes'] and sha(raw)==rec['sha256'], 'STARTER_SOURCE')
            src[name]=raw
        content=json.loads(src['content/full-content.json'])
        constructor=funcs(src['domain/state/run_state.gd'].decode())['new_run']
        require('content.aspects[rs.aspect]' in constructor and
                'var deck_ids: Array = cp.get("startDeck", [])' in constructor and
                'rs.player.deck.append(CardInst.new(rs.next_uid(), StringName(str(id_v)), false))' in constructor,
                'STARTER_CONSTRUCTION')
    rows=[]
    for r in data['authored_draw_producer_inventory']:
        r=dict(r)
        r['starter_copies_by_aspect']={a['id']:a['startDeck'].count(r['card']) for a in content['aspects']}
        r['access_class']=('starter_or_pool' if any(r['starter_copies_by_aspect'].values())
                           or r['in_initial_pool_upper_bound'] else 'absent_from_initial_starter_and_pool')
        r['qualification']='source membership only; not natural frequency, causal value or strategy admission'
        rows.append(r)
    spark=[r for r in rows if r['card']=='firstSpark']
    require(len(spark)==2 and all(set(r['starter_copies_by_aspect'].values())=={1} for r in spark), 'STARTER_FACT')
    return {'draw_sources':rows,'starter_construction':constructor,
            'source_identities':{k:sha(v) for k,v in src.items()},
            'important_limit':'Initial pool exclusion alone is not starter exclusion. No progression profile is changed.'}


def run(repo, out):
    require(not out.exists(), 'NO_OVERWRITE')
    records=[]; decisions={}; frames={}
    for label,(rel,contract_blob,readback_kind) in STUDIES.items():
        root=repo/rel; capture=root/'execution-1'
        raw=(root/'CONTRACT.json').read_bytes();require(blob(raw)==contract_blob, 'CONTRACT_IDENTITY')
        contract=json.loads(raw)
        require(contract['operator']['worlds']=={'00':[False,False,False],'01':[False,False,True],
                '10':[True,True,False],'11':[True,True,True]}, 'ORIGINAL_WORLD_DEFINITION')
        require(contract['primary']['contrasts']==['11-01','11-10','11-10-01+00'] and
                contract['primary']['positive_lower_bounds_required']==3, 'UNCHANGED_REQUIRED_CONTRAST')
        proof=load(capture/'REMOTE-READBACK.json');terminal=load(capture/'TERMINAL.json')
        require(proof['kind']==readback_kind and proof['all_bytes_equal'] is True and
                proof['scientific_status']==terminal['status'] and proof['reproduced_stages']==['5'], 'COMPLETE_INPUT_PROOF')
        require('NOT_ESTABLISHED' in terminal['status'] and list(terminal['stages'])==['5'], 'CLOSED_INPUT')
        manifests=consume_inputs(repo,capture,records);frames[label]=manifests
        binding=pair_source_binding(capture,manifests)
        gate=consumer_gate(terminal['stages']['5'])
        require(gate['passes_frozen_consumer_requirement'] is False, 'NO_FAILED_GATE_TO_REUSE')
        decisions[label]={'original_status':terminal['status'], 'consumer_gate':gate,
            'contract_blob':contract_blob,'capture':str(rel/'execution-1'),
            'terminal_sha256':sha((capture/'TERMINAL.json').read_bytes()),'pair_binding':binding,
            'decision':'Do not open source-only retries with identical paired worlds, assignment and reader.'}
    availability=eligibility(repo,frames['two_slope'],records)
    result={'kind':'SOURCE_REDEFINITION_INVARIANT_CONSUMER_CONTRAST',
      'status':'SOURCE_ONLY_RETRY_CLASS_PRUNED_WITH_EXPLICIT_IDENTITY_PREMISES',
      'studies':decisions,'preserved_axes':list(PRESERVED_AXES),
      'proof':['For each assigned complete initial state/RNG and fixed policy, all source operators ON retain the original transitions.',
               'A source-only regrouping changes neither world11 nor world10 when the content, consumer operator, policy and profile are identical.',
               'Induction on the commands preserves each diagonal trajectory. Therefore every paired Y11-Y10 and its fixed-reader interval is unchanged.',
               'Both archived nominations already fail this necessary consumer lower-bound gate. Altering only the source-off worlds cannot make their conjunction pass.',
               'This is conditional evidence reuse for a closed fixed experiment, not an equivalence theorem for arbitrary future code.'],
      'exceptions_requiring_fresh_authorized_contract':['Changed content, payoff law/operator, independent policy context, progression profile, assignment or estimand is outside the reuse theorem.',
               'Changing an estimand or decision rule is not an implementation repair. Frozen results and scientific correction authority still apply.',
               'An interval crossing zero is not proof of no benefit, universal Hand futility or P9 impossibility.'],
      'eligibility':availability,'new_native_runs':0,'new_independent_samples':0,
      'packages_admitted':0,'p9_certified':False,'review_kind':'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT'}
    out.mkdir(parents=True);save(out/'DECISION.json',result);save(out/'INPUTS.json',records)
    save(out/'FILES.json',[{'path':p.name,'bytes':p.stat().st_size,'sha256':sha(p.read_bytes())}
                            for p in sorted(out.iterdir()) if p.is_file()])
    print(json.dumps({'status':result['status'],'consumer_gates':{k:v['consumer_gate'] for k,v in decisions.items()}},indent=2))


class Tests(unittest.TestCase):
    def identity(self):return {k:'exact-'+k for k in PRESERVED_AXES}
    def stage(self):
        return {'rows_per_world':512,'policy_configurations':128,'distinct_seed_blocks':256,
          'wins':{'00':283,'01':280,'10':306,'11':301},
          'contrasts':{'consumer':{'point':-5/512,'interval':[-16/512,5/512],'positive_lower_bound':False}},
          'resource_pass':True,'cpu_seconds':{w:100. for w in ('00','01','10','11')}}
    def test_exact_identities_can_reuse(self):self.assertTrue(same_consumer_experiment(self.identity(),self.identity()))
    def test_every_changed_axis_blocks_reuse(self):
        for k in PRESERVED_AXES:
            proposed=self.identity();proposed[k]='different'
            self.assertFalse(same_consumer_experiment(self.identity(),proposed),k)
    def test_missing_or_empty_identity_rejected(self):
        with self.assertRaisesRegex(ValueError,'IDENTITY_SCHEMA'):same_consumer_experiment({},self.identity())
        x=self.identity();x['policy']=''
        with self.assertRaisesRegex(ValueError,'IDENTITY_VALUES'):same_consumer_experiment(x,x)
    def test_source_off_outcomes_cannot_change_consumer_effect(self):
        for old00,old01,new00,new01,y10,y11 in itertools.product((0,1),repeat=6):
            self.assertEqual((old00,old01,y10,y11)[3]-(old00,old01,y10,y11)[2],
                             (new00,new01,y10,y11)[3]-(new00,new01,y10,y11)[2])
    def test_arithmetic_and_negative_gate(self):self.assertFalse(consumer_gate(self.stage())['passes_frozen_consumer_requirement'])
    def test_zero_boundary_not_positive(self):
        s=self.stage();s['contrasts']['consumer']['interval'][0]=0
        self.assertFalse(consumer_gate(s)['passes_frozen_consumer_requirement'])
    def test_positive_does_not_get_pruned_as_negative(self):
        s=self.stage();s['contrasts']['consumer']['interval']=[0.01,0.02];s['contrasts']['consumer']['positive_lower_bound']=True
        self.assertTrue(consumer_gate(s)['passes_frozen_consumer_requirement'])
    def test_false_point_rejected(self):
        s=self.stage();s['contrasts']['consumer']['point']=0
        with self.assertRaisesRegex(ValueError,'CONTRAST_ARITHMETIC'):consumer_gate(s)
    def test_nan_rejected(self):
        s=self.stage();s['contrasts']['consumer']['interval'][0]=float('nan')
        with self.assertRaisesRegex(ValueError,'INTERVAL'):consumer_gate(s)
    def test_boolean_win_rejected(self):
        s=self.stage();s['wins']['11']=True
        with self.assertRaisesRegex(ValueError,'WIN_TYPES'):consumer_gate(s)
    def test_no_transfer_from_unqualified_resource(self):
        s=self.stage();s['resource_pass']=False
        with self.assertRaisesRegex(ValueError,'RESOURCES'):consumer_gate(s)

if __name__=='__main__':
    if sys.argv[1:]==['--self-test']:unittest.main(argv=[sys.argv[0]],verbosity=2)
    else:run(*(Path(x).resolve() for x in sys.argv[1:]))
