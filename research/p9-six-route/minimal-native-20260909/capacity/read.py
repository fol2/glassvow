"""Conservative necessary opportunity bounds, not causal activation/admission."""
from __future__ import annotations
from collections import Counter
import hashlib,json,lzma
from pathlib import Path


def require(ok,reason):
    if not ok:raise ValueError(reason)
def sha(b):return hashlib.sha256(b).hexdigest()
def load_lines(p):
    p=Path(p);op=lzma.open if p.suffix=='.xz' else open
    with op(p,'rt') as f:
        for line in f:
            if line.strip():yield json.loads(line)
def config(aspect,vow,first,count,observed=True,smoke=False):
    return {'aspect':aspect,'vow':vow,'policy_root':73209000,'policies':128,'first':first,'count':count,
            'seed0':73209010 if smoke else 73209100,'runs':1 if smoke else 4,'observed':observed}

def cell(folder,cfg,protocol):
    folder=Path(folder);items=iter(load_lines(folder/'endpoints.ndjson.xz'));header=next(items)
    require(header['kind']=='header' and header['config']==cfg,'header config')
    require(header['content_sha256']==protocol['content_sha256'] and header['engine']=='4.7.2-stable (official)','native input')
    require(header['sources']==protocol['tool_sha256'],'native tools')
    require(header['observer_sha256']==protocol['source_sha256']['observed_game.gd'] and header['driver_sha256']==protocol['source_sha256']['probe.gd'],'observer source')
    require(header['observed_sim_sha256']==protocol['observed_sim_sha256'],'sim transform')
    params=header['policy_vectors'];require(len(params)==128,'parameter vectors')
    encoded=[json.dumps(x,sort_keys=True,separators=(',',':')) for x in params]
    require(len(set(encoded))==128,'actual distinct configurations')
    endpoints={};sequence=[]
    for item in items:
        require(item['kind']=='endpoint','endpoint kind')
        i,seed=item['policy_index'],item['seed'];key=f'{i}:{seed}'
        require(key not in endpoints,'duplicate endpoint');row=json.loads(item['serialized'])
        require(row['policy']==params[i],'actual policy binding')
        require(row['seed']==seed and row['aspect']==cfg['aspect'] and row['vow']==cfg['vow'],'actual run binding')
        endpoints[key]={'row':row,'digest':sha(item['serialized'].encode()),'index':i,'seed':seed,'policy_sha256':sha(encoded[i].encode())};sequence.append(key)
    expected=[f'{i}:{s}' for i in range(cfg['first'],cfg['first']+cfg['count']) for s in range(cfg['seed0'],cfg['seed0']+cfg['runs'])]
    require(sequence==expected,'complete assigned ordered outcomes')
    source,consumer=('empower','flurry') if cfg['aspect']=='duskblade' else ('venomStrike','catalyst')
    current=None;count=0;fight=-1;producer_seen=False;potential=False;pair=False;source_played=False;sink_played=False;done={}
    for item in load_lines(folder/'trace.ndjson.xz'):
        key=item['row_key'];require(key in endpoints,'unassigned trace')
        if current!=key:
            require(current is None or current in done,'unfinished trace row')
            require(key not in done,'reopened row');current=key;count=0;fight=-1;producer_seen=False
            potential=pair=source_played=sink_played=False
        if item['kind']=='row_end':
            require(key not in done,'duplicate completed row')
            require(item['commands']==count and item['endpoint_sha256']==endpoints[key]['digest'],'trace endpoint closure')
            e=endpoints[key];row=e['row']
            require(row['outcome'] in ('win','loss','error','stall'),'outcome')
            done[key]={'policy_index':e['index'],'policy_sha256':e['policy_sha256'],'seed':e['seed'],
                'outcome':row['outcome'],'error':row.get('error',''),'potential_chain':potential,
                'pair_seen':pair,'producer_played':source_played,'consumer_played':sink_played,'observed_commands':count}
            continue
        require(item['kind']=='command' and cfg['observed'] and key not in done,'command observation')
        require(item['sequence']==count,'command sequence');count+=1
        before,after=item['before'],item['after']
        require(before['seed']==after['seed']==endpoints[key]['seed'],'state seed')
        require(before['vow']==after['vow']==cfg['vow'],'state vow')
        require(before['aspect']==after['aspect']==(0 if cfg['aspect']=='duskblade' else 1),'state aspect')
        if item['command']['t']=='startCombat':
            require(item['fight']==fight+1,'fight sequence');fight=item['fight'];producer_seen=False
        require(item['fight']==fight,'fight binding')
        if any({source,consumer}.issubset({c['id'] for c in view['deck']}) for view in (before,after)):pair=True
        if item['command']['t']!='playCard' or item['ret'] is not True:continue
        if item['card']==source:producer_seen=True;source_played=True
        if item['card']==consumer:
            sink_played=True
            target=item['command'].get('target')
            if cfg['aspect']=='duskblade':stock=before['str']
            else:
                matches=[e for e in before['enemies'] if e['idx']==target]
                require(len(matches)==1,'target binding');stock=matches[0]['poison']
            # Deliberately overcounts: no source attribution, clipping or alternatives are inferred.
            if producer_seen and stock>0:potential=True
    require(set(done)==set(endpoints),'full trace row coverage')
    return {'config':cfg,'rows':[done[k] for k in expected],'endpoints':{k:e['row'] for k,e in endpoints.items()},
            'policy_manifest_sha256':sha(json.dumps(params,sort_keys=True,separators=(',',':')).encode())}

def aggregate(cells):
    require(cells and len({(c['config']['aspect'],c['config']['vow']) for c in cells})==1,'one grid')
    require(len({c['policy_manifest_sha256'] for c in cells})==1,'same policy family')
    rows=[r for c in cells for r in c['rows']]
    require(len(rows)==512 and len({(r['policy_index'],r['seed']) for r in rows})==512,'full 128x4 rectangle')
    policies={i:[r for r in rows if r['policy_index']==i] for i in range(128)}
    for i,r in policies.items():
        require(sorted(x['seed'] for x in r)==list(range(73209100,73209104)),'assigned policy seeds')
        require(len({x['policy_sha256'] for x in r})==1,'policy identity consistency')
    potential=[i for i,r in policies.items() if any(x['potential_chain'] for x in r)]
    reachable=[i for i,r in policies.items() if any(x['pair_seen'] and x['consumer_played'] for x in r)]
    viable=[i for i,r in policies.items() if any(x['potential_chain'] and x['outcome']=='win' for x in r)]
    faults=[r for r in rows if r['outcome'] in ('error','stall') or r['error']]
    gates={'potential_active_upper_bound_at_least32':len(potential)>=32,
           'reachable_upper_bound_at_least16':len(reachable)>=16,
           'potential_viable_upper_bound_at_least16':len(viable)>=16}
    status='NATIVE_POLICY_CAPACITY_NOT_FALSIFIED_NOT_ADMISSION' if all(gates.values()) else 'FIXED_NATIVE_POLICY_FAMILY_INSUFFICIENT_UPPER_BOUND'
    if faults:status='NATIVE_POLICY_CAPACITY_INCONCLUSIVE_FAULTS'
    return {'status':status,'aspect':cells[0]['config']['aspect'],'vow':cells[0]['config']['vow'],
            'rows':512,'policies':128,'potential_active_upper_bound':potential,'reachable_upper_bound':reachable,
            'potential_viable_upper_bound':viable,'outcomes':dict(Counter(r['outcome'] for r in rows)),
            'faults':faults,'gates':gates,'policy_manifest_sha256':cells[0]['policy_manifest_sha256'],
            'scope':'Conservative opportunity/viability counts in this exact stock controller family only. Potential is not causal activation, and not-potential is not a certified inactive strategy. No independent confirmation or replacement for the stronger retained research controller.',
            'packages_admitted':0,'p9_certified':False}
