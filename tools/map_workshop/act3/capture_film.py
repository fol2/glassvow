"""Record a deterministic six-second native halo study, preserving source identity."""
import hashlib
import json
import subprocess
import tempfile
from capture_review import ROOT, DEST, source_identity


def capture(prefix):
    movie = DEST / f'{prefix}-halo.mp4'
    if movie.exists():
        raise RuntimeError('Use a fresh film prefix')
    source = source_identity()
    with tempfile.TemporaryDirectory(prefix='act3-halo-') as frames:
        poster = DEST / f'{prefix}-halo.png'
        command = ['godot', '--path', str(ROOT), '-s',
                   'res://tools/map_workshop/act3/run.gd', '--', '--inspect', '--clean',
                   '--profile=res://docs/map/studies/act3-step3/profile.json',
                   '--frames=' + frames, '--output=' + str(poster)]
        run = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=360)
        log = run.stdout + run.stderr
        (DEST / f'{prefix}-halo.log').write_text(log)
        if run.returncode or 'SCRIPT ERROR' in log or '\nERROR:' in log:
            raise RuntimeError('Native halo capture failed')
        from pathlib import Path
        images = list(Path(frames).glob('*.png'))
        assert len(images) == 180
        assert source_identity() == source, 'Source changed during film capture'
        subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
                        '-framerate', '30', '-i', frames + '/%04d.png',
                        '-c:v', 'libx264', '-crf', '19', '-pix_fmt', 'yuv420p',
                        '-movflags', '+faststart', str(movie)], check=True)
    probe = subprocess.run(['ffprobe', '-v', 'error', '-show_streams', '-show_format',
                            '-of', 'json', str(movie)], capture_output=True, text=True, check=True)
    metadata = json.loads(probe.stdout)
    assert float(metadata['format']['duration']) == 6.0
    assert int(metadata['streams'][0]['nb_frames']) == 180
    (DEST / f'{prefix}-halo-receipt.json').write_text(json.dumps({
        'source_sha256': source, 'command': command, 'media': metadata,
        'movie_sha256': hashlib.sha256(movie.read_bytes()).hexdigest(),
        'status': 'encoded; visual playback review required'}, indent=2) + '\n')
    print('halo: six seconds encoded and checked', flush=True)


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--prefix', required=True)
    capture(parser.parse_args().prefix)
