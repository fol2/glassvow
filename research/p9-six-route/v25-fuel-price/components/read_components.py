"""Reconcile native component outcomes; no package or P9 admission is implied."""
from pathlib import Path
import copy
import importlib.util
import json
import sys
import numpy as np


def auditor(path):
    spec = importlib.util.spec_from_file_location('component_raw_auditor', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def strip_added_counters(row):
    result = copy.deepcopy(row)
    for record in [result] + result.get('fights', []):
        counts = record.get('mechanism', {})
        for key in list(counts):
            if key == 'nova_fuel_paid' or key.startswith('nova_stock_hist:'):
                del counts[key]
    return result


def verify_parity(component_folder, price_folder, audit_path):
    checker = auditor(audit_path)
    component_folder, price_folder = Path(component_folder), Path(price_folder)
    component_audit, component_rows = checker.audit(component_folder)
    price_audit, price_rows = checker.audit(price_folder)
    cf = json.loads((component_folder/'freeze.json').read_text())
    pf = json.loads((price_folder/'freeze.json').read_text())
    cs, ps = cf['observer']['sources'], pf['observer']['sources']
    if set(cs) != set(ps):
        raise ValueError('Observer file set changed')
    changed = sorted(key for key in cs if cs[key] != ps[key])
    if changed != ['lab_runner.gd']:
        raise ValueError(('Unexpected observer change', changed))
    pairs = []
    for vow in (0, 5):
        for route in ('smolder', 'hand', 'ember', 'balanced'):
            ck = f'p1c1-a1-{route}-v{vow}'
            pk = f'production2_energy0-a1-{route}-v{vow}'
            if [strip_added_counters(row) for row in component_rows[ck]] != price_rows[pk]:
                raise ValueError(('Baseline parity mismatch', ck, pk))
            pairs.append({'component': ck, 'price': pk, 'rows': len(component_rows[ck])})
    report = {'status': 'OBSERVATION_ONLY_BASELINE_PARITY', 'equal_pairs': len(pairs),
              'component_audited_rows': component_audit['rows'],
              'price_audited_rows': price_audit['rows'],
              'component_freeze': component_audit['freeze_sha256'],
              'price_freeze': price_audit['freeze_sha256'],
              'observer_changed_files': changed, 'pairs': pairs,
              'scope': 'Exposed smoke parity, not independent quality evidence.'}
    (component_folder/'PARITY.json').write_text(json.dumps(report, indent=2)+'\n')
    return report


def effect(vector, rng):
    values = np.asarray(vector, dtype=float)
    if values.ndim != 1 or not len(values):
        raise ValueError('One contrast per assigned seed cluster required')
    means = values[rng.integers(0, len(values), size=(10000, len(values)))].mean(axis=1)
    return {'estimate': float(values.mean()), 'seed_clusters': len(values),
            'nominal_cluster_bootstrap95': np.quantile(means, [.025, .975]).tolist(),
            'nonzero_clusters': int(np.count_nonzero(values))}


def read(folder, audit_path):
    folder = Path(folder)
    checker = auditor(audit_path)
    audit, raw = checker.audit(folder)
    freeze = json.loads((folder/'freeze.json').read_text())
    specs = {spec['id']: spec for spec in freeze['specs']}
    rng = np.random.default_rng(93071)
    cells, lookup = [], {}
    expected_seeds = None
    for cell in audit['cells']:
        spec = specs[cell['id']]
        arm = cell['id'].split('-')[0]
        key = arm, spec['vow'], spec['route']
        if key in lookup or arm not in ('p0c0', 'p0c1', 'p1c0', 'p1c1'):
            raise ValueError(('Duplicate/unknown factorial cell', key))
        seeds = [row['seed'] for row in raw[cell['id']]]
        if expected_seeds is not None and seeds != expected_seeds:
            raise ValueError('Assigned seed clusters differ')
        expected_seeds = seeds
        lookup[key] = np.array([row['result'] == 'win' for row in raw[cell['id']]], dtype=int)
        counts = cell['mechanism_total']
        fuel = counts.get('nova_fuel_paid', 0)
        histogram = {key.split(':', 1)[1]: value for key, value in counts.items() if key.startswith('nova_stock_hist:')}
        if sum(histogram.values()) != counts.get('nova_casts', 0):
            raise ValueError(('Incomplete Nova stock histogram', key))
        if fuel != sum(min(int(stock), 2)*count for stock, count in histogram.items()):
            raise ValueError(('Fuel/stock conservation failed', key))
        cells.append({'arm': arm, 'vow': spec['vow'], 'route': spec['route'],
                      'random_build': spec['random_build'], 'nova_fuel_paid': fuel,
                      'nova_stock_histogram': histogram, **cell})
    vectors, contrasts = {}, []
    for vow in (0, 5):
        for route in ('smolder', 'hand', 'ember', 'balanced'):
            y00, y01, y10, y11 = [lookup[arm, vow, route] for arm in ('p0c0', 'p0c1', 'p1c0', 'p1c1')]
            terms = {'producer_with_consumer': y11-y01, 'consumer_with_producer': y11-y10,
                     'producer_without_consumer': y10-y00, 'consumer_without_producer': y01-y00,
                     'interaction': y11-y10-y01+y00}
            for name, vector in terms.items():
                vectors[vow, route, name] = vector
                contrasts.append({'vow': vow, 'route': route, 'contrast': name, **effect(vector, rng)})
    specificity = []
    for vow in (0, 5):
        for name in ('producer_with_consumer', 'consumer_with_producer', 'interaction'):
            target = vectors[vow, 'ember', name]
            other = (vectors[vow, 'smolder', name] + vectors[vow, 'hand', name])/2
            random = vectors[vow, 'balanced', name]
            specificity.append({'vow': vow, 'contrast': name,
                                'ember_minus_other_planned': effect(target-other, rng),
                                'ember_minus_random': effect(target-random, rng)})
    ledger = []
    for cell in cells:
        key = cell['id']
        receipt = json.loads((folder/(key+'.receipt.json')).read_text())
        ledger.append({'id': key, 'content_sha256': receipt['content_sha256'],
                       'seed0': expected_seeds[0], 'n': len(expected_seeds),
                       'outcomes': ''.join({'win': 'W', 'loss': 'L', 'stall': 'S', 'error': 'E'}[row['result']] for row in raw[key]),
                       'raw_sha256': receipt['output_sha256'],
                       'receipt_sha256': checker.sha(folder/(key+'.receipt.json'))})
    report = {'status': 'RAW_RECONCILED_EXPLORATION_NOT_P9', 'rows': audit['rows'],
              'counts': audit['counts'], 'freeze_sha256': audit['freeze_sha256'],
              'cells': cells, 'contrasts': contrasts, 'specificity': specificity,
              'reduced_outcome_ledger': ledger,
              'limitations': ['Shared assigned seeds, not independent rows or identical downstream RNG.',
                             'Removal includes policy responses; one producer null does not remove all fuel.',
                             'Nominal exploration, not multiplicity/selection-corrected confirmation.',
                             'Zero bootstrap width is not proof of population zero effect.',
                             'Health-source shares are descriptive, not isolated causal attribution.',
                             'No signed C2, six-package admission, detector, retention or integration PASS.']}
    (folder/'readout.json').write_text(json.dumps(report, indent=2)+'\n')
    return report


if __name__ == '__main__':
    if len(sys.argv) == 5 and sys.argv[1] == 'parity':
        print(verify_parity(sys.argv[2], sys.argv[3], sys.argv[4]))
    elif len(sys.argv) == 4 and sys.argv[1] == 'read':
        report = read(sys.argv[2], sys.argv[3])
        print(report['status'], report['rows'], report['counts'])
        for cell in report['cells']:
            print(cell['id'], cell['wins'], cell['n'])
        for contrast in report['contrasts']:
            if contrast['route'] == 'ember':
                print('EMBER', contrast['vow'], contrast['contrast'], contrast['estimate'], contrast['nominal_cluster_bootstrap95'])
    else:
        raise SystemExit('parity COMPONENT_SMOKE PRICE_SMOKE AUDITOR | read STUDY AUDITOR')
