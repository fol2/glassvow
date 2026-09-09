import copy
from pathlib import Path
import unittest
import bridge

class BridgeTests(unittest.TestCase):
    def test_wrong_source_refused(self):
        with self.assertRaisesRegex(ValueError,'PILOT_IDENTITY'):bridge.patch('','')
    def test_duplicate_patch_site_refused(self):
        with self.assertRaisesRegex(ValueError,'UNIQUE_PATCH'):bridge.replace_once('xx','x','a')
    def test_missing_patch_site_refused(self):
        with self.assertRaisesRegex(ValueError,'UNIQUE_PATCH'):bridge.replace_once('x','y','a')
    def test_effect_guard_has_other_aspect_and_random_null(self):
        self.assertIn('if random_build or aspect != 1:',bridge.METHODS)
    def test_no_hidden_rng_or_draw_inspection(self):
        for name in ('get_rng','cb.draw','rng.', 'seed', 'randf','OS.', 'future', 'bloodfire_enabled'):
            self.assertNotIn(name,bridge.METHODS)
    def test_bonus_not_per_duplicate_owned_card(self):
        self.assertIn('return score + 2.0 *',bridge.METHODS)
        self.assertNotIn('score += 2.0',bridge.METHODS)
    def test_upgraded_partner_resolved(self):
        self.assertIn('other.merge(other.get("up", {}), true)',bridge.METHODS)
    def test_id_labels_alone_not_sufficient(self):
        self.assertIn('bloodfire_source(content.cards.get',bridge.METHODS)
        self.assertIn('bloodfire_consumer(content.cards.get',bridge.METHODS)
    def test_full_source_delta(self):
        roots=list(Path(__file__).resolve().parents)+[Path('/mnt/data/p9-current-work/base')]
        root=next((p for p in roots if (p/'tools/balance_pilot.gd').exists()),None)
        if root is None:self.fail('PINNED_TEST_SOURCE_MISSING')
        p=(root/'tools/balance_pilot.gd').read_text();s=(root/'tools/balance_sim.gd').read_text()
        a,b,r=bridge.patch(p,s)
        self.assertEqual(set(r['changed_simulator_functions']),{'_claim_rewards','_resolve_event'})
        self.assertEqual(bridge.funcs(p)['card_score'],bridge.funcs(a)['card_score'])
        self.assertEqual(bridge.funcs(p)['_random_shop'],bridge.funcs(a)['_random_shop'])
    def test_no_new_policy_coefficient(self):
        self.assertNotIn('apply_policy',bridge.METHODS)
        self.assertIn('_w("status", "venomousAsh")',bridge.METHODS)
        self.assertIn('2.0 * _w("card", "aspectBonus")',bridge.METHODS)


class ContrastTests(unittest.TestCase):
    def test_exact_no_gain(self):
        import compare_value as v
        self.assertEqual(v.probability(0,0),1)
        self.assertEqual(v.probability(0,4),1)
    def test_exact_gain_tail(self):
        import compare_value as v
        self.assertEqual(v.probability(6,0),1/64)
    def test_half_grid_not_full_policies(self):
        import compare_value as v
        with self.assertRaisesRegex(ValueError,'RECTANGLES'):
            v.compare({'vow':5,'rows':256},{'vow':5,'rows':256},{})

if __name__=='__main__':unittest.main()
