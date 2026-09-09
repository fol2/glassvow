"""Guarded native-effect expansion; compare with existing exact stock captures.

No old native case is rerun as a reference and no population sample is added.
The source argument proves the effect-loop expansion parametrically; finite
native comparisons check its actual wiring into the unmodified envelope.
"""
from __future__ import annotations
import hashlib,json,lzma,os,shutil,subprocess,sys,tempfile,time
from pathlib import Path
R=Path(__file__).resolve().parent
RAW='d8fe513d2cc8992e6168fb3ec4a64e970dd2b5ee82bd2e6c247a33df06bcfd2f'

def require(ok,reason):
    if not ok:raise ValueError(reason)
def sha(b):return hashlib.sha256(b).hexdigest()
def render(x):return (json.dumps(x,indent=2)+'\n').encode()
def source_probe(source):
    replacements=[('res://roles.gd','res://expanded.gd',2),('res://probe.gd','res://expanded_probe.gd',1),
                  ('for mask: int in [-1,0,1,2,3]:','for mask: int in [0]:',1)]
    for old,new,count in replacements:
        require(source.count(old)==count,'unexpected probe source:'+old)
        source=source.replace(old,new)
    return source

def observations(raw):
    rows=[json.loads(s) for s in raw.splitlines()]
    require(rows and rows[0]['kind']=='header','capture header')
    return rows[0],rows[1:]
def key(row):return tuple(row['config'][x] for x in ('family','aspect','vow','up','context'))
def without_config(row):return {k:v for k,v in row.items() if k!='config'}

def compare(old,new,contract,expanded_hash,probe_hash):
    require(sha(old)==RAW,'original captured bytes')
    oh,oldrows=observations(old);nh,newrows=observations(new)
    for k in ('engine','content_sha256','combat_sha256','contract_sha256'):
        require(nh[k]==oh[k],'unchanged source identity:'+k)
    require(nh['roles_sha256']==expanded_hash and nh['probe_sha256']==probe_hash,'actual expanded source binding')
    expected={key(row):row for row in oldrows if row['config']['mask']==-1}
    require(len(expected)==208 and len(newrows)==208,'full expansion rectangle')
    seen=set();matched=[]
    for row in newrows:
        k=key(row)
        require(k in expected and k not in seen and row['config']['mask']==0,'exact comparison assignment')
        seen.add(k)
        require(without_config(row)==without_config(expected[k]),'complete state/event/cost/reset inequality:'+str(k))
        matched.append({'config':row['config'],'full_trace_equal':True,'reference_sha256':sha(render(without_config(expected[k])))})
    require(seen==set(expected),'missing comparison')
    return {'status':'GUARDED_WITHIN_CARD_EXPANSION_EQUIVALENT_ON_ALL_FIXED_CONTEXTS',
            'reference_capture_sha256':sha(old),'expanded_capture_sha256':sha(new),
            'comparisons':matched,'source_rule_scope':'Single native card envelope; unchanged source/guards/functions. Not equivalent to three separate played cards, or removal of acquisition/lifecycle context.',
            'formal_scope':'Parametric effect-loop rewriting argument in PROOF.md plus finite native wiring corroboration; NOT a complete closed-family quotient or package admission.',
            'new_constructed_traces':208,'reused_reference_traces':208,
            'new_independent_samples':0,'packages_admitted':0,'p9_certified':False}

def main(repo,engine,out,mode='capture'):
    repo,engine,out=map(lambda p:Path(p).resolve(),(repo,engine,out))
    parent=R.parent
    p=json.loads((R/'PROTOCOL.json').read_bytes())
    for name,h in p['source_sha256'].items():require(sha((R/name).read_bytes())==h,'frozen source:'+name)
    contract=json.loads((parent/'CONTRACT.json').read_bytes())
    original=lzma.decompress((parent/'native-1/raw.ndjson.xz').read_bytes())
    require(sha(original)==RAW,'reference capture')
    transformed=source_probe((parent/'probe.gd').read_text())
    def decoded():
        return compare(original,lzma.decompress((out/'raw.ndjson.xz').read_bytes()),contract,sha((R/'expanded.gd').read_bytes()),sha(transformed.encode()))
    if mode=='verify':
        require((out/'RESULTS.json').read_bytes()==render(decoded()),'published result byte equality')
        print('EXPANSION_OFFLINE_MATCH');return
    require(not out.exists(),'output already exists');out.mkdir(parents=True)
    terminal={'status':'INCONCLUSIVE','p9_certified':False,'packages_admitted':0,'new_independent_samples':0}
    try:
        require(sha(engine.read_bytes())==contract['engine_sha256'],'exact engine')
        with tempfile.TemporaryDirectory(prefix='p9-effect-expansion-') as temp:
            project=Path(temp)
            for n in ('domain','content'):shutil.copytree(repo/n,project/n)
            require(sha((project/'domain/rules/combat.gd').read_bytes())==contract['combat_sha256'],'combat')
            require(sha((project/'content/full-content.json').read_bytes())==contract['content_sha256'],'content')
            (project/'tools').mkdir()
            for n in ('vow_incentives.gd','check_scripts.sh'):shutil.copyfile(repo/'tools'/n,project/'tools'/n)
            (project/'expanded_probe.gd').write_text(transformed)
            shutil.copyfile(R/'expanded.gd',project/'expanded.gd')
            (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="P9 effect expansion"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
            env=dict(os.environ,GODOT=str(engine),GODOT_SILENCE_ROOT_WARNING='1')
            commands=[('import',[str(engine),'--headless','--path',str(project),'--import']),
                      ('parse',['bash','tools/check_scripts.sh','expanded.gd','expanded_probe.gd']),
                      ('native',[str(engine),'--headless','--path',str(project),'-s','res://expanded_probe.gd','--',str(parent/'CONTRACT.json'),str(out/'raw.ndjson')])]
            for label,cmd in commands:
                with (out/(label+'.stdout')).open('wb') as so,(out/(label+'.stderr')).open('wb') as se:
                    started=time.monotonic();proc=subprocess.Popen(cmd,cwd=project,env=env,stdout=so,stderr=se)
                    try:
                        while proc.poll() is None:
                            require(time.monotonic()-started<120,'invocation watchdog:'+label)
                            path=out/'raw.ndjson'
                            require(not path.exists() or path.stat().st_size<=134217728,'live raw cap')
                            time.sleep(.1)
                    finally:
                        if proc.poll() is None:proc.kill();proc.wait()
                require(proc.returncode==0 and b'ERROR:' not in (out/(label+'.stderr')).read_bytes(),label)
            raw=(out/'raw.ndjson').read_bytes();require(len(raw)<=134217728,'raw cap')
            (out/'raw.ndjson.xz').write_bytes(lzma.compress(raw,preset=6));(out/'raw.ndjson').unlink()
            result=decoded();(out/'RESULTS.json').write_bytes(render(result))
            terminal.update(status=result['status'],constructed_traces=208,raw_bytes=len(raw),raw_sha256=sha(raw))
    except Exception as exc:
        terminal['failure']=repr(exc)
        path=out/'raw.ndjson'
        if path.exists():(out/'raw.ndjson.xz').write_bytes(lzma.compress(path.read_bytes()));path.unlink()
    terminal['files']={p.name:{'bytes':p.stat().st_size,'sha256':sha(p.read_bytes())} for p in out.iterdir() if p.is_file()}
    (out/'TERMINAL.json').write_bytes(render(terminal))
    require(terminal['status']!='INCONCLUSIVE',terminal.get('failure'))

if __name__=='__main__':main(*sys.argv[1:])
