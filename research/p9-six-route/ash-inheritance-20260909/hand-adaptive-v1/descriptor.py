"""Realised Hand provenance, not counterfactual damage or package admission.
Read every retained assigned aware run. No fitting, new game, selected-success
cohort, or change to the frozen model. Validate field semantics on the already
captured complete mask matrix, including independent background relic draw.
"""
from collections import Counter
import copy
import hashlib
import importlib.util
import json
import lzma
from pathlib import Path
import sys
import tarfile
import unittest

HERE=Path('research/p9-six-route/ash-inheritance-20260909/hand-adaptive-v1')
OLD=Path('research/p9-six-route/ash-inheritance-20260909/joint-controller-v1/execution-1')
MANIFEST='cc2081e21e7c603ef0624e399aeaab978a63f9d6'
SOURCES={'preparation','surge'}


def require(ok,why):
    if not ok:raise ValueError(why)


def sha(b):return hashlib.sha256(b).hexdigest()
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def load(p):return json.loads(p.read_bytes())
def save(p,v):p.write_text(json.dumps(v,indent=2)+'\n')
def stream(p):
    op=lzma.open if p.suffix=='.xz' else open
    with op(p,'rt',encoding='utf-8') as f:
        for line in f:
            require(bool(line.strip()),'EMPTY_LINE');yield json.loads(line)


def hand_ids(hand):
    ids=[c['uid'] for c in hand];require(len(set(ids))==len(ids),'DUPLICATE_HELD_INSTANCE');return ids


def draws(events, card, legal, origins):
    """Source direct effects precede its native Exhaust hook. Other draw resets origin."""
    exhausted=False
    for e in events:
        if e.get('t')=='exhaust':exhausted=True
        if e.get('t')=='draw':
            origins[e['uid']]=card if card in SOURCES and legal and not exhausted else 'background'


def fields(hand, consumer_uid, coefficient, origins):
    ids=hand_ids(hand);require(consumer_uid in ids,'CONSUMER_NOT_HELD')
    retained=[u for u in ids if u!=consumer_uid]
    direct={s:[u for u in retained if origins.get(u)==s] for s in sorted(SOURCES)}
    counts={s:len(v) for s,v in direct.items()}
    return {'retained_hand_instances':len(retained),'retained_direct_source_instances':counts,
            'retained_direct_source_uids':direct,'consumer_draw_origin':origins.get(consumer_uid,'unattributed'),
            'hand_coefficient':coefficient,'direct_source_hand_term_units':coefficient*sum(counts.values()),
            'scope':'Structural hand-count term before native attack envelope; not marginal HP, policy value or a causal effect estimate.'}


def finite_check(root):
    spec=importlib.util.spec_from_file_location('qualified_hand_reader',root/'reader-repair-1/execution-1/read_gate.py')
    reader=importlib.util.module_from_spec(spec);spec.loader.exec_module(reader)
    original=root/'execution-1';reader.check(original)
    cases=reader.rows(original/'qualified.jsonl',384)
    labelled={};unknown_draws=0
    for r in cases:
        origins={};draws(r['source_events'],r['source'],r['source_ret'] is True,origins)
        held=r['source_after']['combat']['hand']
        played=[e for e in r['events'] if e.get('t')=='play']
        require(len(played)==1 and played[0]['id']=='phantomBlades','PHANTOM_COMMAND')
        coefficient=r['consumer_data']['effects'][0]['n']
        f=fields(held,played[0]['uid'],coefficient,origins)
        slot=0 if r['source']=='preparation' else 1
        direct=(2 if slot==0 else 1) if r['mask'] & (1<<slot) and r['context']!='empty' else 0
        require(sum(f['retained_direct_source_instances'].values())==direct,'DIRECT_VS_BACKGROUND_DRAW')
        remapped=[dict(c,uid=c['uid']+100000) for c in held]
        altered=fields(remapped,played[0]['uid']+100000,coefficient,{u+100000:v for u,v in origins.items()})
        require(altered['direct_source_hand_term_units']==f['direct_source_hand_term_units'] and altered['retained_direct_source_instances']==f['retained_direct_source_instances'],'UID_RENAMING')
        k=(r['source'],r['up'],r['aspect'],r['vow'],r['context'],r['mask'])
        labelled[k]=(r,f)
    checks=0;zero=0
    for key,(r,f) in labelled.items():
        source_bit=1 if key[0]=='preparation' else 2
        if not key[-1]&source_bit or not key[-1]&4:continue
        base=key[-1]&~(source_bit|4)
        worlds=[labelled[key[:-1]+(base|bits,)] for bits in (0,source_bit,4,source_bit|4)]
        loss=[1000-x[0]['after']['combat']['enemies'][0]['hp'] for x in worlds]
        interaction=loss[3]-loss[2]-loss[1]+loss[0]
        require(interaction==f['direct_source_hand_term_units'],'FINITE_INTERACTION_FIELD')
        checks+=1;zero+=int(interaction==0)
    require(checks==96 and zero==32,'FINITE_DESCRIPTOR_COVERAGE')
    return {'mask_cases':384,'uid_renaming_checks':384,'complete_factorial_contrasts':checks,
            'zero_source_contrasts_retained':zero,'scope':'Only the frozen finite matrix; not general predictive or held-out descriptor admission.'}


def run(repo,out):
    root=repo/HERE;old=repo/OLD
    require(not out.exists(),'OUTPUT_EXISTS');out.mkdir(parents=True)
    require(blob((old/'FILES.json').read_bytes())==MANIFEST,'INPUT_MANIFEST')
    require(load(old/'REMOTE-READBACK.json')['all_bytes_equal'] is True,'INPUT_NOT_READ_BACK')
    receipt=load(root/'reader-repair-1/execution-1/REMOTE-READBACK.json')
    require(receipt['readout_reproduced'] is True,'UNQUALIFIED_MASKS')
    bounded=finite_check(root)
    entries={r['path']:r for r in load(old/'FILES.json')};observed=[]
    def bound(rel):
        p=old/rel;b=p.read_bytes();r=entries[rel]
        require(len(b)==r['bytes'] and sha(b)==r['sha256'],'CAPTURE_BYTES:'+rel)
        observed.append({'path':rel,**r});return p
    with tarfile.open(bound('runtime-source.tar.xz'),'r:xz') as tf:
        content=tf.extractfile('aware/content/full-content.json').read()
    require(sha(content)=='4107c7c0bbed5d9acf8c2bdf97023552426920242ea958c8ebdec793b712afd9','CONTENT')
    card=json.loads(content)['cards']['phantomBlades'];coefficients={False:card['effects'][0]['n'],True:card['up']['effects'][0]['n']}
    expected={f'5:{i}:{seed}' for i in range(128) for seed in range(73414100,73414104)}
    runs={};counts=Counter();policies=set();access_policies=set();cmds=0
    with (out/'FIELDS.jsonl').open('w') as output:
        for first in range(0,128,2):
            p=bound(f'v5/aware/v5-{first:03d}.traces.jsonl.xz')
            current=None;origins={};prior=None;sequence=0;fight=-1
            for r in stream(p):
                key=r['row_key'];require(key in expected,'UNASSIGNED_ROW')
                if key!=current:
                    require(key not in runs,'DUPLICATE_RUN');runs[key]={'commands':0,'phantom_plays':0,'direct_source_plays':0,'consumer_access_plays':0}
                    current=key;origins={};prior=None;sequence=0;fight=-1
                require(r['kind']=='command' and r['sequence']==sequence and r['original_untouched_by_clones'] is True,'COMMAND_IDENTITY')
                sequence+=1;cmds+=1;runs[key]['commands']+=1
                before=hand_ids(r['before']['hand']);after=hand_ids(r['after']['hand'])
                require(prior is None or before==prior,'HAND_CONTINUITY')
                if r['fight']!=fight:origins={};fight=r['fight']
                if r['card']=='phantomBlades' and r['ret'] is True:
                    uid=r['command']['uid'];inst=next(c for c in r['before']['hand'] if c['uid']==uid)
                    f=fields(r['before']['hand'],uid,coefficients[bool(inst['up'])],origins)
                    sourced=sum(f['retained_direct_source_instances'].values())>0
                    access=f['consumer_draw_origin'] in SOURCES
                    runs[key]['phantom_plays']+=1;runs[key]['direct_source_plays']+=int(sourced);runs[key]['consumer_access_plays']+=int(access)
                    index=int(key.split(':')[1])
                    if sourced:policies.add(index)
                    if access:access_policies.add(index)
                    counts['phantom_plays']+=1;counts['with_retained_direct_source']+=int(sourced);counts['source_drew_consumer']+=int(access)
                    counts['actual_hit_positive_without_retained_direct_source']+=int(not sourced and any(e.get('t')=='hitEnemy' and e.get('amount',0)>0 for e in r['events']))
                    output.write(json.dumps({'row_key':key,'sequence':r['sequence'],'fight':fight,**f},sort_keys=True)+'\n')
                draws(r['events'],r['card'],r['ret'] is True,origins)
                origins={u:s for u,s in origins.items() if u in after};prior=after
    require(set(runs)==expected,'FULL_512_RUN_COVERAGE')
    legacy=load(bound('v5/aware-support.json'));legacy_set=set(legacy['policy_ids']['hand'])
    require(len(legacy_set)==63,'LEGACY_BINDING')
    result={'status':'HAND_REALISED_PROVENANCE_EXTRACTOR_CHECKED_NOT_DESCRIPTOR_ADMISSION',
            'finite_validation':bounded,'retained_native_runs':512,'fixed_configurations':128,'commands':cmds,
            'consumer_counts':dict(counts),'configurations_with_retained_direct_source':len(policies),
            'configurations_where_source_drew_consumer':len(access_policies),
            'legacy_active_configurations':len(legacy_set),
            'membership':{'both':len(legacy_set&policies),'legacy_only':len(legacy_set-policies),'provenance_only':len(policies-legacy_set),'neither':128-len(legacy_set|policies)},
            'limits':['Complete retained aware-arm description, not a fresh cohort or independent confirmation.',
                      'Direct-draw origin is factual history, not proof that the held instance would be absent without the source under an adaptive policy.',
                      'Branch/ordinary draws and source-enabled consumer access are explicitly separate; source-slot units are not HP or win gains.',
                      'No frozen classifier is refit or replaced. Held-out prediction, general intervention stability, peer separation and full package proof remain required.'],
            'new_native_runs':0,'new_independent_samples':0,'packages_admitted':0,'p9_certified':False}
    save(out/'RESULTS.json',result);save(out/'RUN-COVERAGE.json',runs);save(out/'INPUTS.json',observed)
    save(out/'FILES.json',[{'path':p.name,'bytes':p.stat().st_size,'sha256':sha(p.read_bytes())} for p in sorted(out.iterdir()) if p.is_file() and p.name!='FILES.json'])
    print(json.dumps(result,indent=2))


class Tests(unittest.TestCase):
    def test_exhaust_background_not_direct(self):
        o={};draws([{'t':'draw','uid':2},{'t':'exhaust'},{'t':'draw','uid':3}],'preparation',True,o)
        self.assertEqual(o,{2:'preparation',3:'background'})
    def test_non_source_draw(self):
        o={2:'surge'};draws([{'t':'draw','uid':2}],'',True,o);self.assertEqual(o,{2:'background'})
    def test_illegal_source(self):
        o={};draws([{'t':'draw','uid':2}],'surge',False,o);self.assertEqual(o,{2:'background'})
    def test_consumer_access_not_retained_slot(self):
        f=fields([{'uid':1},{'uid':2}],1,3,{1:'surge'})
        self.assertEqual(f['consumer_draw_origin'],'surge');self.assertEqual(f['direct_source_hand_term_units'],0)
    def test_disabled_payoff(self):
        self.assertEqual(fields([{'uid':1},{'uid':2}],1,0,{2:'surge'})['direct_source_hand_term_units'],0)
    def test_duplicate_identity(self):
        with self.assertRaisesRegex(ValueError,'DUPLICATE_HELD_INSTANCE'):fields([{'uid':1}]*2,1,3,{})
    def test_missing_consumer(self):
        with self.assertRaisesRegex(ValueError,'CONSUMER_NOT_HELD'):fields([{'uid':2}],1,3,{})
    def test_alternative_sources_not_combined_tags(self):
        f=fields([{'uid':1},{'uid':2},{'uid':3}],1,3,{2:'surge',3:'preparation'})
        self.assertEqual(f['retained_direct_source_instances'],{'preparation':1,'surge':1})


if __name__=='__main__':
    if sys.argv[1:]==['--self-test']:unittest.main(argv=[sys.argv[0]],verbosity=2)
    else:run(*(Path(p).resolve() for p in sys.argv[1:]))
