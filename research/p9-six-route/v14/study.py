"""Frozen paired native experiments. Preserves all assigned outcomes; not a certificate."""
from pathlib import Path
import concurrent.futures, hashlib, json, os, subprocess, time, sys, collections
ROOT=Path(__file__).resolve().parent
PROJECT=ROOT/'project'
ENGINE=ROOT.parent/'p9_recovery/engine/Godot_v4.7.2-stable_linux.x86_64'
ENGINE_HASH='8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e'
ROUTES={0:['facet','fervor','cycle'],1:['smolder','hand','ember']}
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def write(path,obj):
    path=Path(path);path.parent.mkdir(parents=True,exist_ok=True)
    tmp=path.with_suffix(path.suffix+'.tmp');tmp.write_text(json.dumps(obj,indent=2)+'\n');tmp.replace(path)
def observer():
    return {'engine':sha(ENGINE),'sources':{str(p.relative_to(PROJECT)):sha(p) for p in sorted(PROJECT.rglob('*')) if p.is_file() and '.godot' not in p.parts}}
def parse_rows(path):
    if not path.exists():return {},[]
    objects=[json.loads(x) for x in path.read_text().splitlines()]
    return (objects[0],objects[1:]) if objects else ({},[])
def execute(spec,folder,obs,timeout):
    key=spec['id'];out=folder/f'{key}.ndjson';log=folder/f'{key}.log';cfg=folder/f'{key}.json';receipt=folder/f'{key}.receipt.json'
    if receipt.exists():
        old=json.loads(receipt.read_text())
        if old['spec']==spec and old['observer']==obs and old['complete'] and old['output_sha256']==sha(out) and old['log_sha256']==sha(log):return old
        raise ValueError('Existing incompatible or failed capture: '+key)
    write(cfg,spec);ch=sha(spec['content_path']);command=[str(ENGINE),'--headless','--path',str(PROJECT),'-s','res://lab_runner.gd','--',str(cfg),str(out)]
    start=time.monotonic();code=None;exception=None
    try:
        with log.open('wb') as stream:
            result=subprocess.run(command,stdout=stream,stderr=subprocess.STDOUT,env={**os.environ,'GODOT_SILENCE_ROOT_WARNING':'1'},timeout=timeout)
        code=result.returncode
    except subprocess.TimeoutExpired:exception='WATCHDOG'
    try:manifest,rows=parse_rows(out)
    except Exception as ex:manifest,rows={},[];exception=repr(ex)
    diagnostics=[s for s in log.read_text(errors='replace').splitlines() if 'ERROR' in s or s.startswith(('LAB_','Error:'))]
    wanted=list(range(spec['seed0'],spec['seed0']+spec['runs']))
    bindings=manifest.get('content_sha256')==ch and manifest.get('policy_sha256')==obs['sources']['lab_policy.gd'] and manifest.get('driver_sha256')==obs['sources']['lab_runner.gd'] and manifest.get('config')==spec
    assigned=[r.get('seed') for r in rows]==wanted and all(r.get('result') in ('win','loss','stall','error') and all(r.get(k)==spec[k] for k in ('aspect','vow','route','random_build')) for r in rows)
    valid_wins=all(r['act']==3 and r['hp']>0 and r['fights'] and r['fights'][-1]['kind']=='boss' and r['fights'][-1]['result']=='win' for r in rows if r.get('result')=='win')
    complete=code==0 and exception is None and not diagnostics and bindings and assigned and valid_wins and sha(spec['content_path'])==ch
    counts=collections.Counter(r.get('result') for r in rows);mechanics=collections.Counter()
    for row in rows:mechanics.update(row.get('mechanism',{}))
    record={'spec':spec,'observer':obs,'content_sha256':ch,'complete':complete,'seconds':time.monotonic()-start,'exit_code':code,'exception':exception,'diagnostics':diagnostics,'bindings':bindings,'assigned':assigned,'valid_wins':valid_wins,'config_sha256':sha(cfg),'output_sha256':sha(out) if out.exists() else None,'log_sha256':sha(log),'n':len(rows),'counts':dict(counts),'mechanism':dict(mechanics)}
    write(receipt,record);print(key,dict(counts),round(record['seconds'],2),'complete',complete,flush=True)
    if not complete:raise RuntimeError('Incomplete capture '+key+' '+str(diagnostics)+' '+str(exception))
    return record
def batch(name,specs,workers=4,timeout=600):
    obs=observer();assert obs['engine']==ENGINE_HASH
    assert len({s['id'] for s in specs})==len(specs)
    assert all(s['seed0']>=14000000 and s['runs']>0 for s in specs)
    folder=ROOT/'studies'/name;folder.mkdir(parents=True,exist_ok=True)
    freeze={'purpose':'EXPLORATION_NOT_P9','observer':obs,'specs':specs,'source_ref':'2ed6cdb0302ba3aab5845a18d862841165e8aaf7','cohort_note':'Same numeric seed does not guarantee matched downstream RNG','selection_rule':'Compare paired win/loss, mechanism enactment and wall cost. No parameter adaptation inside this batch.','watchdog_seconds':timeout}
    path=folder/'freeze.json'
    if path.exists():assert json.loads(path.read_text())==freeze,'Frozen experiment changed'
    else:write(path,freeze)
    results=[]
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        tasks=[pool.submit(execute,s,folder,obs,timeout) for s in specs]
        for task in concurrent.futures.as_completed(tasks):results.append(task.result())
    assert observer()==obs,'Source changed during batch'
    results.sort(key=lambda r:r['spec']['id']);write(folder/'summary.json',results)
    print('COMPLETE',name,'rows',sum(r['n'] for r in results),flush=True);return results

def comparison(runs,seed,all_routes=True):
    specs=[]
    for a,rs in ROUTES.items():
        for route in rs if all_routes else ['fervor' if a==0 else 'ember']:
            for vow in [0,5]:
                for rollout in [False,True]:
                    label=f'a{a}-{route}-v{vow}-'+('rollout' if rollout else 'greedy')
                    specs.append({'id':label,'content_path':str(ROOT/'content/fixed.json'),'aspect':a,'vow':vow,'route':route,'random_build':False,'random_play':False,'runs':runs,'seed0':seed,'params':{'bank_mode':'current-plus-next','native_rollout':rollout,'rollout_samples':2,'rollout_steps':12}})
    return specs
if __name__=='__main__':
    from recipes import build
    build();mode=sys.argv[1]
    if mode=='smoke':batch('smoke',comparison(1,14000100,False),workers=4,timeout=240)
    elif mode=='compare':batch('compare',comparison(16,14010000),workers=4,timeout=1200)
