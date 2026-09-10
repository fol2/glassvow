"""Regression checks for the existing frozen causal contract, not new observations."""
import copy
import json
from pathlib import Path
import unittest
from unittest.mock import patch
import read_causal as r
import run_causal as runner


def rectangle(vow=5, outcomes=None):
    outcomes = outcomes or {'00': 'loss', '01': 'loss', '10': 'loss', '11': 'win'}
    return {world: [
        {'index': i, 'seed': seed, 'vow': vow, 'policy': {'identity': i},
         'row': {'outcome': outcomes[world], 'error': ''}}
        for first in range(0, 128, 2) for i in (first, first + 1)
        for seed in r.config(first, vow)['seeds']]
        for world in r.WORLDS}


class CausalTests(unittest.TestCase):
    def test_registered_assignment(self):
        self.assertEqual(r.config(0, 5)['seeds'], [73525100,73525101,73525102,73525103])
        self.assertEqual(r.config(126, 0)['seeds'], [73520352,73520353,73520354,73520355])
        self.assertEqual(r.config(0, 5)['root'], 73409000)

    def test_assignment_rejects_invalid_first(self):
        for first in (-2, 1, 128, True, 0.0):
            with self.subTest(first=first), self.assertRaises(ValueError):
                r.config(first, 5)

    def test_assignment_rejects_other_vow(self):
        with self.assertRaises(ValueError): r.config(0, 4)

    def test_vows_have_disjoint_nonprotected_seed_blocks(self):
        sets = [{s for first in range(0,128,2) for s in r.config(first,v)['seeds']} for v in (0,5)]
        self.assertEqual([len(s) for s in sets], [256,256])
        self.assertFalse(sets[0] & sets[1])
        self.assertFalse((sets[0] | sets[1]) & set(range(5000,5200)))

    def test_all_worlds_required(self):
        data=rectangle(); del data['10']
        with self.assertRaisesRegex(ValueError,'FOUR_WORLDS'): r.primary(data,5)

    def test_missing_row_rejected_before_statistics(self):
        data=rectangle(); data['11'].pop()
        with self.assertRaisesRegex(ValueError,'COMPLETE_UNIQUE_RECTANGLE'): r.primary(data,5)

    def test_duplicate_not_counted_as_observation(self):
        data=rectangle(); data['11'][-1]=copy.deepcopy(data['11'][0])
        with self.assertRaisesRegex(ValueError,'COMPLETE_UNIQUE_RECTANGLE'): r.primary(data,5)

    def test_changed_seed_rejected(self):
        data=rectangle(); data['11'][0]['seed']+=100000
        with self.assertRaisesRegex(ValueError,'COMPLETE_UNIQUE_RECTANGLE'): r.primary(data,5)

    def test_policy_pairing_required(self):
        data=rectangle(); data['11'][0]['policy']={'identity':999}
        with self.assertRaisesRegex(ValueError,'MATCHED_POLICY'): r.primary(data,5)

    def test_error_is_not_loss(self):
        data=rectangle(); data['01'][0]['row']['error']='SCRIPT ERROR'
        with self.assertRaisesRegex(ValueError,'FAULT_NOT_LOSS'): r.primary(data,5)

    def test_stall_is_not_loss(self):
        data=rectangle(); data['01'][0]['row']['outcome']='stall'
        with self.assertRaisesRegex(ValueError,'FAULT_NOT_LOSS'): r.primary(data,5)

    def test_vow_binding(self):
        data=rectangle(); data['01'][0]['vow']=0
        with self.assertRaisesRegex(ValueError,'ROW_VOW'): r.primary(data,5)

    def test_complete_constant_positive_case(self):
        actual=r.primary(rectangle(),5)
        self.assertTrue(actual['primary_pass'])
        self.assertEqual(actual['distinct_seed_blocks'],256)
        for contrast in actual['contrasts'].values():
            self.assertEqual(contrast['point'],1.0)
            self.assertEqual(contrast['bonferroni_percentile_interval'],[1.0,1.0])

    def test_exact_null_cannot_pass(self):
        actual=r.primary(rectangle(outcomes=dict.fromkeys(r.WORLDS,'win')),5)
        self.assertFalse(actual['primary_pass'])
        for contrast in actual['contrasts'].values():
            self.assertEqual(contrast['point'],0.0)
            self.assertEqual(contrast['bonferroni_percentile_interval'],[0.0,0.0])

    def test_blocks_are_seeds_not_individual_rows(self):
        observed=[]
        def capture(blocks):
            observed.extend(blocks)
            return [[0.,0.]]*3
        with patch.object(r,'bootstrap',side_effect=capture): r.primary(rectangle(),5)
        self.assertEqual(len(observed),256)
        self.assertTrue(all(b==[1.0,1.0,1.0] for b in observed))

    def test_missing_seed_block_rejected(self):
        with self.assertRaisesRegex(ValueError,'SEED_BLOCK_COUNT'): r.bootstrap([[0.,0.,0.]]*255)

    def test_nonfinite_contrast_rejected(self):
        with self.assertRaisesRegex(ValueError,'FINITE_CONTRASTS'): r.bootstrap([[float('nan'),0.,0.]]*256)

    def test_cost_conjunction_is_exact(self):
        costs=dict.fromkeys(r.WORLDS,3600.0)
        self.assertTrue(r.resource_ok(costs))
        for bad in (3600.01,-1.0,float('nan'),float('inf')):
            altered=dict(costs,**{'11':bad})
            with self.subTest(cost=bad): self.assertFalse(r.resource_ok(altered))
        self.assertFalse(r.resource_ok({'11':1.0}))

    def test_source_flags_survive_both_clone_layers(self):
        base=Path(__file__).resolve().parent.parent
        data=(base/'pair-v1/observed_game.gd').read_bytes()
        for world in r.WORLDS:
            transformed=runner.observer_source(data,world).decode()
            self.assertIn('g.rules.set(flag, rules.get(flag))',transformed)
            self.assertIn('bool(rules.get("bloodfire_consumer_enabled")) and arm in ["B", "AB"]',transformed)
            a,b=('true' if x=='1' else 'false' for x in world)
            self.assertIn('rules.set("bloodfire_producer_enabled", '+a+')',transformed)
            self.assertIn('rules.set("bloodfire_consumer_enabled", '+b+')',transformed)

    def test_named_unsafe_mutant_remains_distinguishable(self):
        base=Path(__file__).resolve().parent.parent
        data=(base/'pair-v1/observed_game.gd').read_bytes()
        safe=runner.observer_source(data,'10')
        mutant=runner.observer_source(data,'10',unsafe=True)
        self.assertNotEqual(safe,mutant)
        self.assertIn(b'g.rules.set("bloodfire_consumer_enabled", arm in ["B", "AB"])',mutant)

    def test_wrong_observer_identity_rejected(self):
        with self.assertRaisesRegex(ValueError,'OBSERVER_OR_WORLD_IDENTITY'):
            runner.observer_source(b'not the bound source','11')

    def test_contract_not_silently_changed(self):
        root=Path(__file__).resolve().parent
        data=(root/'CONTRACT.json').read_bytes()
        self.assertEqual(runner.blob(data),runner.CONTRACT_BLOB)
        p=json.loads(data)
        self.assertEqual(p['source_erratum']['base_effects'],[{'kind':'loseHp','n':3},{'kind':'energy','n':2}])
        self.assertEqual(p['containment']['cpu_seconds_per_world_per_vow'],3600)
        self.assertEqual(p['frozen_assignment']['policies'],128)
        self.assertFalse(p['p9_certified'])
        self.assertEqual(p['packages_admitted'],0)


if __name__=='__main__': unittest.main(verbosity=2)
