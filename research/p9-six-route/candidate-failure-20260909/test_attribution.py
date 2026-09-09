"""Synthetic/source checks only. No fabricated native evidence."""
from copy import deepcopy
import json
from pathlib import Path
import tempfile
import unittest
import attribution as a

class AttributionTests(unittest.TestCase):
    def cells(self):
        return {k: [dict(seed=s, aspect='ashwarden', vow=0, arm=2,
                     outcome='win' if i < n else 'loss', error=None)
                    for i, s in enumerate(a.SEEDS)]
                for k, n in [('00', 29), ('01', 10), ('10', 29), ('11', 10)]}

    def test_complete_factorial_not_admission(self):
        r = a.summarize(self.cells())
        self.assertEqual(r['factor_interaction']['sum'], 0)
        self.assertEqual(r['contrasts']['substrate_in_candidate_background']['net_wins'], -19)
        self.assertEqual(r['packages_admitted'], 0)
        self.assertFalse(r['p9_certified'])

    def test_interaction_not_assumed_zero(self):
        c = self.cells(); c['10'][29]['outcome'] = 'win'
        self.assertEqual(a.summarize(c)['factor_interaction']['sum'], -1)

    def test_original_failure_never_rewritten(self):
        self.assertEqual(a.summarize(self.cells())['original_screen_status'], 'SIGNED_CONTROL_NECESSARY_SCREEN_FAIL')

    def test_missing_corner_rejected(self):
        c = self.cells(); del c['01']
        with self.assertRaises(ValueError): a.summarize(c)

    def test_seed_replacement_rejected(self):
        c = self.cells(); c['01'][0]['seed'] += 1
        with self.assertRaises(ValueError): a.summarize(c)

    def test_reused_negative_changed_rejected(self):
        c = self.cells(); c['11'][10]['outcome'] = 'win'
        with self.assertRaises(ValueError): a.summarize(c)

    def test_fault_not_counted_as_loss(self):
        for value in ('stall', 'error'):
            c = self.cells(); c['01'][0]['outcome'] = value
            with self.assertRaises(ValueError): a.summarize(c)

    def test_error_string_not_hidden(self):
        c = self.cells(); c['10'][0]['error'] = 'observer fault'
        with self.assertRaises(ValueError): a.summarize(c)

    def test_context_not_pooled(self):
        c = self.cells(); c['01'][0]['vow'] = 5
        with self.assertRaises(ValueError): a.summarize(c)

    def test_pairs_require_boolean_outcomes(self):
        with self.assertRaises(ValueError): a.paired([0]*128, [1]*128)

    def test_counts_do_not_fake_independence(self):
        r = a.summarize(self.cells())
        self.assertEqual(r['new_independent_confirmation_samples'], 0)
        self.assertEqual(r['old_outcomes_reused'], 256)
        self.assertEqual(r['new_diagnostic_outcomes'], 256)

    def test_source_rejects_wrong_parent(self):
        with self.assertRaises(ValueError): a.hybrids(b'{}', b'{}')

if __name__ == '__main__': unittest.main()
