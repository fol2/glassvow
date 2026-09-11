"""Prove initial-pool exclusions and inventory draw producers from pinned sources.
This is not a game execution, a new progression profile or population evidence.
"""
import hashlib
import json
from pathlib import Path
import re
import sys
import tarfile
import unittest

BASE=Path('research/p9-six-route/ash-inheritance-20260909')
STUDY=BASE/'hand-two-slope-v1/adaptive-value-v1'
HERE=BASE/'nightsight-opportunity-v1'


def require(ok,why):
    if not ok:raise ValueError(why)


def sha(b):return hashlib.sha256(b).hexdigest()
def load(p):return json.loads(p.read_bytes())
def save(p,x):p.write_text(json.dumps(x,indent=2,sort_keys=True)+'\n')
def funcs(text):
    matches=list(re.finditer(r'^(?:static )?func (\w+)\(',text,re.M))
    return {m[1]:text[m.start():matches[i+1].start() if i+1<len(matches) else len(text)] for i,m in enumerate(matches)}


def pool_upper_bound(content,tier,unlocks):
    # Reveals can only remove base entries. Relax all such gates for a sound exclusion.
    result=list(content['cardPools'].get(tier,[]))
    for unlock in unlocks:
        if unlock.startswith('card:'):
            name=unlock[len('card:'):]
            if name in content['cards'] and content['cards'][name].get('rarity')==tier and name not in result:
                result.append(name)
    return result


def run(repo,out):
    require(not out.exists(),'OUTPUT_EXISTS')
    capture=repo/STUDY/'execution-1';protocol=load(repo/HERE/'PROTOCOL.json')
    blob=lambda b:hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
    require(blob((capture/'FILES.json').read_bytes())==protocol['capture_manifest_blob'],'INPUT_MANIFEST')
    index={r['path']:r for r in load(capture/'FILES.json')}
    for n in ('SOURCE-MANIFEST.json','runtime-source.tar.xz'):
        b=(capture/n).read_bytes();r=index[n]
        require(len(b)==r['bytes'] and sha(b)==r['sha256'],'CAPTURE_SOURCE')
    manifest=load(capture/'SOURCE-MANIFEST.json')['reference'];sources={};identities={}
    with tarfile.open(capture/'runtime-source.tar.xz','r:xz') as tf:
        for name,r in manifest.items():
            if not(name.endswith('.gd') or name=='content/full-content.json'):continue
            p=Path(name);require(not p.is_absolute() and '..' not in p.parts,'PATH')
            member=tf.getmember('reference/'+name);require(member.isfile(),'REGULAR_SOURCE')
            b=tf.extractfile(member).read();require(len(b)==r['bytes'] and sha(b)==r['sha256'],'SOURCE_BYTES')
            sources[name]=b.decode();identities[name]=r
    content=json.loads(sources['content/full-content.json']);cards=content['cards']
    observed=sources['tools/observed_sim.gd'];f=funcs(observed)
    factories={n:t for n,t in f.items() if 'RunState.new_run(' in t}
    require(len(factories)==1,'SINGLE_OBSERVED_FACTORY')
    name,factory=next(iter(factories.items()))
    match=re.search(r'var profile: Dictionary = \{(.*?)\n\s*\}',factory,re.S)
    require(match is not None,'PROFILE_LITERAL')
    unlocks_match=re.search(r'"unlocks"\s*:\s*(\[[^\]]*\])',match[0])
    require(unlocks_match is not None,'UNLOCK_LITERAL')
    unlocks=json.loads(unlocks_match[1]);require(unlocks==['aspect2'],'PROFILE_SCOPE')
    before_creation=factory[:factory.index('RunState.new_run(')]
    require(not re.search(r'profile\s*\[\s*["\']unlocks["\']\s*\]',before_creation),'UNREVIEWED_PROFILE_UNLOCK_MUTATION')
    reward=funcs(sources['domain/rules/rewards.gd'])['card_pool']
    require('for id_v: Variant in base:' in reward and 'for unlock_v: Variant in run.unlocks:' in reward
        and 'unlock.begins_with("card:")' in reward and 'unlock.trim_prefix("card:")' in reward,'POOL_ALGORITHM')
    all_pool=set().union(*(set(pool_upper_bound(content,t,unlocks)) for t in content['cardPools']))
    require('nightSight' not in all_pool,'SIGHT_NOT_EXCLUDED')
    deed=content['deeds'][cards['nightSight']['locked']]
    require(deed['stat']=='unlitVisited' and deed['n']==6 and 'card:nightSight' in deed['unlocks'],'DEED_BINDING')
    changed=pool_upper_bound(content,cards['nightSight']['rarity'],unlocks+deed['unlocks'])
    require('nightSight' in changed,'EXCLUSION_IS_CONTEXT_SPECIFIC')
    combat=funcs(sources['domain/rules/combat.gd'])
    special=combat['_apply_special'];clauses=list(re.finditer(r'^\t\t"([^"]+)":',special,re.M));draw_specials=[]
    for i,m in enumerate(clauses):
        body=special[m.start():clauses[i+1].start() if i+1<len(clauses) else len(special)]
        if 'draw_cards(' in body:draw_specials.append(m[1])
    inventory=[]
    for card,d in cards.items():
        variants={'base':d}
        if isinstance(d.get('up'),dict):variants['up']={**d,**d['up']}
        for variant,definition in variants.items():
            effects=[x for x in definition.get('effects',[]) if x.get('kind')=='draw' or
                     (x.get('kind')=='status' and x.get('id')=='nightsight' and x.get('who')=='self') or
                     (x.get('kind')=='special' and x.get('id') in draw_specials)]
            if effects:inventory.append({'card':card,'variant':variant,'cost':definition.get('cost'),'rarity':d.get('rarity'),
                'effects':effects,'locked':d.get('locked'),'in_initial_pool_upper_bound':card in all_pool})
    callsites={n:t for n,t in combat.items() if n!='draw_cards' and re.search(r'\bdraw_cards\(',t)}
    omens={n:d.get('mods',{}).get('drawDelta') for n,d in content['omens'].items() if d.get('mods',{}).get('drawDelta',0)!=0}
    source_methods={'observed_factory':factory,'card_pool':reward,'draw_callsites':callsites}
    if 'domain/state/vigil_state.gd' in sources:
        source_methods['vigil_refresh_unlocks']=funcs(sources['domain/state/vigil_state.gd'])['_refresh_unlocks']
    result={'kind':'INITIAL_REWARD_POOL_PRODUCER_EXCLUSION','status':'NIGHTSIGHT_EXCLUDED_FROM_BOUND_INITIAL_POOL',
        'source_profile_unlocks':unlocks,'source_factory':name,'night_sight':cards['nightSight'],'dark_walker':deed,
        'night_sight_in_any_base_pool':any('nightSight' in v for v in content['cardPools'].values()),
        'even_all_reveal_gates_open_is_insufficient':True,'countermodel_with_deed_unlock_includes_card':True,
        'countermodel_was_not_run_or_adopted':True,'authored_draw_producer_inventory':inventory,
        'direct_draw_special_ids':draw_specials,'native_direct_draw_callsite_functions':list(callsites),'omen_draw_deltas':omens,
        'limits':['Initial card-pool exclusion under the actual archived observed-simulator profile. This is not a universal theorem about every event, future run or player progression.',
                  'The hypothetical deed-unlocked pool is a source-derived countermodel, not new natural play or a change to the signed comparator.',
                  'The inventory covers authored draw effects, persistent Night Sight and directly identified draw-special clauses; source call sites are supplied for remaining conditional/background channels.',
                  'Neither pool inclusion nor co-occurrence qualifies a strategy. Every prior value result and protected context remains unchanged.'],
        'decision':'Do not test Night Sight value with the existing profile and do not quietly unlock it only for the planned arm. Use eligible in-profile producers; a different progression context requires its own explicit contract and matched signed controls.',
        'new_native_runs':0,'new_independent_samples':0,'packages_admitted':0,'p9_certified':False,
        'review_kind':'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT'}
    out.mkdir(parents=True);save(out/'RESULTS.json',result);save(out/'SOURCE.json',{'identities':identities,'methods':source_methods})
    save(out/'FILES.json',[{'path':p.name,'bytes':p.stat().st_size,'sha256':sha(p.read_bytes())} for p in sorted(out.iterdir()) if p.is_file()])
    print(json.dumps(result,indent=2))


class PoolTests(unittest.TestCase):
    def setUp(self):
        self.c={'cardPools':{'uncommon':['normal']},'cards':{'normal':{'rarity':'uncommon'},'nightSight':{'rarity':'uncommon'},'rareCard':{'rarity':'rare'}}}
    def test_locked_card_missing_even_when_reveals_ignored(self):self.assertNotIn('nightSight',pool_upper_bound(self.c,'uncommon',['aspect2']))
    def test_exact_card_unlock_is_distinct_from_reveal(self):
        self.assertNotIn('nightSight',pool_upper_bound(self.c,'uncommon',['nightSight','darkWalker']))
        self.assertIn('nightSight',pool_upper_bound(self.c,'uncommon',['card:nightSight']))
    def test_wrong_rarity_and_unknown_ids_excluded(self):self.assertEqual(pool_upper_bound(self.c,'uncommon',['card:rareCard','card:invented']),['normal'])
    def test_no_duplicate_base_or_unlock(self):self.assertEqual(pool_upper_bound(self.c,'uncommon',['card:normal','card:nightSight','card:nightSight']),['normal','nightSight'])
    def test_no_content_or_profile_mutation(self):
        before=json.dumps(self.c);profile=['aspect2'];pool_upper_bound(self.c,'uncommon',profile)
        self.assertEqual(json.dumps(self.c),before);self.assertEqual(profile,['aspect2'])


if __name__=='__main__':
    if sys.argv[1:]==['--self-test']:unittest.main(argv=[sys.argv[0]],verbosity=2)
    else:run(*(Path(x).resolve() for x in sys.argv[1:]))
