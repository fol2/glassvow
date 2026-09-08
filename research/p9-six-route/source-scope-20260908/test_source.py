import copy
from pathlib import Path
import unittest
import audit_source as a

class SourceTests(unittest.TestCase):
    def test_unknown_card_field_not_erased(self):
        old = {'effects': [], 'cost': 1}
        new = dict(old, future_mediator=1)
        self.assertFalse(a.compare_card(old, new, False)['combat_projection_equal'])

    def test_acquisition_change_recorded_not_whole_game_equivalence(self):
        old = {'effects': [], 'cost': 1, 'rarity': 'rare'}
        new = dict(old, rarity='common')
        row = a.compare_card(old, new, False)
        self.assertTrue(row['combat_projection_equal'])
        self.assertEqual(row['changed_keys'], ['rarity'])
        self.assertNotEqual(row['base_rarity'], row['candidate_rarity'])

    def test_draw_addition_not_erased(self):
        old = {'effects': [{'kind': 'special', 'id': 'momentum', 'n': 6}]}
        new = copy.deepcopy(old)
        new['effects'].append({'kind': 'draw', 'n': 1})
        self.assertFalse(a.compare_card(old, new, False)['combat_projection_equal'])

    def test_upgrade_overrides_not_ignored(self):
        old = {'cost': 1, 'up': {'cost': 0}}
        new = {'cost': 1, 'up': {'cost': 2}}
        self.assertTrue(a.compare_card(old, new, False)['combat_projection_equal'])
        self.assertFalse(a.compare_card(old, new, True)['combat_projection_equal'])

    def test_function_duplicate_rejected(self):
        with self.assertRaises(ValueError):
            a.functions('func x():\n\treturn 1\nfunc x():\n\treturn 2\n')

    def test_body_change_not_hidden_by_comments(self):
        old = 'func x():\n\treturn 1\n\n# footer\n'
        new = 'func x():\n\treturn 2\n\n# footer\n'
        self.assertNotEqual(a.functions(old), a.functions(new))

    def test_special_branch_not_other_branch(self):
        source = 'func _apply_special():\n\tmatch id:\n\t\t"momentum":\n\t\t\tinst.bonus += 1\n\t\t"shatterEcho":\n\t\t\thit(2)\n\t\t_:\n\t\t\terror()\n'
        self.assertIn('inst.bonus', a.special_arm(source, 'momentum'))
        self.assertNotIn('hit(2)', a.special_arm(source, 'momentum'))
        with self.assertRaises(ValueError):
            a.special_arm(source, 'missing')

    def test_multiplicity_not_erased(self):
        old = {'effects': [{'kind': 'dmg', 'n': 2, 'times': 3}]}
        new = {'effects': [{'kind': 'dmg', 'n': 2, 'times': 5}]}
        self.assertFalse(a.compare_card(old, new, False)['combat_projection_equal'])

if __name__ == '__main__':
    unittest.main()
