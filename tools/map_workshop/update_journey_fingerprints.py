#!/usr/bin/env python3
"""Record imported woodland source identities for export-safe visual cache keys."""
import hashlib
import json
from pathlib import Path
import re

root = Path(__file__).resolve().parents[2]
kinds = re.findall(r'^\s*"([^"]+)": Vector2', (root / 'presentation/map/landscape/kit.gd').read_text(), re.M)
folder = root / 'assets/art/map-journey'
record = {'schema_version': 1, 'assets': {kind: hashlib.sha256((folder / f'{kind}.glb').read_bytes()).hexdigest() for kind in sorted(kinds)}}
(folder / 'runtime-fingerprints.json').write_text(json.dumps(record, indent=2) + '\n')
