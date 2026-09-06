"""Capture a fresh native Act III study with source-bound provenance."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[3]
DEST = ROOT / 'docs/map/studies/act3-step3'
VIEWS = {'court': ['--clean'], 'whole': ['--whole'],
         'phone': ['--phone', '--journey', '--exercise']}


def source_identity():
    paths = sorted((ROOT / 'tools/map_workshop').rglob('*.gd'))
    paths += sorted((ROOT / 'tools/map_workshop').rglob('*.gdshader'))
    paths += [DEST / 'profile.json', ROOT / 'docs/map/studies/camera-composition/act3-seed717.json']
    return {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in paths}


def capture(prefix, views):
    receipt_path = DEST / f'{prefix}-receipt.json'
    if receipt_path.exists() or any(DEST.glob(f'{prefix}-*.png')):
        raise RuntimeError('Use a fresh prefix; candidate images are never mixed or overwritten')
    source = source_identity()
    receipt = {'source_sha256': source, 'views': {}, 'status': 'incomplete'}
    receipt_path.write_text(json.dumps(receipt, indent=2) + '\n')
    for view in views:
        image = DEST / f'{prefix}-{view}.png'
        command = ['godot', '--path', str(ROOT), '-s',
                   'res://tools/map_workshop/act3/run.gd', '--', '--inspect',
                   '--profile=res://docs/map/studies/act3-step3/profile.json',
                   *VIEWS[view], '--output=' + str(image)]
        started = time.monotonic()
        run = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=360)
        log = run.stdout + run.stderr
        (DEST / f'{prefix}-{view}.log').write_text(log)
        if run.returncode or 'SCRIPT ERROR' in log or '\nERROR:' in log or not image.exists():
            raise RuntimeError(f'Native {view} capture failed')
        if source_identity() != source:
            raise RuntimeError('Study source changed during capture; discard this candidate')
        if view == 'phone':
            geometry = json.loads(image.with_name(image.stem + '-geometry.json').read_text())
            assert geometry['nodes'] == 65 and geometry['edges'] == 76
            assert geometry['rendered_deck']['missing'] == 0
            assert geometry['bridge_walkway']['decoration_hits'] == 0
            assert geometry['clearance']['terrain_body_hits'] == 0
            assert geometry['clearance']['architecture']['bounds_hits'] == 0
            inputs = json.loads(image.with_name(image.stem + '-input.json').read_text())
            assert all(v for v in inputs.values() if isinstance(v, bool)), inputs
        receipt['views'][view] = {'image': image.name,
                                  'image_sha256': hashlib.sha256(image.read_bytes()).hexdigest(),
                                  'seconds': round(time.monotonic()-started, 2)}
        receipt_path.write_text(json.dumps(receipt, indent=2) + '\n')
        print(f'{view}: captured and checked', flush=True)
    receipt['status'] = 'captured; visual review still required'
    receipt_path.write_text(json.dumps(receipt, indent=2) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--prefix', required=True)
    parser.add_argument('--views', nargs='+', choices=VIEWS, default=list(VIEWS))
    args = parser.parse_args()
    capture(args.prefix, args.views)
