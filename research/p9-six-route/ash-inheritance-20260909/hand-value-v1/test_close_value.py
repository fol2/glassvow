"""Synthetic regression tests for post-run closure; no game or real outcomes."""
import copy
import json
from pathlib import Path
import tempfile
import unittest

import close_value as c


def rows(vow=5):
    result = {w: [] for w in c.WORLDS}
    for first in range(0, 128, 2):
        for index in (first, first + 1):
            for j in range(4):
                seed = 73620100 + 1000 * vow + 4 * (first // 2) + j
                pattern = f'{index % 16:04b}'
                for world, bit in zip(c.WORLDS, pattern):
                    result[world].append({'index': index, 'seed': seed, 'vow': vow,
                                          'policy': {'id': index},
                                          'row': {'outcome': 'win' if bit == '1' else 'loss'}})
    return result


def stage_fixture(positive=False):
    point = 1. if positive else 0.
    pattern = '0001' if positive else '0000'
    counts = {'wins': {w: 512 if (positive and w == '11') else 0 for w in c.WORLDS},
              'contrasts': {n: point for n in c.CONTRASTS},
              'outcome_patterns_00_01_10_11': {pattern: 512}}
    actual = {'wins': counts['wins'], 'outcome_patterns_00_01_10_11': counts['outcome_patterns_00_01_10_11'],
              'contrasts': {n: {'point': point, 'interval': [.5, 1.] if positive else [0., 0.],
                                'positive_lower_bound': positive} for n in c.CONTRASTS},
              'primary_pass': positive}
    costs = {w: 1000. for w in c.WORLDS}
    saved = copy.deepcopy(actual)
    saved.update(resource_pass=True, pass_all=positive, cpu_seconds=costs, secondary={'descriptive': True})
    terminal_stage = {k: v for k, v in saved.items() if k != 'secondary'}
    return actual, saved, terminal_stage, counts, costs


def terminal(stages):
    positive = list(stages) == ['5', '0'] and all(s['pass_all'] for s in stages.values())
    result = {'status': c.SUPPORTED if positive else c.NEGATIVE, 'stages': copy.deepcopy(stages),
              'packages_admitted': 0, 'p9_certified': False,
              'qualification': {'status': 'HAND_WORLD_ENTRY_BINDING_PASS'}}
    if not positive:
        result.update(last_vow=int(list(stages)[-1]), v0_skipped='0' not in stages)
    return result


def capture(root):
    t = terminal({'5': {'pass_all': False}})
    c.save(root / 'TERMINAL.json', t)
    (root / 'raw.xz').write_bytes(b'not-real-game-data')
    records = [{'path': n, 'bytes': (root / n).stat().st_size,
                'sha256': c.sha((root / n).read_bytes())} for n in ('TERMINAL.json', 'raw.xz')]
    c.save(root / 'FILES.json', records)
    p = {'kind': 'COMPLETE_HAND_ADAPTIVE_VALUE_COLD_READBACK', 'all_bytes_equal': True,
         'scientific_status': t['status'], 'reproduced_stages': ['5'], 'files': len(records) + 1}
    c.save(root / 'REMOTE-READBACK.json', p)
    return t, p, records


class ArithmeticTests(unittest.TestCase):
    def test_complete_all_pattern_rectangle(self):
        result = c.independent_counts(rows(), 5)
        self.assertEqual(result['wins'], {w: 256 for w in c.WORLDS})
        self.assertEqual(result['contrasts'], {n: 0. for n in c.CONTRASTS})
        self.assertEqual(result['outcome_patterns_00_01_10_11'], {f'{i:04b}': 32 for i in range(16)})
        self.assertEqual(result['matched_seed_blocks'], 256)

    def test_v0_uses_its_own_assignment(self):
        self.assertEqual(c.independent_counts(rows(0), 0)['rows_per_world'], 512)
        with self.assertRaisesRegex(ValueError, 'ROW_IDENTITY'):
            c.independent_counts(rows(5), 0)

    def test_duplicate_and_missing_matched_row_rejected(self):
        data = rows(); data['11'][-1] = data['11'][0]
        with self.assertRaisesRegex(ValueError, 'DUPLICATE_ROW'):
            c.independent_counts(data, 5)

    def test_wrong_seed_rejected_even_with_512_rows(self):
        data = rows(); data['01'][0]['seed'] += 500
        with self.assertRaisesRegex(ValueError, 'INVALID_ASSIGNED_OUTCOME'):
            c.independent_counts(data, 5)

    def test_float_identity_not_silently_coerced(self):
        data = rows(); data['00'][0]['index'] = 0.0
        with self.assertRaisesRegex(ValueError, 'ROW_IDENTITY'):
            c.independent_counts(data, 5)

    def test_policy_drift_and_duplicate_policies_rejected(self):
        data = rows(); data['10'][0]['policy'] = {'id': 9999}
        with self.assertRaisesRegex(ValueError, 'WITHIN_CONFIG_POLICY_DRIFT'):
            c.independent_counts(data, 5)
        data = rows()
        for world in c.WORLDS:
            for row in data[world]:
                row['policy'] = {'same': True}
        with self.assertRaisesRegex(ValueError, 'POLICY_RECTANGLE'):
            c.independent_counts(data, 5)

    def test_cross_world_consistent_but_changed_policy_rejected(self):
        data = rows()
        for row in data['10']:
            row['policy'] = {'id': row['index'], 'altered': True}
        with self.assertRaisesRegex(ValueError, 'CROSS_WORLD_POLICY_DRIFT'):
            c.independent_counts(data, 5)

    def test_errors_are_not_losses(self):
        data = rows(); data['11'][0]['row']['error'] = 'stall'
        with self.assertRaisesRegex(ValueError, 'INVALID_ASSIGNED_OUTCOME'):
            c.independent_counts(data, 5)


class GateTests(unittest.TestCase):
    def test_exact_resource_boundary(self):
        args = list(stage_fixture()); args[4]['00'] = 3600.
        args[1]['cpu_seconds'] = args[4]; args[2]['cpu_seconds'] = args[4]
        self.assertFalse(c.stage_check(*args)['pass_all'])
        args[4]['00'] += 1e-9
        with self.assertRaisesRegex(ValueError, 'RESOURCE_CONJUNCTION'):
            c.stage_check(*args)

    def test_nan_or_negative_resource_rejected(self):
        for bad in (float('nan'), -1., True):
            args = list(stage_fixture()); args[4]['00'] = bad
            with self.assertRaisesRegex(ValueError, 'RESOURCE_CONJUNCTION'):
                c.stage_check(*args)

    def test_zero_lower_bound_is_not_positive(self):
        args = stage_fixture()
        self.assertFalse(c.stage_check(*args)['primary_pass'])
        args[0]['contrasts']['consumer']['positive_lower_bound'] = True
        args[1]['contrasts']['consumer']['positive_lower_bound'] = True
        with self.assertRaisesRegex(ValueError, 'CONTRAST_DECISION'):
            c.stage_check(*args)

    def test_primary_source_result_mismatch_rejected(self):
        args = stage_fixture(); args[1]['wins']['11'] = 1
        with self.assertRaisesRegex(ValueError, 'WIN_RECONCILIATION'):
            c.stage_check(*args)

    def test_nonprimary_support_cannot_rescue_negative(self):
        args = stage_fixture(); args[1]['secondary'] = {'support_pass': True, 'active': 128}
        self.assertFalse(c.stage_check(*args)['pass_all'])
        args[1]['pass_all'] = True
        with self.assertRaisesRegex(ValueError, 'STAGE_CONJUNCTION'):
            c.stage_check(*args)

    def test_v5_negative_closes_without_v0(self):
        stages = {'5': {'pass_all': False}}
        self.assertEqual(c.terminal_check(terminal(stages), stages, False), c.NEGATIVE)
        with self.assertRaisesRegex(ValueError, 'MISSING_OR_UNAUTHORISED_V0'):
            c.terminal_check(terminal(stages), stages, True)

    def test_v0_cannot_follow_negative_v5(self):
        stages = {'5': {'pass_all': False}, '0': {'pass_all': True}}
        with self.assertRaisesRegex(ValueError, 'PREMATURE_V0'):
            c.terminal_check(terminal(stages), stages, True)

    def test_positive_v5_alone_is_not_finished(self):
        stages = {'5': {'pass_all': True}}
        with self.assertRaisesRegex(ValueError, 'MISSING_OR_UNAUTHORISED_V0'):
            c.terminal_check(terminal(stages), stages, False)

    def test_v0_negative_is_retained(self):
        stages = {'5': {'pass_all': True}, '0': {'pass_all': False}}
        self.assertEqual(c.terminal_check(terminal(stages), stages, True), c.NEGATIVE)

    def test_both_supported_still_no_certificate(self):
        stages = {'5': {'pass_all': True}, '0': {'pass_all': True}}
        t = terminal(stages)
        self.assertEqual(c.terminal_check(t, stages, True), c.SUPPORTED)
        t['packages_admitted'] = 1
        with self.assertRaisesRegex(ValueError, 'FALSE_ADMISSION'):
            c.terminal_check(t, stages, True)

    def test_failure_cannot_be_hidden_by_terminal_colour(self):
        stages = {'5': {'pass_all': False}}; t = terminal(stages)
        t['failure'] = 'incomplete raw'
        with self.assertRaisesRegex(ValueError, 'SCIENTIFIC_TERMINAL'):
            c.terminal_check(t, stages, False)


class CaptureTests(unittest.TestCase):
    def test_complete_manifest_and_readback(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d); expected = capture(root)
            self.assertEqual(c.capture_check(root), expected)

    def test_extra_unmanifested_file_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d); capture(root); (root / 'unreported').write_text('x')
            with self.assertRaisesRegex(ValueError, 'FULL_CAPTURE_COVERAGE'):
                c.capture_check(root)

    def test_corrupt_or_missing_raw_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d); capture(root); (root / 'raw.xz').write_bytes(b'changed')
            with self.assertRaisesRegex(ValueError, 'CAPTURE_BYTES'):
                c.capture_check(root)
            (root / 'raw.xz').unlink()
            with self.assertRaisesRegex(ValueError, 'FULL_CAPTURE_COVERAGE'):
                c.capture_check(root)

    def test_no_readback_no_closure(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d); capture(root); (root / 'REMOTE-READBACK.json').unlink()
            with self.assertRaises(FileNotFoundError):
                c.capture_check(root)

    def test_readback_count_and_status_must_match(self):
        for key, value in [('files', 999), ('scientific_status', c.SUPPORTED), ('reproduced_stages', ['0'])]:
            with tempfile.TemporaryDirectory() as d:
                root = Path(d); _, p, _ = capture(root); p[key] = value
                c.save(root / 'REMOTE-READBACK.json', p)
                with self.assertRaisesRegex(ValueError, 'READBACK_'):
                    c.capture_check(root)

    def test_duplicate_manifest_path_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d); _, p, records = capture(root); records.append(records[0])
            p['files'] += 1; c.save(root / 'FILES.json', records); c.save(root / 'REMOTE-READBACK.json', p)
            with self.assertRaisesRegex(ValueError, 'DUPLICATE_MANIFEST_PATH'):
                c.capture_check(root)

    def test_unsafe_path_rejected(self):
        for value in ('../outside', '/etc/passwd', '', '.'):
            with self.assertRaisesRegex(ValueError, 'UNSAFE_PATH'):
                c.relative(value)


class PipelineTests(unittest.TestCase):
    def exercise(self, root, corrupt=False):
        from types import SimpleNamespace
        from unittest.mock import patch
        import sys
        data = rows()
        totals = c.independent_counts(data, 5)
        actual = {'wins': totals['wins'],
                  'outcome_patterns_00_01_10_11': totals['outcome_patterns_00_01_10_11'],
                  'contrasts': {n: {'point': 0., 'interval': [-.1, .1],
                                    'positive_lower_bound': False} for n in c.CONTRASTS},
                  'primary_pass': False}
        saved = copy.deepcopy(actual)
        saved.update(cpu_seconds={w: 64. for w in c.WORLDS}, pass_all=False,
                     resource_pass=True, secondary={})
        stage = {k: v for k, v in saved.items() if k != 'secondary'}
        t = terminal({'5': stage})
        capture_root = root / c.STUDY / 'execution-1'
        capture_root.mkdir(parents=True)
        _, p, records = capture(capture_root)
        c.save(capture_root / 'TERMINAL.json', t)
        c.save(capture_root / 'RESOLVED-PROTOCOLS.json', {w: {} for w in c.WORLDS})
        c.save(root / c.STUDY / 'CONTRACT.json', {})
        def config(first, vow):
            return {'root': 73409000, 'first': first, 'count': 2,
                    'seeds': list(range(73620100 + 1000*vow + 4*(first//2),
                                       73620100 + 1000*vow + 4*(first//2) + 4)),
                    'vow': vow, 'integration': False}
        for world in c.WORLDS:
            folder = capture_root / 'v5' / world; folder.mkdir(parents=True)
            for first in range(0, 128, 2):
                c.save(folder / (f'v5-{first:03d}.RECEIPT.json'),
                       {'status': 'COMPLETE', 'cfg': config(first, 5), 'rows': 8,
                        'cpu': {'user': 1., 'system': 0.}})
        if corrupt:
            saved['wins']['11'] += 1
        c.save(capture_root / 'v5/RESULTS.json', saved)
        def outcome_records(path, cfg, protocol):
            return [r for r in data[path.parent.name]
                    if cfg['first'] <= r['index'] < cfg['first'] + 2]
        value = SimpleNamespace(read_value=SimpleNamespace(validate_extra=lambda *args: None))
        reader = SimpleNamespace(outcome_records=outcome_records)
        runner = SimpleNamespace(validate_contract=lambda x: None,
                                 entry_result=lambda p: t['qualification'],
                                 dependencies=lambda repo: (None, value, None, reader))
        readout = SimpleNamespace(config=config, primary=lambda *args: actual)
        with patch.object(c, 'source_check', return_value={'fixture_only': True}), \
             patch.object(c, 'capture_check', return_value=(t, p, records)), \
             patch.object(c, 'git', return_value='synthetic-source-not-real-evidence'), \
             patch.dict(sys.modules, {'run_hand': runner, 'read_hand': readout}):
            return c.audit(root, root / c.STUDY / 'closure-1')

    def test_complete_pipeline_and_capsule_preserve_old_limits(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            result = self.exercise(root)
            self.assertEqual(result['status'], c.NEGATIVE)
            self.assertEqual(result['stages']['5']['wins']['11'], 256)
            state_path = root / c.ROOT / 'SESSION-STATE.json'
            c.save(state_path, {'historical_raw_gap': True, 'frozen_model': 'unchanged'})
            (root / c.ROOT / 'package-disposition-20260908').mkdir()
            c.sync(root, root / c.STUDY / 'closure-1')
            state = c.load(state_path)
            self.assertIs(state['historical_raw_gap'], True)
            self.assertEqual(state['frozen_model'], 'unchanged')
            self.assertEqual(state['packages_admitted'], 0)
            self.assertIn('without extension or rescue', state['exact_next_action'])
            self.assertIn(c.NEGATIVE, (root / c.ROOT / 'SESSION-HANDOFF.md').read_text())

    def test_invalid_pipeline_never_writes_a_decision(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with self.assertRaisesRegex(ValueError, 'WIN_RECONCILIATION'):
                self.exercise(root, corrupt=True)
            self.assertFalse((root / c.STUDY / 'closure-1').exists())


if __name__ == '__main__':
    unittest.main()
