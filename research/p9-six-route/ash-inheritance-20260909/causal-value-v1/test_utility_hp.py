"""Delivery regression: native lose_combat clamps HP; the self-hit remains three.
Original qualify.py at ac9aaf68 expected -1 for its own initial_hp=2 fixture.
The retained source-utility capture and main CombatRules.lose_combat both refute
that expectation. No fixture, engine, game rule or population decision changes.
"""
import unittest
import qualify

class UtilityHPTests(unittest.TestCase):
    def test_two_hp_lethal(self):
        self.assertEqual(qualify.source_hp_after(2),0)
        self.assertNotEqual(qualify.source_hp_after(2),2-3)
    def test_three_hp_lethal(self):
        self.assertEqual(qualify.source_hp_after(3),0)
    def test_surviving_exchange(self):
        self.assertEqual(qualify.source_hp_after(30),27)
    def test_invalid_initial_values_rejected(self):
        for hp in (0,-1,True,2.0):
            with self.subTest(hp=hp),self.assertRaises(ValueError):
                qualify.source_hp_after(hp)

if __name__=='__main__': unittest.main(verbosity=2)
