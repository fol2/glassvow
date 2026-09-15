"""Exhaustive synthetic primitive checks; no game execution or authority."""
import itertools
import unittest

from primitive_reduction import paired, route


class PrimitiveReductionTests(unittest.TestCase):
    def test_paired_truth_table(self):
        for left, right in itertools.product((0, 1), repeat=2):
            gain, loss = paired([left], [right])
            self.assertEqual(gain, [int(left == 1 and right == 0)])
            self.assertEqual(loss, [int(left == 0 and right == 1)])
            self.assertLessEqual(gain[0] + loss[0], 1)

    def test_route_truth_table_and_impossible_enactment(self):
        for win, acquired, enacted, other in itertools.product((0, 1), repeat=4):
            if enacted > acquired:
                with self.assertRaises(ValueError):
                    route([win], [acquired], [enacted], [other])
                continue
            result = route([win], [acquired], [enacted], [other])
            self.assertEqual(result['win_enact'], [int(win and enacted)])
            self.assertEqual(result['exclusive'], [int(enacted and not other)])
            self.assertEqual(result['acquire'], [acquired])
            self.assertEqual(result['enact'], [enacted])

    def test_root_alignment_and_binary_types(self):
        for invalid in ([], [True], [1.0], [2], ['1'], None):
            with self.assertRaises(ValueError):
                paired(invalid, [0])
        with self.assertRaises(ValueError):
            paired([1, 0], [0])
        with self.assertRaises(ValueError):
            route([1], [1, 1], [1], [0])

    def test_same_trajectory_membership_preserves_multiple_routes(self):
        result = route([1, 1], [1, 1], [1, 1], [1, 0])
        self.assertEqual(result['enact'], [1, 1])
        self.assertEqual(result['exclusive'], [0, 1])
        self.assertEqual(result['win_enact'], [1, 1])


if __name__ == '__main__':
    unittest.main(verbosity=2)
