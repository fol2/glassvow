"""Prepare the specified independent component experiment; never run it.

Pass the restored workspace containing price/ and snapshot/. Existing component
sources are never overwritten. This changes only a copied research driver.
"""
from pathlib import Path
from copy import deepcopy
import hashlib
import json
import shutil
import sys

if len(sys.argv) != 2:
    raise SystemExit('usage: prepare_components.py RESTORED_WORKSPACE')
root = Path(sys.argv[1]).resolve()
component = root/'components'
project = component/'project'
if project.exists():
    raise RuntimeError('Never overwrite an existing component source')
shutil.copytree(root/'price/project', project,
                ignore=shutil.ignore_patterns('.godot', '__pycache__'))
shutil.copyfile(root/'price/study.py', component/'study.py')
source = root/'price/content/production2_energy0.json'
raw = source.read_bytes()
assert hashlib.sha256(raw).hexdigest() == '48a03cc213f8505c4133bf5c179eeaa8975d1bfb1655c4c864fd6c9312508246'
base = json.loads(raw)
output = {}
(component/'content').mkdir()
for producer in (0, 1):
    for consumer in (0, 1):
        data = deepcopy(base)
        for upgraded in (False, True):
            for card_id in ('pyreheart', 'novaflare'):
                card = data['cards'][card_id]['up'] if upgraded else data['cards'][card_id]
                if card_id == 'pyreheart' and not producer:
                    for effect in card['effects']:
                        if effect.get('id') == 'emberflow':
                            effect['n'] = 0
                elif card_id == 'novaflare' and not consumer:
                    for effect in card['effects']:
                        if effect.get('id') == 'emberNova':
                            effect['n'] = 0
                            effect['floor_per'] = 0
        label = f'p{producer}c{consumer}'
        path = component/'content'/f'{label}.json'
        encoded = raw if producer and consumer else (json.dumps(data, ensure_ascii=False, indent=2)+'\n').encode()
        path.write_bytes(encoded)
        output[label] = {'path': str(path), 'sha256': hashlib.sha256(encoded).hexdigest(),
                         'producer': producer, 'consumer': consumer}
(component/'content/manifest.json').write_text(json.dumps(output, indent=2)+'\n')
path = project/'lab_runner.gd'
text = path.read_text()
needle = '   var events: Array[Dictionary]=observed_apply(g,action,cast_id if cast_id!="" else str(action["t"]))'
assert text.count(needle) == 1
text = text.replace(needle, '   var nova_fuel_before: int=ji(g.run.stats.get("embersSpent",0))\n'+needle)
needle = '    if cast_id=="novaflare":measure("nova_casts");measure("nova_embers_sum",cast_embers)'
assert text.count(needle) == 1
text = text.replace(needle, needle+'\n    if cast_id=="novaflare":\n     measure("nova_fuel_paid",ji(g.run.stats.get("embersSpent",0))-nova_fuel_before)\n     measure("nova_stock_hist:"+str(cast_embers))')
path.write_text(text)
print('COMPONENT_PREPARED', len(output), 'recipes; no gameplay or policy change')
