"""Execute the already-published validation assignment after observable recovery.

Old raw freezes are not available: never fabricate one. Pin current actual bytes,
re-establish probe-on/off full-run parity, and retain the frozen descriptor and N.
This is a diagnostic continuation/reproduction, not final corrected P9 evidence.
"""
from pathlib import Path
import importlib.util
import json
import sys

R = Path(__file__).resolve().parent
sys.path.insert(0, str(R/'study'))
import study
import run_causal
module_spec = importlib.util.spec_from_file_location('assigned', R/'study/run_replication_original.py')
assigned = importlib.util.module_from_spec(module_spec)
module_spec.loader.exec_module(assigned)

if len(sys.argv) != 2:
    raise SystemExit('usage: run_recovered.py smoke|replication')
mode = sys.argv[1]
if mode == 'smoke':
    study.batch('causal_smoke', run_causal.panel(1,43000100,True), workers=4, timeout=240)
elif mode == 'replication':
    parity = json.loads((R/'study/studies/causal_smoke/PARITY.json').read_text())
    assert parity['equal_pairs'] == 18 and parity['all_complete']
    model = R/'replication/FROZEN-DESCRIPTOR.json'
    assert study.sha(model) == '2cfe1d8ff00d5ff695664c597be3a93e3960f39732fa049eac82b9397184bab7'
    specs = assigned.panel()
    assert len(specs) == 64 and sum(s['runs'] for s in specs) == 1024
    now = study.bound_observer(specs)
    pin = R/'RECOVERED_OBSERVER.json'
    if pin.exists():
        assert json.loads(pin.read_text()) == now
    else:
        study.write(pin, now)
    study.batch('causal_replication', specs, workers=4, timeout=1200)
else:
    raise SystemExit('unknown mode')
