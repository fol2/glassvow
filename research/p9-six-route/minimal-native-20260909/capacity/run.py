"""Fixed inexpensive native-policy capacity. No content or controller retune."""
from __future__ import annotations
from concurrent.futures import ThreadPoolExecutor
import hashlib,json,lzma,os,shutil,subprocess,sys,tempfile,time
from pathlib import Path
import read
R=Path(__file__).resolve().parent

def save(p,v):p.write_text(json.dumps(v,indent=2)+'\n')
def h(p):return read.sha(p.read_bytes())
def transform(s):
    needle='var game: GlassvowGame = GlassvowGame.new(content, run)'
    read.require(s.count(needle)==1 and s.count('class_name BalanceSim')==1,'bound simulator constructor')
    return s.replace('class_name BalanceSim','class_name ObservedNativeOpportunitySim',1).replace(needle,'var game: GlassvowGame = preload("res://observed_game.gd").new(content, run)',1)

def prepare(base,project,p):
    for d in ('domain','content'):shutil.copytree(base/d,project/d)
    domain={str(f.relative_to(project)):h(f) for f in sorted((project/'domain').rglob('*')) if f.is_file()}
    read.require(read.sha(json.dumps(domain,sort_keys=True,separators=(',',':')).encode())==p['domain_manifest_sha256'],'domain identity')
    read.require(h(project/'content/full-content.json')==p['content_sha256'],'content identity')
    (project/'tools').mkdir()
    for n,want in p['all_tool_sha256'].items():
        read.require(h(base/'tools'/n)==want,'native tool '+n);shutil.copyfile(base/'tools'/n,project/'tools'/n)
    text=transform((base/'tools/balance_sim.gd').read_text())
    read.require(read.sha(text.encode())==p['observed_sim_sha256'],'only specified constructor transformed')
    (project/'tools/observed_sim.gd').write_text(text)
    for n in ('observed_game.gd','probe.gd'):shutil.copyfile(R/n,project/n)
    (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="P9 native opportunity bound"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')

def invocation(cmd,project,folder,label):
    start=time.monotonic();proc=None
    try:
        with (folder/(label+'.stdout')).open('wb') as so,(folder/(label+'.stderr')).open('wb') as se:
            proc=subprocess.Popen(cmd,cwd=project,stdout=so,stderr=se,env=dict(os.environ,GODOT_SILENCE_ROOT_WARNING='1'))
            while proc.poll() is None:
                read.require(time.monotonic()-start<120,'INVOCATION_WATCHDOG')
                read.require(sum(p.stat().st_size for p in folder.glob('*.ndjson'))<=536870912,'RAW_CAP')
                time.sleep(.1)
        read.require(proc.returncode==0 and b'ERROR:' not in (folder/(label+'.stderr')).read_bytes(),'NATIVE_OR_DELIVERY_ERROR:'+label)
    finally:
        if proc is not None and proc.poll() is None:proc.kill();proc.wait()
    return {'command':cmd,'returncode':proc.returncode,'seconds':time.monotonic()-start}

def execute(cfg,project,engine,folder,p):
    folder.mkdir();save(folder/'CONFIG.json',cfg);failure=None;result=None;receipt={}
    try:
        receipt=invocation([str(engine),'--headless','--path',str(project),'-s','res://probe.gd','--',str(folder/'CONFIG.json'),str(folder/'endpoints.ndjson'),str(folder/'trace.ndjson')],project,folder,'native')
    except Exception as exc:failure=repr(exc)
    raw=[]
    for f in folder.glob('*.ndjson'):
        b=f.read_bytes();raw.append({'name':f.name,'bytes':len(b),'sha256':read.sha(b)})
        f.with_suffix(f.suffix+'.xz').write_bytes(lzma.compress(b,preset=3));f.unlink()
    if failure is None:
        try:
            result=read.cell(folder,cfg,p)
            save(folder/'CELL.json',{k:v for k,v in result.items() if k!='endpoints'})
        except Exception as exc:failure=repr(exc)
    save(folder/'EXECUTION.json',{'status':'COMPLETE' if failure is None else 'INCONCLUSIVE','failure':failure,'native':receipt,'raw':raw,'p9_certified':False})
    read.require(failure is None,failure)
    return result

def offline(out,p):
    results={}
    for aspect in ('duskblade','ashwarden'):
        for vow in (5,0):
            folder=out/f'{aspect}-v{vow}'
            if not folder.exists():continue
            cells=[read.cell(folder/f'p{first:03}',read.config(aspect,vow,first,32),p) for first in range(0,128,32)]
            result=read.aggregate(cells)
            read.require((folder/'RESULTS.json').read_bytes()==(json.dumps(result,indent=2)+'\n').encode(),'frozen result bytes')
            results[f'{aspect}-v{vow}']=result
    terminal=json.loads((out/'TERMINAL.json').read_bytes())
    read.require(terminal['status']=='FIXED_NATIVE_POLICY_CAPACITY_COMPLETE_NOT_ADMISSION','complete terminal')
    for aspect in ('duskblade','ashwarden'):
        read.require(aspect+'-v5' in results,'required V5 coverage')
        permits_v0=results[aspect+'-v5']['status']=='NATIVE_POLICY_CAPACITY_NOT_FALSIFIED_NOT_ADMISSION'
        read.require((aspect+'-v0' in results)==permits_v0,'conditional V0 entry')
    read.require(terminal['grids']==results,'unchanged terminal aggregation')
    return results

def main(base,engine,out,mode='capture'):
    base,engine,out=map(lambda s:Path(s).resolve(),(base,engine,out));p=json.loads((R/'PROTOCOL.json').read_bytes())
    for n,want in p['source_sha256'].items():read.require(h(R/n)==want,'source '+n)
    if mode=='verify':
        results=offline(out,p);read.require(bool(results),'no completed grid');print('CAPACITY_OFFLINE_MATCH',list(results));return
    read.require(not out.exists(),'capture already exists');out.mkdir(parents=True)
    terminal={'status':'INCONCLUSIVE','grids':{},'packages_admitted':0,'p9_certified':False,'independent_confirmation_samples':0}
    try:
        read.require(h(engine)==p['engine_sha256'],'engine')
        with tempfile.TemporaryDirectory(prefix='p9-native-capacity-') as t:
            project=Path(t);prepare(base,project,p)
            invocation([str(engine),'--headless','--path',str(project),'--import'],project,out,'import')
            env=dict(os.environ,GODOT=str(engine),GODOT_SILENCE_ROOT_WARNING='1')
            z=subprocess.run(['bash','tools/check_scripts.sh','observed_game.gd','probe.gd','tools/observed_sim.gd'],cwd=project,capture_output=True,env=env,timeout=120)
            (out/'parse.stdout').write_bytes(z.stdout);(out/'parse.stderr').write_bytes(z.stderr);read.require(z.returncode==0,'parse')
            smoke=out/'integration';smoke.mkdir();pairs=[]
            for aspect in ('duskblade','ashwarden'):
                for vow in (0,5):
                    results=[]
                    for observed in (False,True):
                        cfg=read.config(aspect,vow,0,1,observed,True)
                        results.append(execute(cfg,project,engine,smoke/f'{aspect}-v{vow}-o{int(observed)}',p)['endpoints'])
                    read.require(results[0]==results[1],'OBSERVER_CHANGED_FULL_ENDPOINT')
                    pairs.append({'aspect':aspect,'vow':vow,'full_endpoint_equal':True})
            save(smoke/'RESULTS.json',{'pairs':pairs,'new_population_rows':0})
            eligible=['duskblade','ashwarden']
            for vow in (5,0):
                next_eligible=[]
                for aspect in eligible:
                    folder=out/f'{aspect}-v{vow}';folder.mkdir()
                    with ThreadPoolExecutor(max_workers=2) as pool:
                        cells=list(pool.map(lambda first:execute(read.config(aspect,vow,first,32),project,engine,folder/f'p{first:03}',p),range(0,128,32)))
                    result=read.aggregate(cells);save(folder/'RESULTS.json',result);terminal['grids'][f'{aspect}-v{vow}']=result
                    if result['status']=='NATIVE_POLICY_CAPACITY_NOT_FALSIFIED_NOT_ADMISSION':next_eligible.append(aspect)
                eligible=next_eligible
            terminal['status']='FIXED_NATIVE_POLICY_CAPACITY_COMPLETE_NOT_ADMISSION'
    except Exception as exc:terminal['failure']=repr(exc)
    terminal['files']={str(f.relative_to(out)):{'bytes':f.stat().st_size,'sha256':h(f)} for f in out.rglob('*') if f.is_file()}
    save(out/'TERMINAL.json',terminal)
    read.require(terminal['status']!='INCONCLUSIVE',terminal.get('failure'))

if __name__=='__main__':main(*sys.argv[1:])
