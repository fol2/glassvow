"""Complete preserved two-slope Hand path accounting, not a new value test.
No simulator, fits, selected-success sample, new metric gate or admission.
"""
from collections import Counter
import hashlib
import importlib.util
import json
import lzma
from pathlib import Path
import sys

ROOT = Path('research/p9-six-route/ash-inheritance-20260909')
STUDY = ROOT/'hand-two-slope-v1/adaptive-value-v1'
PROVENANCE = ROOT/'hand-adaptive-v1/descriptor.py'
PROVENANCE_BLOB = 'f41337fb6a0ea7fa91a0e2ede26ebf0670cd724b'
CONTRACT_BLOB = '5d738f65e6302dd33a8b5c2a22d60e38bca6c471'
WORLDS = ('00','01','10','11')
SOURCES = ('preparation','surge')


def require(ok, why):
    if not ok: raise ValueError(why)


def sha(b): return hashlib.sha256(b).hexdigest()
def blob(b): return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def load(p): return json.loads(p.read_bytes())
def save(p,x): p.write_text(json.dumps(x,indent=2,sort_keys=True)+'\n')


def payoff(q, upgraded, enabled):
    require(type(q) is int and q>=0 and type(upgraded) is bool and type(enabled) is bool,'LAW_TYPES')
    return ((7 if upgraded else 6)*max(0,q-4)+2*min(q,4)) if enabled else 0


def consumer_fields(record, origins, enabled, hand_ids):
    hand=record['before']['hand'];ids=hand_ids(hand)
    uid=record['command']['uid'];require(uid in ids,'CONSUMER_INSTANCE')
    card=next(x for x in hand if x['uid']==uid)
    q=len(ids)-1
    direct={s:sum(u!=uid and origins.get(u)==s for u in ids) for s in SOURCES}
    s=sum(direct.values());require(type(card['up']) is bool,'UPGRADE_TYPE');up=card['up']
    raw=payoff(q,up,enabled)
    return {'remaining_hand':q,'above_reserve':q>4,'retained_direct_source_instances':direct,
            'source_drew_consumer':origins.get(uid) in SOURCES,
            'structural_raw':raw,'structural_source_slot_deletion':raw-payoff(q-s,up,enabled),
            'scope':'Source origin and algebraic same-hand slot deletion only; not adaptive marginal damage, HP or win value.'}


def source_module(repo):
    p=repo/PROVENANCE;require(blob(p.read_bytes())==PROVENANCE_BLOB,'PROVENANCE_SOURCE')
    spec=importlib.util.spec_from_file_location('preserved_hand_origins',p)
    m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
    return m


def assigned(contract,vow):
    a=contract['assignment'];by_first={}
    for first in range(0,a['policies'],a['policies_per_cell']):
        start=a['seed_base']+a['seed_vow_stride']*vow+a['seeds_per_cell']*(first//a['policies_per_cell'])
        by_first[first]={f'{vow}:{i}:{s}' for i in range(first,first+a['policies_per_cell'])
                         for s in range(start,start+a['seeds_per_cell'])}
    require(len(by_first)==64 and all(len(x)==8 for x in by_first.values()),'ASSIGNED_CELLS')
    return by_first


def run(repo,out):
    require(not out.exists(),'NO_OVERWRITE')
    original=repo/STUDY/'execution-1'
    terminal=load(original/'TERMINAL.json');proof=load(original/'REMOTE-READBACK.json')
    require(proof['all_bytes_equal'] is True and proof['scientific_status']==terminal['status'],'COLD_INPUT')
    require(terminal['status'] in ('TWO_SLOPE_HAND_ADAPTIVE_VALUE_NOT_ESTABLISHED','TWO_SLOPE_HAND_ADAPTIVE_VALUE_SUPPORTED_NOT_CERTIFICATE'),'COMPLETE_VALUE_INPUT')
    require(blob((repo/STUDY/'CONTRACT.json').read_bytes())==CONTRACT_BLOB,'EXACT_CONTRACT')
    contract=load(repo/STUDY/'CONTRACT.json');entries={r['path']:r for r in load(original/'FILES.json')}
    require(len(entries)==len(load(original/'FILES.json')),'DUPLICATE_MANIFEST')
    provenance=source_module(repo);inputs=[];results={};coverage={}
    out.mkdir(parents=True)
    with (out/'CONSUMER-FIELDS.jsonl').open('w') as sink:
        for v in terminal['stages']:
            vow=int(v);cells=assigned(contract,vow);results[v]={}
            for world in WORLDS:
                runs={};counts=Counter();distribution=Counter();sets={k:set() for k in ('consumer','retained_source','source_access','either_source_path','above_reserve','source_path_above_reserve')}
                for first, expected in cells.items():
                    rel=f'v{vow}/{world}/v{vow}-{first:03d}.traces.jsonl.xz';p=original/rel
                    b=p.read_bytes();r=entries[rel]
                    require(len(b)==r['bytes'] and sha(b)==r['sha256'],'INPUT_BYTES:'+rel)
                    inputs.append({'path':rel,**r});current=None;origins={};prior=None;sequence=0;fight=None;found=set()
                    with lzma.open(p,'rt',encoding='utf-8') as f:
                        for line in f:
                            require(line.strip(),'EMPTY_LINE');x=json.loads(line);key=x['row_key']
                            require(key in expected,'UNASSIGNED_RUN')
                            if key!=current:
                                require(key not in runs,'DUPLICATE_RUN')
                                runs[key]={'commands':0,'consumer_plays':0};found.add(key)
                                current=key;origins={};prior=None;sequence=0;fight=None
                            require(x['kind']=='command' and x['sequence']==sequence and x['original_untouched_by_clones'] is True,'COMMAND_IDENTITY')
                            sequence+=1;runs[key]['commands']+=1;counts['commands']+=1
                            before=provenance.hand_ids(x['before']['hand']);after=provenance.hand_ids(x['after']['hand'])
                            require(prior is None or before==prior,'HAND_CONTINUITY')
                            if x['fight']!=fight:origins={};fight=x['fight']
                            if x['card']=='phantomBlades' and x['ret'] is True:
                                fields=consumer_fields(x,origins,world[1]=='1',provenance.hand_ids)
                                sourced=sum(fields['retained_direct_source_instances'].values())>0
                                access=fields['source_drew_consumer'];high=fields['above_reserve'];i=int(key.split(':')[1])
                                flags={'consumer':True,'retained_source':sourced,'source_access':access,'either_source_path':sourced or access,'above_reserve':high,'source_path_above_reserve':high and (sourced or access)}
                                for name, yes in flags.items():
                                    counts[name+'_plays']+=int(yes)
                                    if yes:sets[name].add(i)
                                counts['structural_source_slot_deletion_sum']+=fields['structural_source_slot_deletion']
                                distribution[str(fields['remaining_hand'])]+=1;runs[key]['consumer_plays']+=1
                                sink.write(json.dumps({'vow':vow,'world':world,'row_key':key,'sequence':x['sequence'],'fight':fight,**fields},sort_keys=True)+'\n')
                            provenance.draws(x['events'],x['card'],x['ret'] is True,origins)
                            origins={u:s for u,s in origins.items() if u in after};prior=after
                    require(found==expected,'CELL_COVERAGE')
                require(set(runs)==set().union(*cells.values()) and len(runs)==512,'FULL_STAGE_COVERAGE')
                if world[0]=='0':
                    require(counts['retained_source_plays']==counts['source_access_plays']==0,'SOURCE_OFF_PROVENANCE_LEAK')
                if world[1]=='0':require(counts['structural_source_slot_deletion_sum']==0,'PAYOFF_OFF_LEAK')
                results[v][world]={'runs':len(runs),'counts':dict(counts),'remaining_hand_at_consumer':dict(sorted(distribution.items(),key=lambda kv:int(kv[0]))),
                    'configurations_with_observation':{k:len(s) for k,s in sets.items()},'limits':'Descriptive full-assignment counts, not post-treatment-selected win inference or certified policy breadth.'}
                coverage[v+':'+world]=runs
    decision={'kind':'COMPLETE_TWO_SLOPE_HAND_FACTUAL_PATH_ACCOUNTING','original_scientific_status':terminal['status'],
        'primary_terminal_sha256':sha((original/'TERMINAL.json').read_bytes()),'primary_changed':False,
        'results':results,'total_runs':sum(x['runs'] for d in results.values() for x in d.values()),
        'limits':['No new simulator outcome, controller, coefficients, random seed or fitted model.',
            'Raw law units precede Strength, Block, vulnerability, death and HP clamps; they are not actual extra HP.',
            'Source-enabled consumer access and retained-other-card paths overlap and must not be added.',
            'An observed source path does not establish that an adaptive policy would lose its payoff without that source.',
            'This audit cannot rescue the frozen value terminal or admit a descriptor/package.'],
        'review_kind':'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT','new_native_runs':0,'new_independent_samples':0,'packages_admitted':0,'p9_certified':False}
    save(out/'RESULTS.json',decision);save(out/'INPUTS.json',inputs);save(out/'RUN-COVERAGE.json',coverage)
    save(out/'FILES.json',[{'path':p.name,'bytes':p.stat().st_size,'sha256':sha(p.read_bytes())} for p in sorted(out.iterdir()) if p.is_file()])
    print(json.dumps(decision,indent=2))


if __name__=='__main__':run(*(Path(x).resolve() for x in sys.argv[1:]))
