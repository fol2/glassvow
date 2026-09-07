"""Fresh exploratory comparison; old 2501xxxx outcomes are not replayed as new."""
from pathlib import Path
import json, sys
from study_bound import batch, ROOT


def specs(n, seed):
    old = json.loads((ROOT / 'fuel_content/manifest.json').read_text())
    new = json.loads((ROOT / 'capped_content/manifest.json').read_text())
    recipes = {k: v for k, v in old.items() if k.endswith('demand3')}
    recipes.update(new)
    return [
        {'id': f'{label}-{route}-v{vow}', 'content_path': row['path'],
         'aspect': 1, 'vow': vow, 'route': route,
         'random_build': route == 'balanced', 'random_play': False,
         'runs': n, 'seed0': seed,
         'params': {'bank_mode': 'current-plus-next', 'native_rollout': True,
                    'rollout_samples': 2, 'rollout_steps': 12,
                    'leaf_terminal': False, 'banklight_fit': 12}}
        for label, row in recipes.items() for vow in (0, 5)
        for route in ('smolder', 'hand', 'ember', 'balanced')
    ]


if __name__ == '__main__':
    if sys.argv[1] == 'smoke':
        batch('capped_smoke', specs(1, 26000100), workers=4, timeout=180)
    elif sys.argv[1] == 'screen':
        batch('capped_screen', specs(32, 26010000), workers=4, timeout=1200)
    else:
        raise SystemExit('use smoke or screen')
