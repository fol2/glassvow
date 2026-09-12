"""Summarise exported Metal GPU intervals for one PID without copying trace metadata.

Export metal-gpu-intervals with xctrace first. Nested work and concurrent channels
are unioned, not summed. Incomplete first/last frames are excluded. This reports
active GPU time, not frame latency or an isolated-device certification.
"""
import argparse
import json
import math
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path


def summarise(path, pid):
    tree = ET.parse(path)
    identities = {e.attrib['id']: e for e in tree.iter() if 'id' in e.attrib}
    frames = defaultdict(list)
    for row in tree.iter('row'):
        values = [identities[e.attrib['ref']] if 'ref' in e.attrib else e for e in row]
        if len(values) < 11 or values[10].attrib.get('fmt', '') != f'godot ({pid})':
            continue
        if values[7].text != 'Active' or values[3].tag != 'gpu-frame-number':
            continue
        number = int(values[3].text)
        if number <= 0:
            continue
        start = int(values[0].text)
        frames[number].append((start, start + int(values[1].text)))
    samples = []
    for number in sorted(frames)[1:-1]:
        intervals = sorted(frames[number])
        start, end = intervals[0]
        active = 0
        for left, right in intervals[1:]:
            if left > end:
                active += end - start
                start, end = left, right
            else:
                end = max(end, right)
        samples.append((active + end - start) / 1_000_000)
    if len(samples) < 30:
        raise ValueError('Fewer than 30 complete GPU frame samples')
    ordered = sorted(samples)
    return {'pid': pid, 'frames': len(samples), 'active_gpu_ms': {
        'median': ordered[len(ordered)//2], 'p95': ordered[math.ceil(.95*len(ordered))-1],
        'max': ordered[-1]}, 'scope': 'Host Metal trace; per-frame union of active GPU intervals for this PID; excludes first/last frame; other applications may contend; not GPU allocation or frame latency'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('xml', type=Path)
    parser.add_argument('--pid', type=int, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    report = summarise(args.xml, args.pid)
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report))
