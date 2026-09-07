"""Reconcile every assigned native row; describe the fixed price factorial.

No route label, selected maximum or exploratory interval is a P9 certificate.
This reader imports only the existing raw auditor, never the experiment runner.
"""
from pathlib import Path
import collections
import importlib.util
import json
import sys
import numpy as np


def load_auditor(path):
    spec = importlib.util.spec_from_file_location('raw_auditor', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def cluster_effect(values, rng, repetitions=10000):
    x = np.asarray(values, dtype=float)
    if x.ndim != 1 or not len(x):
        raise ValueError('Expected one contrast per assigned seed cluster')
    means = x[rng.integers(0, len(x), size=(repetitions, len(x)))].mean(axis=1)
    return {'seed_clusters': len(x), 'estimate': float(x.mean()),
            'nominal_seed_bootstrap95': np.quantile(means, [.025, .975]).tolist(),
            'nonzero_clusters': int(np.count_nonzero(x)),
            'warning': 'Exploratory; multiplicity/selection uncorrected; a degenerate empirical interval does not prove zero population effect.'}


def read(folder, audit_path):
    folder = Path(folder)
    auditor = load_auditor(audit_path)
    audit, raw = auditor.audit(folder)
    freeze = json.loads((folder / 'freeze.json').read_text())
    specs = {s['id']: s for s in freeze['specs']}
    by_key = {}
    cells = []
    for cell in audit['cells']:
        s = specs[cell['id']]
        label = Path(s['content_path']).stem
        production = int(label.split('_')[0].removeprefix('production'))
        energy = int(label.split('_')[1].removeprefix('energy'))
        key = (production, energy, s['aspect'], s['vow'], s['route'])
        if key in by_key:
            raise ValueError('Duplicate factorial cell')
        by_key[key] = (cell, raw[cell['id']])
        cells.append({'production': production, 'energy': energy, 'aspect': s['aspect'],
                      'vow': s['vow'], 'route': s['route'], 'random_build': s['random_build'],
                      **cell})
    rng = np.random.default_rng(872393)
    effects = []
    effect_vectors = {}
    for production in [1, 2]:
        for aspect, routes in [(0, ['facet','fervor','cycle','balanced']), (1, ['smolder','hand','ember','balanced'])]:
            for vow in [0, 5]:
                for route in routes:
                    key = production, aspect, vow, route
                    control, a = by_key[production, 1, aspect, vow, route]
                    treatment, b = by_key[production, 0, aspect, vow, route]
                    if [r['seed'] for r in a] != [r['seed'] for r in b]:
                        raise ValueError('Paired assigned seeds differ')
                    d = np.asarray([int(y['result']=='win') - int(x['result']=='win') for x,y in zip(a,b)])
                    effect_vectors[key] = d
                    effects.append({'production': production, 'aspect': aspect, 'vow': vow,
                                    'route': route, 'energy1_wins': control['wins'],
                                    'energy0_wins': treatment['wins'], 'n': len(a),
                                    'improved_pairs': int((d==1).sum()), 'worsened_pairs': int((d==-1).sum()),
                                    **cluster_effect(d, rng)})
    specificity = []
    for production in [1, 2]:
        for vow in [0, 5]:
            ember = effect_vectors[production,1,vow,'ember']
            others = (effect_vectors[production,1,vow,'smolder'] + effect_vectors[production,1,vow,'hand']) / 2.0
            random = effect_vectors[production,1,vow,'balanced']
            specificity.append({'production': production,'vow':vow,
                'ember_minus_other_planned_effect': cluster_effect(ember-others, rng),
                'ember_minus_random_effect': cluster_effect(ember-random, rng)})
    limits = [
        'Same numeric seed is a paired assignment, not identical downstream random events.',
        'The 32 seed clusters are shared across arms/routes, not 2048 independent seeds.',
        'Balanced rollout RandomBuild is not signed original arm2/C2.',
        'Health-source fractions are descriptive; no individual causal mediator attribution.',
        'Price changes cause policy responses; these are total effects, not fixed-action effects.',
        'No candidate promotion, package admission, detector, retention, integration or P9 PASS.'
    ]
    return {'status':'RAW_RECONCILED_EXPLORATION_NOT_P9','rows':audit['rows'],
            'counts':audit['counts'],'freeze_sha256':audit['freeze_sha256'],
            'cell_count':len(cells),'cells':cells,'price_effects':effects,
            'ash_specificity':specificity,'limitations':limits}


if __name__ == '__main__':
    if len(sys.argv)!=3:
        raise SystemExit('usage: read_price.py STUDY_FOLDER AUDIT_STUDY_PY')
    report = read(sys.argv[1], sys.argv[2])
    out = Path(sys.argv[1])/'readout.json'
    out.write_text(json.dumps(report,indent=2)+'\n')
    print(report['status'],report['rows'],report['counts'])
    for row in report['price_effects']:
        print('p',row['production'],'a',row['aspect'],'v',row['vow'],row['route'],
              f"{row['energy1_wins']} -> {row['energy0_wins']} / {row['n']}",
              'delta',round(row['estimate'],4))
