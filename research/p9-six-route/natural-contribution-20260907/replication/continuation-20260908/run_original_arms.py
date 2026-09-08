"""Execute the existing original-arm diagnostic; no controller/content adaptation."""
from pathlib import Path
import concurrent.futures,hashlib,json,os,subprocess,sys,time,collections
R=Path(__file__).resolve().parent;W=R/'original-arms';ENGINE=R/'engine/Godot_v4.7.2-stable_linux.x86_64'
P=json.loads((W/'PROTOCOL.json').read_text())
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def write(p,o):
    p=Path(p);p.parent.mkdir(parents=True,exist_ok=True)
    temp=p.with_suffix(p.suffix+'.tmp');temp.write_text(json.dumps(o,indent=2)+'\n');temp.replace(p)
def panel(mode):
    plan=P[mode];cells=[]
    for catalogue in P['catalogues']:
        content=R/'study/project/content/full-content.json' if catalogue=='original' else R/'study/fuel_content/production2_demand3.json'
        assert sha(content)==P['catalogues'][catalogue]
        for aspect in ('duskblade','ashwarden'):
            for vow in (0,5):
                for arm in (1,2,3,4):
                    cells.append({'id':f'{catalogue}-{aspect}-v{vow}-arm{arm}',
                      'catalogue':catalogue,'content_path':str(content),'aspect':aspect,'vow':vow,
                      'arm':arm,'seed0':plan['seed0'],'runs':plan['runs_per_cell']})
    assert len(cells)==32;return cells

def observer(project):
    obs={'engine_sha256':sha(ENGINE),'protocol_sha256':sha(W/'PROTOCOL.json'),
      'controller_sha256':sha(__file__),'project':str(project),
      'sources':{str(p.relative_to(project)):sha(p) for p in sorted(project.rglob('*')) if p.is_file() and '.godot' not in p.parts}}
    assert obs['engine_sha256']=='8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e'
    assert all(obs['sources']['tools/'+n]==h for n,h in P['sources'].items())
    return obs

def execute(spec,folder,obs):
    name=spec['id'];cfg=folder/(name+'.json');out=folder/(name+'.ndjson');log=folder/(name+'.log');receipt=folder/(name+'.receipt.json')
    if receipt.exists():
        x=json.loads(receipt.read_text())
        assert x['complete'] and x['spec']==spec and x['observer']==obs
        assert all(sha(p)==x[k] for p,k in ((out,'output_sha256'),(log,'log_sha256'),(cfg,'config_sha256')))
        return x
    write(cfg,spec);start=time.monotonic();code=None;exc=None
    try:
        with log.open('wb') as f:
            proc=subprocess.run([str(ENGINE),'--headless','--path',obs['project'],'-s','res://arms_runner.gd','--',str(cfg),str(out)],
              stdout=f,stderr=subprocess.STDOUT,timeout=1200,env={**os.environ,'GODOT_SILENCE_ROOT_WARNING':'1'})
        code=proc.returncode
    except subprocess.TimeoutExpired:exc='WATCHDOG'
    lines=[x for x in log.read_text(errors='replace').splitlines() if 'ERROR' in x or x.startswith(('Error:','ARM_CFG'))]
    try:
        data=[json.loads(x) for x in out.read_text().splitlines()];manifest=data[0];rows=data[1:]
    except Exception as e:manifest={};rows=[];exc=repr(e)
    bindings=(manifest.get('config')==spec and manifest.get('engine')=='4.7.2-stable (official)' and
      manifest.get('sources')==P['sources'] and manifest.get('content_sha256')==P['catalogues'][spec['catalogue']] and
      manifest.get('driver_sha256')==obs['sources']['arms_runner.gd'])
    assigned=([r.get('seed') for r in rows]==list(range(spec['seed0'],spec['seed0']+spec['runs'])) and
      all(r.get('outcome') in ('win','loss','stall','error') and all(r.get(k)==spec[k] for k in ('aspect','vow','arm')) and
      r.get('policy')==manifest.get('policy') for r in rows))
    valid_wins=all(r['hp']>0 and r['fights'] and r['fights'][-1]['act']==3 and r['fights'][-1]['kind']=='boss' and
      all(f['result']=='win' for f in r['fights']) for r in rows if r.get('outcome')=='win')
    counts=dict(collections.Counter(r.get('outcome') for r in rows))
    result={'spec':spec,'observer':obs,'complete':code==0 and exc is None and not lines and bindings and assigned and valid_wins,
      'exit_code':code,'exception':exc,'diagnostics':lines,'bindings':bindings,'assigned':assigned,'valid_wins':valid_wins,
      'seconds':time.monotonic()-start,'n':len(rows),'counts':counts,'output_sha256':sha(out) if out.exists() else None,
      'config_sha256':sha(cfg),'log_sha256':sha(log)}
    write(receipt,result);print(folder.name,name,counts,round(result['seconds'],2),result['complete'],flush=True)
    assert result['complete'],(name,code,exc,lines,bindings,assigned,valid_wins)
    return result

def batch(mode,project='candidate-project',reference=False):
    specs=panel(mode)
    if reference:specs=[s for s in specs if s['catalogue']=='original']
    folder=W/(mode+('-reference' if reference else ''));folder.mkdir(exist_ok=True)
    obs=observer(W/project)
    freeze={'status':'ORIGINAL_ARM_DEFINITIONS_DIAGNOSTIC_NOT_P9','observer':obs,'specs':specs,
      'watchdog_seconds':1200,'workers':4,'source_contract':'No six balance-tool changes; unchanged signed arm definitions, diagnostic seeds only.',
      'no_adaptation':True,'source_protocol':str(W/'PROTOCOL.json')}
    f=folder/'freeze.json'
    if f.exists():assert json.loads(f.read_text())==freeze
    else:write(f,freeze)
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        rows=list(pool.map(lambda s:execute(s,folder,obs),specs))
    assert observer(W/project)==obs
    write(folder/'SUMMARY.json',{'cells':len(rows),'rows':sum(x['n'] for x in rows),'all_complete':all(x['complete'] for x in rows)})
    return rows

def main():
    mode=sys.argv[1]
    if mode=='smoke':
        batch('smoke');batch('smoke','reference-project',True)
        pairs=[]
        for spec in panel('smoke'):
            if spec['catalogue']!='original':continue
            name=spec['id'];left=W/'smoke'/(name+'.ndjson');right=W/'smoke-reference'/(name+'.ndjson')
            # Manifest config, policy and entire run output agree, not just outcomes.
            assert left.read_bytes()==right.read_bytes(),name
            pairs.append({'id':name,'raw_sha256':sha(left)})
        write(W/'ORIGINAL-LAW-PARITY.json',{'equal_pairs':len(pairs),'full_native_rows_equal':True,
          'scope':'Original catalogue against unmodified product domain; source-recovery bridge, not new independent samples.','pairs':pairs})
        print('ORIGINAL_LAW_PARITY',len(pairs),flush=True)
    elif mode=='screen':
        assert json.loads((W/'ORIGINAL-LAW-PARITY.json').read_text())['equal_pairs']==16
        assert json.loads((W/'smoke/SUMMARY.json').read_text())['all_complete']
        batch('screen');print('ORIGINAL_ARM_SCREEN_COMPLETE 2048',flush=True)
    else:raise SystemExit('smoke|screen')
if __name__=='__main__':main()
