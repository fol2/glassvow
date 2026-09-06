"""Independent raw-row reconciliation for one native exploratory stage."""
import collections
import hashlib
import json
import sys
from pathlib import Path


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify(folder):
    folder = Path(folder)
    freeze = json.loads((folder / 'freeze.json').read_text())
    all_rows = 0
    result = []
    for spec in freeze['specs']:
        key = spec['id']
        receipt = json.loads((folder / (key + '.receipt.json')).read_text())
        out = folder / (key + '.ndjson')
        log = folder / (key + '.log')
        cfg = folder / (key + '.config.json')
        if not receipt['complete'] or receipt['exit_code'] != 0:
            raise ValueError((key, 'incomplete execution'))
        if digest(out) != receipt['output_sha256'] or digest(log) != receipt['log_sha256']:
            raise ValueError((key, 'capture hash mismatch'))
        if digest(cfg) != receipt['identity']['config'] or json.loads(cfg.read_text()) != spec:
            raise ValueError((key, 'configuration mismatch'))
        objects = [json.loads(line) for line in out.read_text().splitlines()]
        manifest, rows = objects[0], objects[1:]
        expected_seeds = list(range(spec['seed0'], spec['seed0'] + spec['runs']))
        if manifest['kind'] != 'manifest' or any(row['kind'] != 'row' for row in rows):
            raise ValueError((key, 'record type mismatch'))
        if len(rows) != spec['runs'] or [row['seed'] for row in rows] != expected_seeds:
            raise ValueError((key, 'assigned cohort mismatch'))
        bindings = {
            'content_sha256': receipt['identity']['content'],
            'policy_sha256': freeze['observer']['files']['lab_policy.gd'],
            'driver_sha256': freeze['observer']['files']['lab_runner.gd'],
        }
        if any(manifest[name] != value for name, value in bindings.items()):
            raise ValueError((key, 'manifest binding mismatch'))
        for row in rows:
            if row['result'] not in ('win', 'loss', 'stall', 'error'):
                raise ValueError((key, 'unknown outcome'))
            if any(row[name] != spec[name] for name in ('aspect', 'vow', 'route')):
                raise ValueError((key, 'row identity mismatch'))
            if row['result'] == 'win' and not (row['act'] == 3 and row['hp'] > 0):
                raise ValueError((key, 'invalid whole-run win'))
            if not row['fights']:
                raise ValueError((key, 'missing combat history'))
        counts = collections.Counter(row['result'] for row in rows)
        if receipt['summary']['wins'] != counts['win'] or receipt['summary']['n'] != len(rows):
            raise ValueError((key, 'summary mismatch'))
        if any('ERROR' in line or line.startswith(('LAB_', 'Error:')) for line in log.read_text().splitlines()):
            raise ValueError((key, 'native diagnostic'))
        all_rows += len(rows)
        result.append({'id': key, 'n': len(rows), 'outcomes': dict(counts),
                       'freeze_sha256': digest(folder / 'freeze.json'),
                       'output_sha256': digest(out)})
    totals = sum((collections.Counter(row['outcomes']) for row in result), collections.Counter())
    return {'status': 'RAW_STUDY_RECONCILED_NOT_P9', 'cells': len(result),
            'rows': all_rows, 'all_counts': dict(totals), 'records': result}


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: verify_study.py STUDY_DIRECTORY')
    path = Path(sys.argv[1])
    report = verify(path)
    (path / 'verification.json').write_text(json.dumps(report, indent=2) + '\n')
    print({key: value for key, value in report.items() if key != 'records'})
