"""Read the complete existing original-arm archive; never execute a game.

The compact projection preserves every assigned seed's outcomes and the stated
co-ownership/co-play indicators, not state/temporal causality. Counts are a census
of this exposed fixed cohort, not new samples, policy replicates or admission.
"""
from __future__ import annotations
import hashlib
import io
import json
from pathlib import Path
import tarfile

ARCHIVE = 'b866d60d7d9dad9bbd83610c145e242ed026bf046806ca5c7cab83f4b58d326c'
CONTENT = ('a0d608a5142d2e3aab799cdf33d3163922b402c2aaf2a895e46e096399b56cf1',
           '3c7b2f9dba362d19128ef82ad559d3f26e54925371d823a665767032255eadaa')
ROUTES = ((('facet','chisel','resonantLance'),('fervor','empower','flurry'),('cycle','momentum','momentum')),
          (('smolder','venomStrike','catalyst'),('hand','nightSight','phantomBlades'),('cycle','momentum','momentum')))
FIELDS = ('producer_offered','consumer_offered','both_final_owned','both_played_anywhere','consumer_played')


def require(value, message):
    if not value:
        raise ValueError(message)


def sha(b):
    return hashlib.sha256(b).hexdigest()


def dump(obj):
    return (json.dumps(obj, separators=(',',':'), ensure_ascii=False)+'\n').encode()


def encode(bits):
    require(len(bits)==64 and all(type(b) is bool for b in bits),'64 boolean rows required')
    return f'{int("".join("1" if b else "0" for b in bits),2):016x}'


def decode(text):
    require(isinstance(text,str) and len(text)==16 and all(c in '0123456789abcdef' for c in text),'invalid bitmap')
    return [b=='1' for b in f'{int(text,16):064b}']


def build(path):
    raw=Path(path).read_bytes()
    require(len(raw)==518348 and sha(raw)==ARCHIVE,'archive identity')
    groups=[]; inputs={}; policies={}; policy_cells={}; summary={'win':0,'loss':0,'stall':0,'error':0}
    with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz') as tf:
        expected_files={f'screen/{c}-{a}-v{v}-arm{k}.ndjson' for c in ('original','candidate') for a in ('duskblade','ashwarden') for v in (0,5) for k in (1,2,3,4)}
        require({m.name for m in tf.getmembers() if m.name.startswith('screen/') and m.name.endswith('.ndjson')}==expected_files,'archive screen coverage')
        for c,catalogue in enumerate(('original','candidate')):
            for a,aspect in enumerate(('duskblade','ashwarden')):
                for v in (0,5):
                    for arm in (1,2,3,4):
                        name=f'screen/{catalogue}-{aspect}-v{v}-arm{arm}.ndjson'
                        b=tf.extractfile(name).read(); inputs[name]={'bytes':len(b),'sha256':sha(b)}
                        all_rows=[json.loads(x) for x in b.splitlines()]; header=all_rows[0]; rows=all_rows[1:]
                        require(len(rows)==64 and header['engine']=='4.7.2-stable (official)','native coverage')
                        require(header['content_sha256']==CONTENT[c],'content binding')
                        config=header['config']
                        require((config['catalogue'],config['aspect'],config['vow'],config['arm'],config['seed0'],config['runs'])==(catalogue,aspect,v,arm,45010000,64),'header context')
                        policy=dump(header['policy']); policies[sha(policy)]=header['policy']; policy_cells[name]=sha(policy)
                        require(header['driver_sha256']=='4afb2ebe028d95c521c1df845dbca723d509bcc002dd79477540a26908f6202c','driver binding')
                        require(header['sources']==SOURCES,'balance tool identities')
                        for i,r in enumerate(rows):
                            require((r['seed'],r['aspect'],r['vow'],r['arm'])==(45010000+i,aspect,v,arm),'row binding')
                            require(dump(r['policy'])==policy,'unexpected policy')
                            require(r['outcome'] in summary and r['error']=='','invalid outcome')
                            summary[r['outcome']]+=1
                        values=[]
                        for route,p,q in ROUTES[a]:
                            bits=[[] for _ in FIELDS]
                            for r in rows:
                                ev=r['packageEvents']; deck=r['deckIds']
                                flags=[ev.get(p+'Offered',0)>0, ev.get(q+'Offered',0)>0,
                                       p in deck and q in deck,
                                       ev.get(p+'Played',0)>0 and ev.get(q+'Played',0)>0,
                                       ev.get(q+'Played',0)>0]
                                for target,flag in zip(bits,flags): target.append(flag)
                            values.append([route,*map(encode,bits)])
                        groups.append([c,a,v,arm,encode([r['outcome']=='win' for r in rows]),values])
    require(summary=={'win':382,'loss':1666,'stall':0,'error':0},'cohort total')
    return {'format':'p9-fixed-cohort-coownership-bitmap-v1','source_archive_sha256':ARCHIVE,
            'source_archive_remote_complete':False,'source_files':inputs,'rows':2048,'seed0':45010000,'n':64,
            'base_policies':policies,'base_policy_per_cell':policy_cells,'balance_sources':SOURCES,'columns':['catalogue','aspect','vow','arm','wins','routes'],
            'route_columns':['route',*FIELDS],'groups':groups,'outcomes':summary,
            'limits':['No same-battle or temporal order, actual acquisition time, causal producer attribution, or same-instance repetition is encoded.',
                      'Final co-ownership is only a sufficient final-deck occurrence, not ever-owned coverage.',
                      'Starter ownership is not an offer; absence of an offered counter is not failure to be available.',
                      'For Cycle, both-played reduces to at least one play of any Momentum copy, NOT a repeat.',
                      'One fixed base policy with four signed arm modes is not 64 or 2048 independent policies.',
                      'The archive is exposed reproduction; this census adds no independent sample or admission.']}


SOURCES = {
    'balance_catalogue.gd':'6e240546cd616a2518ee7a2b8fae41aa8a94078429155f89f6d9165eef1c20c0',
    'balance_metrics.gd':'6904043d83d9cc91265a60911b28f49a01074d185e353b2dccdad64293cd0deb',
    'balance_pilot.gd':'4ff5934fc03af84e9d0c8fb285a91c6b7d5dfcab180b88825b1e75bb47ea6c47',
    'balance_policy.gd':'8eeeb1d3289bbab7fb033e6f175b9d2adcbb2944292c097ad09f79419e162026',
    'balance_sim.gd':'b169e2588e2ea65b75b94ee94b8e129c2c3ac8a0d5f7076224521a204623cd06',
    'vow_incentives.gd':'f83e9273798c87ed6675c609997e09ffea8a2a0d4f3a4ef2b95a4f8d2864098e'}


def validate_provenance(primary):
    files={f'screen/{c}-{a}-v{v}-arm{k}.ndjson' for c in ('original','candidate')
           for a in ('duskblade','ashwarden') for v in (0,5) for k in (1,2,3,4)}
    require(set(primary['source_files'])==files,'source coverage')
    require(set(primary['base_policy_per_cell'])==files,'policy coverage')
    require(primary['balance_sources']==SOURCES,'tool binding')
    for h,p in primary['base_policies'].items():
        require(sha(dump(p))==h,'policy identity')
    require(set(primary['base_policy_per_cell'].values())==set(primary['base_policies']),'policy inventory')
    require(primary['outcomes']=={'win':382,'loss':1666,'stall':0,'error':0},'outcome inventory')
    require(primary['columns']==['catalogue','aspect','vow','arm','wins','routes'],'column identity')
    require(primary['source_archive_remote_complete'] is False,'cannot upgrade historical preservation')


def read(primary):
    require(primary['format']=='p9-fixed-cohort-coownership-bitmap-v1','format')
    require(primary['source_archive_sha256']==ARCHIVE and primary['rows']==2048 and primary['n']==64 and primary['seed0']==45010000,'binding')
    require(primary['route_columns']==['route',*FIELDS],'schema')
    validate_provenance(primary)
    seen=set(); cells=[]; total_wins=0
    for c,a,v,k,wins,route_records in primary['groups']:
        key=(c,a,v,k)
        require(key not in seen and c in (0,1) and a in (0,1) and v in (0,5) and k in (1,2,3,4),'context')
        seen.add(key); w=decode(wins); total_wins+=sum(w)
        require([r[0] for r in route_records]==[r[0] for r in ROUTES[a]],'route coverage')
        for rr in route_records:
            require(len(rr)==len(FIELDS)+1,'route schema')
            b={f:decode(x) for f,x in zip(FIELDS,rr[1:])}
            require(all(not p or q for p,q in zip(b['both_played_anywhere'],b['consumer_played'])),'logical implication')
            cells.append({'catalogue':('original','candidate')[c],'aspect':('duskblade','ashwarden')[a],
                          'vow':v,'arm':k,'route':rr[0],'n':64,'wins':sum(w),
                          **{f:sum(x) for f,x in b.items()},
                          'wins_with_both_played':sum(x and y for x,y in zip(w,b['both_played_anywhere'])),
                          'temporal_chain_count':None,'independent_policy_count':None})
    require(len(seen)==32 and total_wins==382,'complete cohort')
    return {'status':'COMPLETE_EXPOSED_COHORT_CENSUS_NOT_CAUSAL_OR_POLICY_ADMISSION',
            'rows':2048,'cells':cells,'unique_base_policy_vectors':len(primary['base_policies']),
            'arm_modes':4,'new_native_runs':0,'new_independent_samples':0,'limits':primary['limits']}


if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser();p.add_argument('archive');p.add_argument('output');a=p.parse_args()
    primary=build(a.archive);out=Path(a.output);out.mkdir(parents=True,exist_ok=True)
    for name,obj in [('CENSUS-PRIMARY.json',primary),('CENSUS.json',read(primary))]:
        b=dump(obj);path=out/name
        if path.exists():require(path.read_bytes()==b,'refuse changed output')
        else:path.write_bytes(b)
        print(name,len(b),sha(b))
