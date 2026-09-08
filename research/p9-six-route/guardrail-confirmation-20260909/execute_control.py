"""Execute one frozen signed-control rectangle, preserving complete available output."""
from __future__ import annotations
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import lzma
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
from read_control import analyze, require, sha, specifications, validate

R = Path(__file__).resolve().parent


def save(path, obj):
    Path(path).write_text(json.dumps(obj, indent=2) + '\n')


def command(args, folder, label, cwd, seconds):
    start = time.monotonic(); code = None; failure = None
    try:
        with (folder / (label+'.stdout')).open('wb') as stdout, (folder / (label+'.stderr')).open('wb') as stderr:
            p = subprocess.run(args, cwd=cwd, stdout=stdout, stderr=stderr, timeout=seconds,
                               env=dict(os.environ, GODOT_SILENCE_ROOT_WARNING='1'))
        code = p.returncode
    except subprocess.TimeoutExpired:
        failure = 'INVOCATION_WATCHDOG'
    err = (folder / (label+'.stderr')).read_bytes()
    if code != 0 or b'ERROR:' in err or b'Failed to load script' in err:
        failure = failure or 'PROCESS_OR_NATIVE_DIAGNOSTIC'
    return {'command': args, 'returncode': code, 'failure': failure,
            'seconds': time.monotonic()-start}


def prepare(repo, target, p):
    baseline = target / 'baseline'; baseline.mkdir()
    for name in ('domain', 'content'):
        shutil.copytree(repo/name, baseline/name)
    subprocess.run([sys.executable, str(repo/'research/p9-six-route/source-package-audit-20260908/assemble.py'),
                    str(repo), str(target/'candidate')], check=True, capture_output=True, timeout=120)
    projects = {}
    for cat in ('baseline','candidate'):
        project = target/cat; tools = project/'tools'; tools.mkdir(exist_ok=True)
        for name, digest in p['tool_sha256'].items():
            source=repo/'tools'/name; require(sha(source.read_bytes())==digest,'TOOL:'+name)
            shutil.copyfile(source,tools/name)
        for name in ('balance_sweep.gd','check_scripts.sh'):
            shutil.copyfile(repo/'tools'/name,tools/name)
        shutil.copyfile(R/'probe.gd',project/'probe.gd')
        (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="P9 signed-control screen"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        require(sha((project/'content/full-content.json').read_bytes()) == p['content_sha256'][cat], 'CONTENT:'+cat)
        require(sha((project/'domain/rules/combat.gd').read_bytes()) == p['combat_sha256'][cat], 'COMBAT:'+cat)
        domain={str(x.relative_to(project)):sha(x.read_bytes()) for x in sorted((project/'domain').rglob('*')) if x.is_file()}
        require(sha(json.dumps(domain,sort_keys=True,separators=(',',':')).encode()) == p['domain_manifest_sha256'][cat], 'DOMAIN:'+cat)
        projects[cat] = project
    return projects


def execute(spec, project, engine, folder, protocol):
    stem=spec['id']; cfg=folder/(stem+'.config.json'); raw=folder/(stem+'.ndjson')
    save(cfg,spec)
    receipt=command([str(engine),'--headless','--path',str(project),'-s','res://probe.gd','--',str(cfg),str(raw)],
                    folder,stem,project,protocol['containment']['invocation_seconds'])
    receipt.update(config=spec,status='INCONCLUSIVE',raw=None)
    if raw.exists():
        data=raw.read_bytes();receipt['raw']={'bytes':len(data),'sha256':sha(data)}
        require(len(data)<=protocol['containment']['raw_bytes_per_cell'],'RAW_CAP')
        try:
            require(receipt['failure'] is None, receipt['failure'])
            validate([json.loads(x) for x in data.splitlines()],spec,protocol)
            receipt['status']='COMPLETE'
        except Exception as exc:
            receipt['failure']=repr(exc)
    save(folder/(stem+'.execution.json'),receipt)
    return receipt


def main(repo, engine, output, metadata_only=False):
    repo,engine,output=(Path(x).resolve() for x in (repo,engine,output))
    require(not output.exists(),'OUTPUT_ALREADY_EXISTS')
    output.mkdir(parents=True)
    p=json.loads((R/'PROTOCOL.json').read_bytes())
    require(sha(engine.read_bytes())==p['engine_sha256'],'ENGINE')
    for name,digest in p['source_sha256'].items():
        require(sha((R/name).read_bytes())==digest,'SOURCE:'+name)
    require(p['seeds_per_grid']==128 and p['arm']==2,'FROZEN_RECTANGLE')
    terminal={'status':'INCONCLUSIVE','packages_admitted':0,'p9_certified':False}
    try:
        with tempfile.TemporaryDirectory(prefix='p9-signed-controls-') as tmp:
            projects=prepare(repo,Path(tmp),p)
            for cat,project in projects.items():
                receipt=command([str(engine),'--headless','--path',str(project),'--import'],output,cat+'-import',project,120)
                require(receipt['failure'] is None,'IMPORT:'+cat)
                env=dict(os.environ,GODOT=str(engine))
                check=subprocess.run(['bash','tools/check_scripts.sh','probe.gd'],cwd=project,env=env,capture_output=True,timeout=120)
                (output/(cat+'-parse.stdout')).write_bytes(check.stdout)
                (output/(cat+'-parse.stderr')).write_bytes(check.stderr)
                require(check.returncode==0,'PARSE:'+cat)
            if metadata_only:
                # Output headers only. No game, seed, policy outcome or scientific observation.
                receipts=[]
                for spec in specifications(p):
                    spec=dict(spec,runs=0)
                    receipts.append(execute(spec,projects[spec['catalogue']],engine,output,p))
                require(all(r['status']=='COMPLETE' for r in receipts),'ZERO_ROW_METADATA')
                terminal.update(status='ZERO_ROW_SOURCE_AND_SIGNED_ARM_BINDING_PASS',rows=0)
            else:
                with ThreadPoolExecutor(max_workers=p['containment']['workers']) as pool:
                    receipts=list(pool.map(lambda spec:execute(spec,projects[spec['catalogue']],engine,output,p),specifications(p)))
                require(all(r['status']=='COMPLETE' for r in receipts),'INCOMPLETE_RECTANGLE')
                result=analyze(output,p);save(output/'RESULTS.json',result)
                terminal.update(status=result['status'],rows=result['rows'],decision=result['decision'])
    except Exception as exc:
        terminal['failure']=repr(exc)
    native=[]
    for path in output.glob('*.ndjson'):
        raw=path.read_bytes();compressed=lzma.compress(raw,preset=6)
        path.with_suffix(path.suffix+'.xz').write_bytes(compressed)
        native.append({'name':path.name,'raw_bytes':len(raw),'raw_sha256':sha(raw),'packed_bytes':len(compressed),'packed_sha256':sha(compressed)})
        path.unlink()
    terminal.update(raw=native,protocol_sha256=sha((R/'PROTOCOL.json').read_bytes()),
                    source_files=p['source_sha256'],new_native_outcome_rows=terminal.get('rows',0),
                    scope='Signed-control screen only; no package/P9 certificate or protected acceptance identities.')
    save(output/'TERMINAL.json',terminal)
    print(json.dumps({k:v for k,v in terminal.items() if k not in ('raw','source_files')},sort_keys=True))
    return 0 if terminal['status']!='INCONCLUSIVE' else 3


if __name__=='__main__':
    raise SystemExit(main(*sys.argv[1:4],metadata_only='--metadata-only' in sys.argv))
