"""Synthetic boundary tests for the unchanged support decision, not observations."""
from __future__ import annotations
import copy
import importlib
import os
import unittest
from cohort import policies, SEEDS

reader = importlib.import_module(os.environ.get('P9_READER_MODULE', 'read_support'))


def fixture(active=32, inactive=32):
    result = []
    for i, policy in enumerate(policies()):
        is_active = i < active
        positive = is_active or i >= active + inactive
        result.append({
            'policy_id': policy['policy_id'], 'policy_index': i, 'vow': 5,
            'runs': [{'seed': seed, 'result': 'win',
                      'historical_chain_active': is_active,
                      'positive_high_payoff': positive,
                      'final_pair': is_active, 'consumer_reached': positive,
                      'decision_trace_sha256': f'synthetic:{i}:{seed}'}
                     for seed in SEEDS]})
    return result


class TerminalReview(unittest.TestCase):
    def test_all_minima_pass_only_necessary_gate(self):
        r = reader.summarize(fixture())
        self.assertEqual(len(r['active']), 32)
        self.assertEqual(len(r['inactive']), 32)
        self.assertEqual(len(r['ambiguous']), 64)
        self.assertTrue(all(r['gates'].values()))
        self.assertEqual(r['packages_admitted'], 0)
        self.assertFalse(r['p9_certified'])

    def test_31_active_is_failure_even_with_every_win(self):
        r = reader.summarize(fixture(active=31))
        self.assertEqual(r['outcomes']['win'], 512)
        self.assertFalse(r['gates']['active'])
        self.assertEqual(r['status'], 'HAND_NATURAL_SUPPORT_GATE_FAIL_IN_FIXED_POLICY_FAMILY')

    def test_31_inactive_is_failure(self):
        r = reader.summarize(fixture(inactive=31))
        self.assertFalse(r['gates']['inactive'])

    def test_all_positive_other_supplier_is_ambiguous_not_inactive(self):
        r = reader.summarize(fixture(active=0, inactive=0))
        self.assertEqual(r['inactive'], [])
        self.assertEqual(len(r['ambiguous']), 128)

    def test_one_active_seed_counts_one_policy_not_four(self):
        cells = fixture()
        for cell in cells[:32]:
            for row in cell['runs'][:3]:
                row['historical_chain_active'] = False
        self.assertEqual(len(reader.summarize(cells)['active']), 32)

    def test_any_late_positive_prevents_inactive(self):
        cells = fixture()
        cells[32]['runs'][-1]['positive_high_payoff'] = True
        r = reader.summarize(cells)
        self.assertEqual(len(r['inactive']), 31)
        self.assertIn(32, r['ambiguous'])
        self.assertFalse(r['gates']['inactive'])

    def test_missing_policy_rejected(self):
        with self.assertRaises(ValueError):
            reader.summarize(fixture()[:-1])

    def test_duplicate_policy_id_rejected(self):
        cells = fixture()
        cells[-1]['policy_id'] = cells[0]['policy_id']
        with self.assertRaises(ValueError):
            reader.summarize(cells)

    def test_seed_replacement_rejected(self):
        cells = fixture()
        cells[0]['runs'][-1]['seed'] += 1
        with self.assertRaises(ValueError):
            reader.summarize(cells)

    def test_stall_and_error_fail_closed(self):
        for outcome in ('stall', 'error'):
            with self.subTest(outcome=outcome):
                cells = fixture()
                cells[-1]['runs'][-1]['result'] = outcome
                r = reader.summarize(cells)
                self.assertFalse(r['gates']['fault_free'])
                self.assertEqual(r['status'], 'HAND_NATURAL_SUPPORT_GATE_FAIL_IN_FIXED_POLICY_FAMILY')

    def test_mixed_vow_rejected(self):
        cells = fixture()
        cells[-1]['vow'] = 0
        with self.assertRaises(ValueError):
            reader.summarize(cells)

    def test_trajectory_aliases_reported_without_fake_replication(self):
        cells = fixture()
        for cell in cells:
            for row in cell['runs']:
                row['decision_trace_sha256'] = 'same-factual-action-sequence'
        r = reader.summarize(cells)
        self.assertEqual(r['trajectory_classes'], 1)
        self.assertEqual(r['packages_admitted'], 0)


if __name__ == '__main__':
    unittest.main()
