"""Falsification tests for the scoped proof; no simulator or historical study."""
import copy
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('p9_formal_compare', Path(__file__).with_name('compare.py'))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


def status_card(who='allEnemies', n=3):
    return {'cost': 1, 'type': 'skill', 'target': 'allEnemies', 'effects': [
        {'kind': 'status', 'id': 'poison', 'who': who, 'n': n}]}


def wrapped64(value):
    return ((value + (1 << 63)) % (1 << 64)) - (1 << 63)


class ProofTests(unittest.TestCase):
    def test_complete_residue_closure(self):
        self.assertEqual(m.fixed_point((0, 0)), [(0, 0)])

    def test_generator_range_is_closed(self):
        for a in range(8):
            for b in range(8):
                for u, v in m.kernel_successors((a, b)):
                    self.assertTrue(0 <= u < 8 and 0 <= v < 8)

    def test_wraparound_preserves_required_divisibility(self):
        values = [0, 8, -8, (1 << 63) - 8, -(1 << 63)]
        coefficients = [0, 1, 2, 3, 7, -1, -(1 << 63), (1 << 63) - 1]
        for a in values:
            for k in coefficients:
                self.assertEqual(wrapped64(a * k) % 8, 0)

    def test_transfer_wraparound(self):
        self.assertEqual(wrapped64(((1 << 63) - 8) + 16) % 8, 0)

    def test_positive_background_both_variants_fail_residue_inclusion(self):
        for n in (4, 5):
            self.assertNotIn(((8 + n) % 8, 0), m.fixed_point((0, 0)))

    def test_point_rebinding_invalidates_refutation(self):
        def with_background(state):
            return m.kernel_successors(state) | {((state[0] + 4) % 8, state[1])}
        self.assertIn((4, 0), m.fixed_point((0, 0), with_background))

    def test_decay_would_invalidate_refutation_if_phase_were_hidden(self):
        def hide_phase(state):
            return m.kernel_successors(state) | {((state[0] - 1) % 8, state[1])}
        self.assertIn((4, 0), m.fixed_point((0, 0), hide_phase))
        self.assertIn((5, 0), m.fixed_point((0, 0), hide_phase))

    def test_modulus_divides_machine_ring(self):
        self.assertEqual((1 << 64) % m.MODULUS, 0)

    def test_source_all_not_silently_retargeted(self):
        self.assertEqual(m.source_atoms(status_card()), ['add_all'])

    def test_point_source_detected(self):
        self.assertEqual(m.source_atoms(status_card('target', 4)), ['add_target'])

    def test_zero_source_does_not_add_stock(self):
        self.assertEqual(m.source_atoms(status_card(n=0)), [])

    def test_negative_source_requires_separate_model(self):
        with self.assertRaisesRegex(ValueError, 'NEGATIVE'):
            m.source_atoms(status_card(n=-1))

    def test_bool_is_not_an_authored_integer(self):
        with self.assertRaisesRegex(ValueError, 'INTEGER'):
            m.source_atoms(status_card(n=True))

    def test_float_is_not_an_authored_integer(self):
        with self.assertRaisesRegex(ValueError, 'INTEGER'):
            m.source_atoms(status_card(n=3.0))

    def test_unknown_target_fails_closed(self):
        with self.assertRaisesRegex(ValueError, 'TARGETING'):
            m.source_atoms(status_card('otherEnemy'))

    def test_new_role_effect_fails_closed(self):
        with self.assertRaisesRegex(ValueError, 'UNMODELLED'):
            m.source_atoms({'effects': [{'kind': 'special', 'id': 'newPoisonSource'}]})

    def test_marker_remains_visible_in_model(self):
        card = status_card()
        card['effects'].append({'kind': 'status', 'id': 'mistbound', 'n': 1, 'who': 'allEnemies'})
        self.assertEqual(m.source_atoms(card), ['add_all', 'visible_marker'])

    def test_catalyst_is_not_an_additive_source(self):
        card = {'exhaust': True, 'effects': [{'kind': 'special', 'id': 'catalyst', 'n': 2,
                                          'mistboundBonus': 1}]}
        self.assertEqual(m.source_atoms(card), ['integer_scale_target'])

    def test_upgrade_replaces_effect_array(self):
        card = status_card()
        card['up'] = {'effects': [{'kind': 'status', 'id': 'poison', 'n': 5, 'who': 'allEnemies'}]}
        values = list(m.variants(card))
        self.assertEqual(values[0][1]['effects'][0]['n'], 3)
        self.assertEqual(values[1][1]['effects'][0]['n'], 5)
        self.assertEqual(values[1][1]['cost'], 1)

    def test_lifecycle_metadata_not_mutated(self):
        card = {'cost': 0, 'exhaust': True, 'effects': [{'kind': 'draw', 'n': 2}],
                'up': {'exhaust': False}}
        original = copy.deepcopy(card)
        variants = list(m.variants(card))
        self.assertTrue(variants[0][1]['exhaust'])
        self.assertFalse(variants[1][1]['exhaust'])
        self.assertEqual(card, original)

    def test_deterministic_document_bytes(self):
        with tempfile.TemporaryDirectory() as tmp:
            a, b = Path(tmp) / 'a.json', Path(tmp) / 'b.json'
            m.dump(a, {'z': 0, 'a': [1, 2]})
            m.dump(b, {'a': [1, 2], 'z': 0})
            self.assertEqual(a.read_bytes(), b.read_bytes())

    def test_wrong_archive_identity_rejected_before_open(self):
        with self.assertRaisesRegex(ValueError, 'ARCHIVE_IDENTITY'):
            m.archive_content(b'not an archive')

    def test_only_matched_signature_never_opens_confirmation(self):
        # The implementation intentionally has no successful admission branch:
        # its comparison library and framing algebra are not complete P9 proof.
        source = Path(m.__file__).read_text()
        self.assertIn("'formal_eligibility': False", source)
        self.assertIn("'opens_population_confirmation': False", source)
        self.assertNotIn("'formal_eligibility': True", source)


if __name__ == '__main__':
    unittest.main()
