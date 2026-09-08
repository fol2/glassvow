"""Recover the historical hand producer predicate on every existing arm row.

Missing phantomDamage is UNKNOWN, not zero. This is a post-observation census;
no runtime, policy or sample is added and no historical support gate is applied
at the wrong sampling unit.
"""
import json,tarfile
from pathlib import Path
from census import ARCHIVE, require, sha, encode, decode, dump


def build(archive):
    archive=Path(archive)
    require(sha(archive.read_bytes())==ARCHIVE,'original archive')
    groups=[]
    with tarfile.open(archive,'r:xz') as tf:
        for cat in ('original','candidate'):
            for aspect in ('duskblade','ashwarden'):
                for vow in (0,5):
                    for arm in (1,2,3,4):
                        name=f'screen/{cat}-{aspect}-v{vow}-arm{arm}.ndjson'
                        raw=tf.extractfile(name).read();rows=[json.loads(x) for x in raw.splitlines()[1:]]
                        require(len(rows)==64 and [r['seed'] for r in rows]==list(range(45010000,45010064)),'cohort')
                        paired=[];observed=[];positive=[]
                        for r in rows:
                            deck=r['deckIds'];ev=r['packageEvents']
                            paired.append('phantomBlades' in deck and ev.get('phantomBladesPlayed',0)>0 and any(p in deck and ev.get(p+'Played',0)>0 for p in ('preparation','surge')))
                            observed.append('phantomDamage' in ev)
                            positive.append('phantomDamage' in ev and ev['phantomDamage']>0)
                        groups.append([cat,aspect,vow,arm,sha(raw),encode(paired),encode(observed),encode(positive)])
    return {'kind':'HISTORICAL_HAND_PREDICATE_COVERAGE_NOT_ADMISSION','source_archive_sha256':ARCHIVE,
            'seed0':45010000,'n':64,'groups':groups,
            'columns':['catalogue','aspect','vow','arm','source_sha256','final_coplay','payoff_observed','payoff_positive_if_observed']}


def analyze(primary,census):
    require(primary['kind']=='HISTORICAL_HAND_PREDICATE_COVERAGE_NOT_ADMISSION' and primary['source_archive_sha256']==ARCHIVE,'binding')
    require(primary['n']==64 and primary['seed0']==45010000,'seed binding')
    seen=set();result=[]
    for cat,aspect,vow,arm,h,p,o,d in primary['groups']:
        key=(cat,aspect,vow,arm);require(key not in seen,'duplicate context');seen.add(key)
        name=f'screen/{cat}-{aspect}-v{vow}-arm{arm}.ndjson'
        require(census['source_files'][name]['sha256']==h,'source file identity')
        pp,oo,dd=map(decode,(p,o,d))
        require(all(not b or a for a,b in zip(oo,dd)),'unobserved payoff cannot be positive')
        result.append({'catalogue':cat,'aspect':aspect,'vow':vow,'arm':arm,'n':64,
          'final_producer_consumer_coplay':sum(pp),'payoff_field_observed':sum(oo),
          'complete_historical_activation_count':sum(a and b for a,b in zip(pp,dd)) if all(oo) else None,
          'unknown_payoff_rows':64-sum(oo)})
    expected={(c,a,v,k) for c in ('original','candidate') for a in ('duskblade','ashwarden') for v in (0,5) for k in (1,2,3,4)}
    require(seen==expected,'full context coverage')
    return {'status':'HAND_FAMILY_PROXIES_RECONCILED_REQUIRED_PAYOFF_OBSERVATION_MISSING',
            'cells':result,'rows':2048,'new_native_runs':0,'new_independent_samples':0,
            'independent_policy_count':None,'packages_admitted':0,
            'decision':'Do not classify the family using Night Sight alone or claim that old activation was reproduced without phantomDamage. Complete current source-specific observer/intervention semantics before a fresh support panel.'}


if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser();p.add_argument('archive');p.add_argument('out',type=Path);a=p.parse_args()
    a.out.write_bytes(dump(build(a.archive)))
