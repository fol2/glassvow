"""Read an unmeasured persistent-source opportunity from complete retained data.
No engine, new outcome, model fit, primary reclassification or package admission.
"""
from collections import Counter
import hashlib
import json
import lzma
import math
from pathlib import Path
import re
import sys
import tarfile

BASE=Path('research/p9-six-route/ash-inheritance-20260909')
STUDY=BASE/'hand-two-slope-v1/adaptive-value-v1'
HERE=BASE/'nightsight-opportunity-v1'
WORLDS=('00','01','10','11')
CONTENT='ac779e08b0afc5054242ecf5dc1f7421e648e4ee114607708584d1d74ce92cdc'


def require(ok,why):
    if not ok:raise ValueError(why)


def sha(b):return hashlib.sha256(b).hexdigest()
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def load(p):return json.loads(p.read_bytes())
def save(p,x):p.write_text(json.dumps(x,indent=2,sort_keys=True)+'\n')
def path(s):
    p=Path(s);require(not p.is_absolute() and '..' not in p.parts and p.as_posix()==s,'PATH');return p

def integer(x):
    require(type(x) in (int,float) and math.isfinite(x) and int(x)==x,'EVENT_INTEGER');return int(x)


def functions(text):
    ms=list(re.finditer(r'^(?:static )?func (\w+)\(',text,re.M))
    return {m[1]:text[m.start():ms[i+1].start() if i+1<len(ms) else len(text)] for i,m in enumerate(ms)}


class Track:
    """Event-accounted opportunity upper bound; not extra-card attribution."""
    def __init__(self,types):
        self.types=types;self.fight=None;self.total=0;self.named=0;self.turn=0
        self.source_turn=None;self.eligible=False;self.counts=Counter()
    def consume(self,x):
        if x['fight']!=self.fight:
            self.fight=x['fight'];self.total=0;self.named=0;self.turn=0
            self.source_turn=None;self.eligible=False
        result=None
        if x['card']=='phantomBlades' and x['ret'] is True:
            hand=x['before']['hand'];uid=x['command']['uid']
            require(len({h['uid'] for h in hand})==len(hand) and any(h['uid']==uid for h in hand),'HELD_CONSUMER')
            result={'possible_persistent_source_path':self.eligible,'remaining_hand':len(hand)-1,
                    'event_accounted_status':self.total,'turn':self.turn,
                    'source_turn':self.source_turn,'above_reserve':len(hand)-1>4}
            self.counts['consumer_plays']+=1
            self.counts['possible_path_plays']+=int(self.eligible)
            self.counts['possible_path_above_reserve']+=int(self.eligible and len(hand)-1>4)
        packet=False;draws=0
        for e in x['events']:
            if e.get('t')==self.types['STATUS'] and e.get('id')=='nightsight' and e.get('who')=='player':
                n=integer(e['n']);self.total+=n
                if n>0 and x['card']=='nightSight' and x['ret'] is True:
                    self.named+=n;self.source_turn=self.turn;self.counts['source_applications']+=1
                elif n>0:self.counts['other_positive_status_applications']+=1
                if n<0:
                    self.named=min(self.named,max(0,self.total));self.counts['status_removals']+=1
            if e.get('t')==self.types['TURN']:
                n=integer(e['n']);require(n>self.turn,'TURN_CONTINUITY');self.turn=n
                self.eligible=False
                packet=self.total>0 and self.named>0 and self.source_turn is not None and self.source_turn<n
                draws=0
                if packet:self.counts['potential_source_turns']+=1
            if packet and e.get('t')==self.types['DRAW']:
                draws+=1
                if draws==1:self.counts['potential_source_turns_with_draw']+=1
                self.counts['draws_in_potential_source_turn_packet']+=1
                self.eligible=True
        return result


def source(capture,bound):
    manifest=load(bound('SOURCE-MANIFEST.json'))['reference']
    archive=bound('runtime-source.tar.xz'); selected={}
    with tarfile.open(archive,'r:xz') as tf:
        for rel,rec in manifest.items():
            if not (rel.endswith('.gd') or rel=='content/full-content.json'):continue
            p=path(rel);m=tf.getmember('reference/'+str(p));require(m.isfile(),'ARCHIVE_TYPE')
            b=tf.extractfile(m).read();require(len(b)==rec['bytes'] and sha(b)==rec['sha256'],'MEMBER:'+rel)
            selected[rel]=b.decode()
    content=selected['content/full-content.json'];require(sha(content.encode())==CONTENT,'CONTENT_IDENTITY')
    cards=json.loads(content)['cards'];emitters={}
    for name,d in cards.items():
        for upgrade,definition in [('base',d),('up',dict(d,**d.get('up',{})))]:
            for e in definition.get('effects',[]):
                if e.get('kind')=='status' and e.get('id')=='nightsight' and e.get('who')=='self':
                    emitters[name+':'+upgrade]=e
    require('nightSight:base' in emitters and cards['nightSight']['type']=='power','SOURCE_CARD')
    combat=selected['domain/rules/combat.gd'];fs=functions(combat)
    start=fs['_start_player_turn'];draw=fs['draw_cards']
    require('5 + _sget(p.statuses, "nightsight")' in start and 'draw_cards(run, cb, maxi(1, draws))' in start,'PERSISTENT_DRAW_LAW')
    require('cb.hand.size() >= 10' in draw and 'cb.draw.pop_back()' in draw,'DRAW_LIMIT_AND_ORDER')
    event_files=[(n,t) for n,t in selected.items() if 'class_name EventTypes\n' in t]
    require(len(event_files)==1,'EVENT_TYPE_SOURCE')
    types=dict(re.findall(r'const\s+(TURN|DRAW|STATUS)\b[^\n=]*=\s*&?"([^"]+)"',event_files[0][1]))
    require(set(types)=={'TURN','DRAW','STATUS'},'EVENT_BINDING')
    return types,{'card':cards['nightSight'],'catalogue_player_status_emitters':emitters,
        'combat_identity':manifest['domain/rules/combat.gd'],'start_turn':start,'draw_cards':draw,
        'event_source':{'path':event_files[0][0],**manifest[event_files[0][0]]},'event_types':types,
        'limits':'Source-bound temporal opportunity. Extra draw versus baseline/cap/empty-pile counterfactual is not reconstructed.'}


def run(repo,out):
    require(not out.exists(),'NO_OVERWRITE')
    p=load(repo/HERE/'PROTOCOL.json');capture=repo/STUDY/'execution-1'
    require(blob((capture/'FILES.json').read_bytes())==p['capture_manifest_blob'],'INPUT_MANIFEST')
    require(blob((capture/'REMOTE-READBACK.json').read_bytes())==p['capture_readback_blob'],'INPUT_READBACK')
    proof=load(capture/'REMOTE-READBACK.json');require(proof['all_bytes_equal'] is True,'UNVERIFIED_INPUT')
    require(blob((repo/STUDY/'CONTRACT.json').read_bytes())==p['contract_blob'],'INPUT_CONTRACT')
    contract=load(repo/STUDY/'CONTRACT.json');entries={r['path']:r for r in load(capture/'FILES.json')};inputs={}
    def bound(rel):
        q=capture/path(rel);b=q.read_bytes();r=entries[rel]
        require(len(b)==r['bytes'] and sha(b)==r['sha256'],'INPUT_BYTES:'+rel);inputs[rel]=r;return q
    terminal=load(bound('TERMINAL.json'));require(terminal['status']==proof['scientific_status'],'TERMINAL')
    types,src=source(capture,bound)
    for name,h in load(repo/STUDY/'FREEZE.json')['source_sha256'].items():
        require(sha((repo/STUDY/path(name)).read_bytes())==h,'FROZEN_READER:'+name)
    sys.path.insert(0,str(repo/STUDY));import campaign
    _,_,_,_,reader,_=campaign.dependencies(repo)
    protocols=load(bound('RESOLVED-PROTOCOLS.json'));a=contract['assignment']
    require(a['policies']==128 and a['policies_per_cell']==2 and a['seeds_per_cell']==4,'DESIGN')
    out.mkdir(parents=True);results={};coverage={};all_fields=0
    with (out/'FIELDS.jsonl').open('w') as sink:
        for vs in terminal['stages']:
            vow=int(vs);results[vs]={}
            for world in WORLDS:
                runs={};counts=Counter();possible=set();winning=set();above=set();wins=0
                for first in range(0,128,2):
                    seed=a['seed_base']+a['seed_vow_stride']*vow+4*(first//2)
                    cfg={'root':a['policy_root'],'first':first,'count':2,'seeds':list(range(seed,seed+4)),'vow':vow,'integration':False}
                    stem=f'v{vow}/{world}/v{vow}-{first:03d}'
                    rows=reader.outcome_records(bound(stem+'.outcomes.jsonl.xz'),cfg,protocols[world])
                    outcomes={x['row_key']:x['row']['outcome'] for x in rows}
                    require(len(outcomes)==8 and all(y in ('win','loss') for y in outcomes.values()),'OUTCOMES')
                    wins+=sum(y=='win' for y in outcomes.values());current=None;track=None;sequence=0;seen=set()
                    with lzma.open(bound(stem+'.traces.jsonl.xz'),'rt',encoding='utf-8') as f:
                        for line in f:
                            require(line.strip(),'EMPTY_RECORD');x=json.loads(line);key=x['row_key']
                            require(key in outcomes,'ASSIGNED_RUN')
                            if key!=current:
                                require(key not in runs,'DUPLICATE_RUN');current=key;track=Track(types);sequence=0
                                runs[key]={'commands':0,'possible_path':False,'source_applications':0};seen.add(key)
                            require(x['kind']=='command' and x['sequence']==sequence and x['original_untouched_by_clones'] is True,'TRACE_IDENTITY')
                            sequence+=1;runs[key]['commands']+=1
                            field=track.consume(x)
                            runs[key]['source_applications']=track.counts['source_applications']
                            if field:
                                all_fields+=1
                                sink.write(json.dumps({'row_key':key,'world':world,'sequence':x['sequence'],'fight':x['fight'],**field},sort_keys=True)+'\n')
                                if field['possible_persistent_source_path']:
                                    i=int(key.split(':')[1]);possible.add(i);runs[key]['possible_path']=True
                                    if outcomes[key]=='win':winning.add(i)
                                    if field['above_reserve']:above.add(i)
                            # Add event counters as differences; a run's counter survives fight reset.
                            previous=runs[key].get('counts',{})
                            for k,n in track.counts.items():counts[k]+=n-previous.get(k,0)
                            runs[key]['counts']=dict(track.counts)
                    require(seen==set(outcomes),'CELL_TRACE_COVERAGE')
                require(len(runs)==512 and wins==terminal['stages'][vs]['wins'][world],'FULL_STAGE_IDENTITY')
                counts['commands']=sum(x['commands'] for x in runs.values())
                results[vs][world]={'runs':512,'wins_descriptive_only':wins,'counts':dict(counts),
                    'configurations_with_possible_path':len(possible),'configurations_with_winning_possible_path':len(winning),
                    'configurations_with_possible_path_above_reserve':len(above),'possible_policy_ids':sorted(possible)}
                coverage[vs+':'+world]=runs
    screen={v:{w:{'possible_support':d[w]['configurations_with_possible_path']>=p['screen']['minimum_configurations_with_possible_path'],
                  'winning_support':d[w]['configurations_with_winning_possible_path']>=p['screen']['minimum_configurations_with_winning_possible_path']}
               for w in p['screen']['worlds']} for v,d in results.items()}
    passed=all(all(g.values()) for d in screen.values() for g in d.values())
    result={'kind':p['kind'],'status':'PERSISTENT_SOURCE_OPPORTUNITY_NOT_RULED_OUT' if passed else 'FIXED_CAPTURE_PERSISTENT_SOURCE_OPPORTUNITY_INSUFFICIENT',
        'results':results,'screen':screen,'source':src,'total_runs':sum(d['runs'] for v in results.values() for d in v.values()),
        'consumer_records':all_fields,'original_value_status':terminal['status'],'primary_changed':False,
        'limits':[p['interpretation'],'This does not rescue either direct-draw primary claim or establish extra HP, value, descriptor or scientific independence.',
                  'A positive necessary screen only justifies missing source/operator qualification, never a population start or package admission.'],
        'review_kind':'AUTHOR_SELF_REVIEW_NOT_INDEPENDENT','new_native_runs':0,'new_independent_samples':0,'packages_admitted':0,'p9_certified':False}
    save(out/'RESULTS.json',result);save(out/'COVERAGE.json',coverage);save(out/'INPUTS.json',[inputs[k] for k in sorted(inputs)])
    save(out/'FILES.json',[{'path':q.name,'bytes':q.stat().st_size,'sha256':sha(q.read_bytes())} for q in sorted(out.iterdir()) if q.is_file()])
    print(json.dumps({k:v for k,v in result.items() if k!='source'},indent=2))


if __name__=='__main__':run(*(Path(x).resolve() for x in sys.argv[1:]))
