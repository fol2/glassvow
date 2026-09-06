"""Hash-bound native exploratory runs. Preserves all assigned outcomes; no P9 pass claim."""
from pathlib import Path
import concurrent.futures as cf
import collections, hashlib, json, os, subprocess, time, sys
ROOT=Path(__file__).resolve().parent
PROJECT=ROOT/'project'
ENGINE=ROOT.parent/'engine/Godot_v4.7.2-stable_linux.x86_64'
ROUTES={0:['facet','fervor','cycle'],1:['smolder','hand','ember']}
ENGINE_SHA='8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e'
ANCHORS={'facet':['chisel','quakeblow','resonantLance'],'fervor':['empower','flurry'], 'cycle':['momentum'], 'smolder':['toxicMist','catalyst'],'hand':['nightSight','phantomBlades'],'ember':['pyreheart','tithe','novaflare'],'balanced':[]}

def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def write(p, value):
    p=Path(p);p.parent.mkdir(parents=True,exist_ok=True)
    text=json.dumps(value,ensure_ascii=False,indent=2)+'\n'
    tmp=p.with_suffix(p.suffix+'.tmp');tmp.write_text(text);tmp.replace(p)
def observer():
    return {'engine_sha256':sha(ENGINE),'source':{str(p.relative_to(PROJECT)):sha(p) for p in sorted(PROJECT.rglob('*')) if p.is_file() and '.godot' not in p.parts and p.suffix in ('.gd','.json','.godot')}}
def classify(log):
    return [line for line in log.splitlines() if 'ERROR' in line or line.startswith(('Error:','LAB_'))]
def summarize(rows,route):
    counts=collections.Counter(r['result'] for r in rows);n=len(rows)
    mk=collections.Counter()
    for r in rows: mk.update(r.get('mechanism',{}))
    fs=[f for r in rows for f in r['fights']]
    return {'n':n,'wins':counts['win'],'rate':counts['win']/n,'outcomes':dict(counts),
      'anchors':{c:{k:sum(r[k].get(c,0)>0 for r in rows) for k in ['offered','picked','played']} for c in ANCHORS[route]},
      'mechanism_total':dict(mk),'mechanism_mean':{k:v/n for k,v in mk.items()},
      'mean_deck':sum(len(r['deck']) for r in rows)/n,
      'mean_turns_per_fight':sum(f['turns'] for f in fs)/max(1,len(fs)),
      'failure_enemies':dict(collections.Counter('/'.join(r['fights'][-1]['enemies']) for r in rows if r['result']!='win' and r['fights']))}
def run_cell(spec,folder,frozen):
    key=spec['id'];config=folder/(key+'.config.json');out=folder/(key+'.ndjson');log=folder/(key+'.log');receipt=folder/(key+'.receipt.json')
    if receipt.exists():
        old=json.loads(receipt.read_text())
        if old['spec']==spec and old['observer']==frozen and old['complete'] and sha(out)==old['output_sha256'] and sha(log)==old['log_sha256']:
            return old
        raise RuntimeError(f'Existing different/incomplete evidence: {key}')
    write(config,spec);content_sha=sha(spec['content_path'])
    env={**os.environ,'GODOT_SILENCE_ROOT_WARNING':'1'};env.pop('DISPLAY',None)
    command=[str(ENGINE),'--headless','--path',str(PROJECT),'-s','res://lab_runner.gd','--',str(config),str(out)]
    t=time.monotonic();exit_code=None;failure=None
    try:
        with log.open('wb') as stream:
            done=subprocess.run(command,stdout=stream,stderr=subprocess.STDOUT,env=env,timeout=180)
        exit_code=done.returncode
    except subprocess.TimeoutExpired:
        failure='PER_INVOCATION_WATCHDOG'
    objects=[json.loads(l) for l in out.read_text().splitlines()] if out.exists() else []
    rows=objects[1:] if objects else [];manifest=objects[0] if objects else {}
    faults=classify(log.read_text(errors='replace'))
    desired=list(range(spec['seed0'],spec['seed0']+spec['runs']))
    identities_ok=manifest.get('content_sha256')==content_sha and manifest.get('policy_sha256')==frozen['source']['lab_policy.gd'] and manifest.get('driver_sha256')==frozen['source']['lab_runner.gd'] and manifest.get('legacy_policy_sha256')==frozen['source']['legacy_policy.gd']
    rows_ok=[r.get('seed') for r in rows]==desired and all(r.get('kind')=='row' and r.get('result') in ['win','loss','error','stall'] and all(r.get(k)==spec[k] for k in ['route','aspect','vow','random_build']) for r in rows)
    wins_ok=all(r['act']==3 and r['hp']>0 and r['fights'][-1]['kind']=='boss' and r['fights'][-1]['result']=='win' for r in rows if r.get('result')=='win')
    complete=exit_code==0 and not faults and identities_ok and rows_ok and wins_ok and sha(spec['content_path'])==content_sha
    record={'schema':'p9.exploratory.native/v8','complete':complete,'spec':spec,'observer':frozen,'content_sha256':content_sha,'config_sha256':sha(config),'command':command,'exit_code':exit_code,'seconds':time.monotonic()-t,'diagnostics':faults,'failure':failure,'output_sha256':sha(out) if out.exists() else None,'log_sha256':sha(log),'summary':summarize(rows,spec['route']) if rows else None}
    write(receipt,record)
    if not complete: raise RuntimeError(f'{key}: incomplete capture; {faults}; {failure}; identity={identities_ok}; rows={rows_ok}')
    return record

def batch(specs,name,workers=4):
    folder=ROOT/'studies'/name;folder.mkdir(parents=True,exist_ok=True)
    obs=observer();assert obs['engine_sha256']==ENGINE_SHA
    assert len({s['id'] for s in specs})==len(specs)
    assert all(s['runs']>0 and s['seed0']>=8100000 for s in specs)
    freeze={'purpose':'exploration, not acceptance','observer':obs,'specs':specs,'same_seeds_not_identical_downstream_rng':True,'protected_identities_opened':False}
    file=folder/'freeze.json'
    if file.exists():
        if json.loads(file.read_text())!=freeze:raise RuntimeError('Refusing to alter the frozen experiment')
    else:write(file,freeze)
    results=[]
    with cf.ThreadPoolExecutor(max_workers=workers) as pool:
        futures={pool.submit(run_cell,s,folder,obs):s for s in specs}
        for f in cf.as_completed(futures):
            r=f.result();results.append(r)
            print(name,r['spec']['id'],r['summary']['wins'],r['summary']['n'],r['summary']['outcomes'],flush=True)
    if observer()!=obs:raise RuntimeError('Observer changed during execution')
    results.sort(key=lambda r:r['spec']['id']);write(folder/'summary.json',results)
    print('COMPLETE',name,'cells',len(results),'rows',sum(r['summary']['n'] for r in results),flush=True)
    return results

def panel(contents,n,seed,params=None,matched=False):
    specs=[]
    for label,path in contents.items():
        for a,routes in ROUTES.items():
            for v in [0,5]:
                controllers=routes+['balanced']
                for r in controllers:
                    for random in ([False,True] if matched else ([True] if r=='balanced' else [False])):
                        id=f'{label}-a{a}-{r}-v{v}'+('-RB' if random else '')
                        specs.append({'id':id,'content_path':str(path),'aspect':a,'route':r,'vow':v,'random_build':random,'random_play':False,'runs':n,'seed0':seed,'params':params or {}})
    return specs
if __name__=='__main__':
    from recipes import make
    cs=make()
    if sys.argv[1]=='smoke':batch(panel({'finite_access':cs['finite_access']},4,8100000),'smoke')
    elif sys.argv[1]=='screen':batch(panel({k:v for k,v in cs.items() if k!='original'},32,8101000),'screen')
