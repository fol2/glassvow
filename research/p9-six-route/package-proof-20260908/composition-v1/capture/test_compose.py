import unittest
import compose as c

class Tests(unittest.TestCase):
    def test_unknown_null_is_not_ignored(self):
        self.assertEqual(c.differences({}, {'future_mediator':None}),['future_mediator'])
    def test_absent_and_null_not_equal(self):
        self.assertEqual(c.differences({'draw':None},{}),['draw'])
    def test_upgrade_overrides(self):
        self.assertEqual(c.resolved({'cost':1,'up':{'cost':0}},True),{'cost':0})
    def test_draw_not_scalar_erased(self):
        self.assertEqual(c.differences({'effects':[]},{'effects':[{'kind':'draw','n':1}]}),['effects'])
    def test_acquisition_retained(self):
        self.assertEqual(c.differences({'rarity':'rare'},{'rarity':'common'}),['rarity'])
    def test_duplicate_functions_rejected(self):
        with self.assertRaises(ValueError):c.function('func a():\n\tpass\nfunc a():\n\tpass\n','a')
    def test_indented_comments_not_removed(self):
        self.assertIn('\t# kept',c.function('func a():\n\tpass\n\t# kept\n# tail\n','a'))
    def test_body_changes_not_erased(self):
        self.assertNotEqual(c.function('func a():\n\treturn 1\n# tail\n','a'),c.function('func a():\n\treturn 2\n# tail\n','a'))
    def test_unroll_keeps_two_death_guards(self):
        source='func play_card():\n'+c.LOOP+'\treturn true\n'
        out=c.unroll(source)
        self.assertEqual(out.count('if not cb.over:'),2)
        self.assertIn('if effects.size() == 2:',out)
        self.assertIn('else:',out)
        self.assertIn('return true',out)
    def test_unrecognised_loop_fails(self):
        with self.assertRaises(ValueError):c.unroll('func play_card():\n\tpass\n')
    def test_other_special_arms_not_mixed(self):
        s='func _apply_special():\n\tmatch sid:\n\t\t"momentum":\n\t\t\tgrow()\n\t\t"shatterEcho":\n\t\t\techo()\n'
        self.assertEqual(c.arm(s,'_apply_special','momentum'),'\t\t\tgrow()\n')
    def test_parameters_retained(self):
        self.assertEqual(c.differences({'n':6,'grow':4},{'n':0,'grow':14}),['grow','n'])

if __name__=='__main__':unittest.main()
