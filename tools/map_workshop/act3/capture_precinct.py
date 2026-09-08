"""Capture the native precinct matrix, failing on incomplete runs or source drift."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[3]
DEST = ROOT / 'docs/map/studies/act3-step3'
SAMPLES = {seed: DEST / f'precinct-v1-seed{seed}.json' for seed in [717, 4, 2026]}


def identity():
    paths = []
    for directory in ['tools/map_workshop', 'presentation/map', 'domain/map_layout']:
        paths.extend(p for p in (ROOT / directory).rglob('*')
                     if p.suffix in {'.gd', '.gdshader', '.glb', '.json'})
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(paths)}


def records(log, label):
    return [json.loads(line[len(label):]) for line in log.splitlines()
            if line.startswith(label)]


def capture(prefix, seeds, shapes, samples):
    receipt_path = DEST / f'{prefix}-receipt.json'
    if receipt_path.exists():
        raise RuntimeError('Use a fresh capture prefix')
    sources = identity()
    receipt = {'source_sha256': sources, 'runs': [], 'status': 'incomplete'}
    receipt_path.write_text(json.dumps(receipt, indent=2) + '\n')
    for seed in seeds:
        sample = DEST / f'{prefix}-seed{seed}.json'
        shutil.copyfile(samples[seed], sample)
        for index, shape in enumerate(shapes):
            name = f'{prefix}-{seed}-{shape}'
            command = ['godot', '--path', str(ROOT), '-s',
                       'res://tools/map_workshop/act3/precinct_study.gd', '--',
                       '--sample=' + str(sample), '--viewport=' + shape,
                       '--exercise-input', '--exercise-all-nodes', '--exercise-routes']
            if index == 0:
                command += ['--audit-thresholds', '--audit-passage', '--audit-foundations']
            if seed == 717:
                command += ['--profile-native']
            started = time.monotonic()
            print('START', name, flush=True)
            result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=600)
            log = result.stdout + result.stderr
            (DEST / f'{name}.log').write_text(log)
            if result.returncode or 'SCRIPT ERROR' in log or '\nERROR:' in log:
                raise RuntimeError(f'{name} failed; inspect its log')
            if identity() != sources:
                raise RuntimeError('Source changed during matrix capture')
            inputs = records(log, 'PRECINCT_INPUT ')
            if len(inputs) != 1 or not inputs[0]['all_nodes']['ok'] or not inputs[0]['route_camera']['ok']:
                raise RuntimeError('Missing or failed input/route evidence')
            images = {}
            for view in ['whole', 'journey', 'court', 'threshold', 'passage', 'input']:
                target = DEST / f'{name}-{view}.png'
                shutil.copyfile('/tmp/act3-precinct-' + view + '.png', target)
                images[view] = {'file': target.name,
                                'sha256': hashlib.sha256(target.read_bytes()).hexdigest()}
            if index == 0:
                for source in [Path('/tmp/act3-threshold-mesh-audit.json'),
                               Path('/tmp/act3-foundation-audit.json')]:
                    shutil.copyfile(source, DEST / f'{name}-{source.name}')
            receipt['runs'].append({'seed': seed, 'shape': shape, 'command': command,
                                    'seconds': round(time.monotonic()-started, 2),
                                    'images': images, 'input': inputs[0],
                                    'timing': records(log, 'PRECINCT_TIMING ')})
            receipt_path.write_text(json.dumps(receipt, indent=2) + '\n')
            print('PASS', name, flush=True)
    receipt['status'] = 'native matrix captured; author visual inspection and final review required'
    receipt_path.write_text(json.dumps(receipt, indent=2) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--prefix', required=True)
    parser.add_argument('--seeds', type=int, nargs='+', choices=SAMPLES, default=[717, 4, 2026])
    parser.add_argument('--shapes', nargs='+', choices=['844x390', '1180x820', '1458x820'],
                        default=['844x390', '1180x820', '1458x820'])
    parser.add_argument('--sample', action='append', nargs=2, metavar=('SEED', 'PATH'), default=[])
    args = parser.parse_args()
    samples = dict(SAMPLES)
    for seed, path in args.sample:
        if int(seed) not in samples or not Path(path).is_file():
            parser.error('Each sample needs a supported seed and existing JSON file')
        samples[int(seed)] = Path(path)
    capture(args.prefix, args.seeds, args.shapes, samples)
