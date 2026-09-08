"""Capture one coherent Act II native review candidate, serially on the GPU."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time
import tempfile

ROOT = Path(__file__).resolve().parents[3]
DEST = ROOT / 'docs/map/studies/act2-step3'
PROFILE = DEST / 'profile-library-waterline.json'
VIEWS = {
    'boss': ['--detail=boss'],
    'submerged': ['--detail=submerged', '--clean'],
    'library': ['--detail=library', '--clean'],
    'precinct': ['--detail=precinct', '--clean'],
    'bridge': ['--detail=bridge', '--clean'],
    'stairs': ['--detail=stairs', '--clean'],
    'whole': ['--whole'],
    'phone': ['--phone', '--journey', '--exercise'],
    'pad': ['--pad', '--journey', '--exercise'],
}


def capture(views, prefix):
    receipt = {'profile': str(PROFILE.relative_to(ROOT)),
               'profile_sha256': hashlib.sha256(PROFILE.read_bytes()).hexdigest(), 'views': {}}
    existing = DEST / f'{prefix}-capture-receipt.json'
    if existing.exists():
        previous = json.loads(existing.read_text())
        if previous.get('profile_sha256') == receipt['profile_sha256']:
            receipt['views'] = previous.get('views', {})
    for name in views:
        output = DEST / f'{prefix}-{name}.png'
        command = ['godot', '--path', str(ROOT), '--rendering-method', 'mobile',
                   '-s', 'res://tools/map_workshop/act2/run.gd', '--', '--inspect',
                   '--profile=res://' + str(PROFILE.relative_to(ROOT)), *VIEWS[name],
                   '--output=' + str(output)]
        started = time.monotonic()
        run = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=300)
        log = run.stdout + run.stderr
        (DEST / f'{prefix}-{name}.log').write_text(log)
        if run.returncode or 'SCRIPT ERROR' in log or '\nERROR:' in log or not output.exists():
            raise RuntimeError(f'Native {name} capture failed; see its log')
        geometry = json.loads(output.with_name(output.stem + '-geometry.json').read_text())
        placement = json.loads(output.with_name(output.stem + '-placement.json').read_text())
        assert geometry['nodes'] == 65 and geometry['edges'] == 76
        assert not geometry['missing_route_samples'] and geometry['rendered_deck']['missing'] == 0
        assert geometry['rendered_width_checks']['sample_count'] > 0
        assert not geometry['rendered_width_checks']['failures']
        assert geometry.get('bridge_walkway', {}).get('decoration_hits', 0) == 0, geometry.get('bridge_walkway')
        assert geometry['bridgehead_overlap']['maximum_surface_separation'] < .001
        assert placement['bounds_hits'] == 0
        scenery = placement.get('scenery', {})
        assert scenery.get('shared_meshes') == 18
        assert len(scenery.get('families', {})) == 6
        assert scenery.get('instances', 0) > 0
        item = {'image': output.name, 'elapsed_seconds': round(time.monotonic()-started, 2)}
        if name in ('phone', 'pad'):
            controls = json.loads(output.with_name(output.stem + '-input.json').read_text())
            assert all(value for value in controls.values() if isinstance(value, bool)), controls
            item['input'] = controls
        receipt['views'][name] = item
        (DEST / f'{prefix}-capture-receipt.json').write_text(json.dumps(receipt, indent=2)+'\n')
        print(f'{name}: native capture and bounded checks passed', flush=True)


def capture_water(prefix):
    with tempfile.TemporaryDirectory(prefix='act2-water-') as frames:
        output = DEST / f'{prefix}-water.png'
        command = ['godot', '--path', str(ROOT), '--rendering-method', 'mobile',
                   '-s', 'res://tools/map_workshop/act2/run.gd', '--', '--inspect',
                   '--profile=res://' + str(PROFILE.relative_to(ROOT)), '--detail=library',
                   '--clean', '--frames=' + frames, '--output=' + str(output)]
        run = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=300)
        log = run.stdout + run.stderr
        (DEST / f'{prefix}-water.log').write_text(log)
        if run.returncode or 'SCRIPT ERROR' in log or '\nERROR:' in log:
            raise RuntimeError('Native water capture failed; see its log')
        assert len(list(Path(frames).glob('*.png'))) == 240
        movie = DEST / f'{prefix}-water.mp4'
        subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-framerate', '30',
                        '-i', str(Path(frames)/'%04d.png'), '-c:v', 'libx264', '-crf', '19',
                        '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(movie)], check=True)
        probe = subprocess.run(['ffprobe', '-v', 'error', '-show_streams', '-show_format',
                                '-of', 'json', str(movie)], capture_output=True, text=True, check=True)
        (DEST / f'{prefix}-water-media.json').write_text(probe.stdout)
        metadata = json.loads(probe.stdout)
        video = metadata['streams'][0]
        assert video['width'] == 1458 and video['height'] == 820
        assert int(video['nb_frames']) == 240 and float(metadata['format']['duration']) == 8.0
        print('water: eight-second native film encoded and checked', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--views', nargs='+', choices=VIEWS, default=list(VIEWS))
    parser.add_argument('--prefix', default='v1')
    parser.add_argument('--film', action='store_true')
    args = parser.parse_args()
    capture(args.views, args.prefix)
    if args.film:
        capture_water(args.prefix)
