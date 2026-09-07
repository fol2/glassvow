#!/usr/bin/env python3
"""Capture the complete native Step 3 guidance matrix and real combat pairs."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import time
ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'docs/map/studies/act3-step3/precinct-v4'
SHAPES = ['1458x820', '1180x820', '844x390']
def run(command, name):
    started = time.monotonic()
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=600)
    log = result.stdout + result.stderr
    (OUT / (name + '.log')).write_text(log)
    if result.returncode or 'SCRIPT ERROR' in log or '\nERROR:' in log:
        raise RuntimeError(name + ' failed; inspect the retained log')
    return log, round(time.monotonic() - started, 2)
def main():
    OUT.mkdir(exist_ok=True)
    if (OUT/'receipt.json').exists():
        raise RuntimeError('Use a fresh output version; do not overwrite a receipt')
    record = {'head': subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(), 'runs':[], 'status':'running'}
    for seed in [717,4,2026]:
        for shape in SHAPES:
            name = f'map-{seed}-{shape}'
            print('START', name, flush=True)
            command = ['godot','--path',str(ROOT),'-s','res://tools/map_workshop/act3/precinct_study.gd','--',
                       f'--sample=res://docs/map/studies/act3-step3/precinct-v2-seed{seed}.json',
                       '--viewport='+shape,'--exercise-input','--exercise-guidance']
            if seed == 717: command.append('--profile-native')
            log, seconds = run(command,name)
            checks = [json.loads(line.removeprefix('PRECINCT_INPUT ')) for line in log.splitlines() if line.startswith('PRECINCT_INPUT ')]
            assert len(checks)==1 and checks[0]['guidance']['ok']
            images = []
            for view in ['arrival','choice-0','choice-1','overview']:
                source = Path('/tmp/act3-guidance-'+view+'.png')
                target = OUT/(name+'-'+view+'.png')
                shutil.copyfile(source,target)
                images.append(target.name)
            for view in ['whole','court','journey','threshold','passage']:
                target = OUT/(name+'-'+view+'.png')
                shutil.copyfile('/tmp/act3-precinct-'+view+'.png',target)
                images.append(target.name)
            record['runs'].append({'seed':seed,'shape':shape,'seconds':seconds,'checks':checks[0],'images':images})
            print('PASS', name, flush=True)
    for shape, stage in zip(SHAPES,['desktop-landscape','pad-landscape','phone-landscape']):
        name = 'combat-'+shape
        log, seconds = run(['godot','--path',str(ROOT),'-s','res://tools/map_workshop/act3/combat_ground_study.gd','--','--fight=duskfang','--kind=elite','--act=2','--seed=717','--shape='+stage,'--vp='+shape],name)
        assert 'single_frozen_scene=true replaced_plates=1' in log
        for state in ['before','after']:
            shutil.copyfile('/tmp/act3-combat-'+shape.split('x')[0]+'-'+state+'.png',OUT/(name+'-'+state+'.png'))
    run(['godot','--path',str(ROOT),'-s','res://tools/map_workshop/act3/verify_ground_alpha.gd'],'ground-alpha')
    record['media_sha256']={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(OUT.glob('*.png'))}
    record['status']='native matrix complete; visual inspection and independent review reported separately'
    (OUT/'receipt.json').write_text(json.dumps(record,indent=2)+'\n')
    print('MATRIX COMPLETE',flush=True)
if __name__=='__main__': main()
