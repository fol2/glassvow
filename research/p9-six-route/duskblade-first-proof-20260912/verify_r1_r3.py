"""Reproduce complete R1-R3 author evidence, standard library, synthetic only."""
from __future__ import annotations

import argparse
import ast
import hashlib
import io
import json
from pathlib import Path
import platform
import re
import sys
import time
import unittest

HERE = Path(__file__).resolve().parent
FROZEN = {'reference_kernel.py': 'ee091fb503849117358b3691264fca71803f8bbc',
          'ALLOCATION.json': '824ff18acbca2f776533beed83a43b21d9a50f2c',
          'primitive_reduction.py': '46828c418d3b542bbca356f9c1804dd328cc5910'}


def blob(raw):
    return hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest()


def pins():
    return {p.name: {'git_blob': blob(p.read_bytes()), 'bytes': p.stat().st_size}
            for p in sorted(HERE.iterdir()) if p.suffix == '.py' or p.name == 'ALLOCATION.json'}


def pack(value):
    if isinstance(value, dict):
        return {k: pack(v) for k, v in value.items()}
    if isinstance(value, list):
        if len(value) > 20 and all(v is None or type(v) in (bool, int, float, str) for v in value):
            runs = []
            for item in value:
                if runs and type(runs[-1][0]) is type(item) and runs[-1][0] == item:
                    runs[-1][1] += 1
                else:
                    runs.append([item, 1])
            return {'$rle': runs}
        return [pack(v) for v in value]
    return value


def unpack(value):
    if isinstance(value, dict):
        if set(value) == {'$rle'}:
            return [v for v, n in value['$rle'] for _ in range(n)]
        return {k: unpack(v) for k, v in value.items()}
    return [unpack(v) for v in value] if isinstance(value, list) else value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--code-head', required=True, help='Exact GitHub head containing these source bytes')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--export-fixture', type=Path, help='Optional directory for complete expanded synthetic input bytes')
    args = parser.parse_args()
    if not re.fullmatch('[0-9a-f]{40}', args.code_head):
        parser.error('--code-head must be a full SHA')
    args.output.mkdir(parents=True, exist_ok=True)
    before = pins()
    for name, sha in FROZEN.items():
        assert before[name]['git_blob'] == sha, name
    for name in before:
        if name.endswith('.py'):
            source = (HERE / name).read_text()
            tree = ast.parse(source, filename=name)
            compile(source, name, 'exec')
            for node in ast.walk(tree):
                if isinstance(node, ast.ImportFrom):
                    assert not (node.module or '').startswith('historical_'), 'historical import'
                elif isinstance(node, ast.Import):
                    assert all(not alias.name.startswith('historical_') for alias in node.names), 'historical import'
    import prospective_admission as admission
    import synthetic_records as fixtures
    import synthetic_controls as controls
    import reference_kernel as kernel
    from evidence_boundary import canonical, digest
    controls.RESULTS.clear()
    log = io.StringIO()
    print('SYNTHETIC AUTHOR CHECKS ONLY; no native calls, binding or independent approval', file=log)
    print('code_head=' + args.code_head, file=log)
    print('python=' + platform.python_version(), file=log)
    start = time.monotonic()
    suite = unittest.defaultTestLoader.loadTestsFromNames(['test_prospective_admission', 'test_primitive_reduction'])
    result = unittest.TextTestRunner(stream=log, verbosity=2).run(suite)
    reference = unittest.TextTestRunner(stream=log, verbosity=2).run(
        unittest.defaultTestLoader.loadTestsFromTestCase(kernel.DesignTests))
    packet, context = fixtures.good_bundle()
    positive = admission.evaluate_packet(packet, context)
    assert result.wasSuccessful() and reference.wasSuccessful(), log.getvalue()
    assert len(positive['rows']) == 204 and len(positive['predicates']) == 152
    assert positive['statistical'] == 'PASS' and not positive['certificate']
    assert positive['root_checks']['paired_overlap'] == 0
    assert pins() == before, 'source changed during verification'
    packed = pack(positive)
    assert unpack(packed) == positive, 'lossless result encoding'
    keys = sorted(positive['predicates'])
    codes = {'PASS': 'P', 'FAIL': 'F', 'INCONCLUSIVE': 'I'}
    probes = []
    for recorded in controls.RESULTS:
        item = dict(recorded); decisions = item.pop('predicates')
        assert not decisions or sorted(decisions) == keys
        item['decision_vector'] = ''.join(codes[decisions[k]] for k in keys) if decisions else ''
        decoded = {k: {v: q for q, v in codes.items()}[ch] for k, ch in zip(keys, item['decision_vector'])}
        assert decoded == decisions
        probes.append(item)
    inputs = {'packet': packet, 'expected_identities': context.expected_identities,
              'expected_allocation': context.expected_allocation,
              'receipts': {name: raw.decode() for name, raw in context.receipts.items()},
              'store': {loc: {'bytes': len(raw), 'sha256': digest(raw)} for loc, raw in sorted(context.store.items())}}
    if args.export_fixture:
        args.export_fixture.mkdir(parents=True, exist_ok=True)
        for raw in context.store.values():
            (args.export_fixture / (digest(raw) + '.txt')).write_bytes(raw)
        (args.export_fixture / 'INPUTS.json').write_bytes(canonical(inputs) + b'\n')
    artifacts = {'AUTHOR-R1-R3-POSITIVE.json': packed,
                 'AUTHOR-R1-R3-PROBES.json': {'predicate_keys': keys, 'codes': codes,
                     'note': 'guard-deleted cases intentionally replace guards; they are negative controls of the test suite, not production accepts',
                     'records': probes}, 'AUTHOR-R1-R3-INPUTS.json': inputs}
    hashes = {}
    for name, value in artifacts.items():
        raw = canonical(value) + b'\n'
        (args.output / name).write_bytes(raw)
        hashes[name] = {'git_blob': blob(raw), 'sha256': digest(raw), 'bytes': len(raw)}
    print('SOURCE_BLOBS_UNCHANGED; 204 counts; 152 PASS; paired-overlap=0; real allocation remains zero', file=log)
    stdout = log.getvalue().encode()
    (args.output / 'AUTHOR-R1-R3-STDOUT.txt').write_bytes(stdout)
    hashes['AUTHOR-R1-R3-STDOUT.txt'] = {'git_blob': blob(stdout), 'sha256': digest(stdout), 'bytes': len(stdout)}
    report = {'status': 'AUTHOR_TESTS_PASS_REVIEW_PENDING', 'code_head': args.code_head,
              'python': platform.python_version(), 'seconds': round(time.monotonic()-start, 3),
              'entry_and_primitive_test_methods': result.testsRun, 'reference_test_methods': reference.testsRun,
              'nested_reference_methods_in_entry_suite': 16, 'probe_records': len(probes),
              'failures': len(result.failures)+len(reference.failures), 'errors': len(result.errors)+len(reference.errors),
              'source_unchanged': True, 'sources': before, 'artifacts': hashes,
              'synthetic_store_bytes': sum(len(raw) for raw in context.store.values()),
              'actual_native_calls': 0, 'actual_game_outcomes': 0, 'actual_binding': None,
              'independent_review': None, 'actual_allocation_blob': FROZEN['ALLOCATION.json'],
              'command': f'python verify_r1_r3.py --code-head {args.code_head} --output <evidence-directory>'}
    (args.output / 'AUTHOR-R1-R3-RUN.json').write_bytes(canonical(report) + b'\n')
    print(log.getvalue(), end='')
    print(json.dumps({k: v for k, v in report.items() if k not in ('sources', 'artifacts')}, sort_keys=True))


if __name__ == '__main__':
    main()
