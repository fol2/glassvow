"""Execute the published producer/consumer protocol after verified price evidence.

Copy into the prepared components workspace alongside study.py and content/.
No parameter adaptation or protected acceptance cohort is performed here.
"""
from pathlib import Path
import json
import sys
import study
R = Path(__file__).resolve().parent


def panel(n, seed):
    specs = []
    for label, entry in json.loads((R/'content/manifest.json').read_text()).items():
        assert study.sha(entry['path']) == entry['sha256']
        for vow in (0, 5):
            for route in ('smolder', 'hand', 'ember', 'balanced'):
                specs.append({
                    'id': f'{label}-a1-{route}-v{vow}',
                    'content_path': entry['path'], 'aspect': 1, 'vow': vow,
                    'route': route, 'random_build': route == 'balanced',
                    'random_play': False, 'runs': n, 'seed0': seed,
                    'params': {'bank_mode': 'current-plus-next',
                               'native_rollout': True, 'rollout_samples': 2,
                               'rollout_steps': 12, 'leaf_terminal': False}})
    return specs


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: run_components.py smoke|screen')
    mode = sys.argv[1]
    if mode == 'smoke':
        study.batch('specificity_smoke', panel(1, 35000100), workers=4, timeout=180)
    elif mode == 'screen':
        parity = json.loads((R/'studies/specificity_smoke/PARITY.json').read_text())
        assert parity['equal_pairs'] == 8
        study.batch('specificity_screen', panel(16, 36010000), workers=4, timeout=900)
    else:
        raise SystemExit('unknown mode')
