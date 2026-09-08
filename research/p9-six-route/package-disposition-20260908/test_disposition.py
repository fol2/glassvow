import copy,json,os,tempfile,unittest
from pathlib import Path
import disposition as d
import hand_contract as h
from read_packet import unpack

R=Path(__file__).parent
B=Path(os.environ.get('P9_BASE','/mnt/data/p9-unified/base'))
C=Path(os.environ.get('P9_CANDIDATE','/mnt/data/p9-unified/candidate'))

class DispositionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data=d.build(B,C,R)
    def test_six_contexts_not_six_certificates(self):
        self.assertEqual(len(self.data['routes']),6)
        self.assertFalse(any(r['admitted'] for r in self.data['routes']))
        self.assertEqual(self.data['packages_admitted'],0)
    def test_hand_family_permission_not_quantitative_carry(self):
        r=self.data['hand_first_decision']
        self.assertTrue(r['inherited_family_eligible'])
        self.assertFalse(r['old_numerical_admission_carries'])
        self.assertFalse(r['requires_night_sight'])
    def test_historical_producer_set_exact(self):
        self.assertEqual(self.data['historical_hand_contract']['producers'],['preparation','surge'])
    def test_hand_curve_full_domain(self):
        self.assertEqual(self.data['hand_payoff_curves'][0]['candidate_raw'],[0,2,4,6,8,14,20,26,32,38])
        self.assertEqual(self.data['hand_payoff_curves'][1]['candidate_raw'],[0,2,4,6,8,15,22,29,36,43])
    def test_pre_removal_count_rejected(self):
        with self.assertRaises(ValueError):d.payoff(10,{'n':6,'reserve':4,'floor_per':2})
    def test_negative_stock_rejected(self):
        with self.assertRaises(ValueError):d.payoff(-1,{'n':6})
    def test_old_linear_law_preserved_as_comparator(self):
        self.assertEqual(self.data['hand_payoff_curves'][0]['old_raw'],list(range(0,30,3)))
    def test_upgrade_exhaust_change_retained(self):
        r=self.data['hand_card_deltas']['preparation'][1]
        self.assertFalse(r['base']['exhaust']);self.assertTrue(r['candidate']['exhaust'])
        self.assertIn('effects',r['changed'])
    def test_rarity_not_erased(self):
        self.assertIn('rarity',self.data['hand_card_deltas']['phantomBlades'][0]['changed'])
    def test_alternative_producers_not_erased(self):
        ids={r['card_id'] for r in self.data['producer_source_inventory']['direct_draw']}
        self.assertTrue({'preparation','surge','momentum','firstSpark'}<=ids)
    def test_inherited_background_card_not_dropped(self):
        self.assertEqual(self.data['existing_candidate_added_card_ids'],['banklight'])
    def test_missing_source_fails(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaises(OSError):d.build(folder,C,R)
    def test_no_fabricated_hard_guardrail_verdict(self):
        r=self.data['guardrail_screen']
        self.assertFalse(r['formal_hard_guardrail_pass'])
        self.assertFalse(r['formal_hard_guardrail_failure_proved_by_this_census'])
    def test_every_route_preserves_open_population_obligation(self):
        self.assertTrue(all(r['obligations']['competent_multi_policy_support']=='MISSING_FOR_EXACT_CANDIDATE' for r in self.data['routes']))
    def test_hand_missing_payoff_is_unknown(self):
        p=json.loads((R/'HAND-PRIMARY.json').read_bytes());r=h.analyze(p,unpack(R))
        self.assertEqual(len(r['cells']),32)
        self.assertTrue(all(x['complete_historical_activation_count'] is None for x in r['cells']))
        self.assertEqual(sum(x['unknown_payoff_rows'] for x in r['cells']),2048)
    def test_hand_more_than_night_sight_proxy(self):
        r=h.analyze(json.loads((R/'HAND-PRIMARY.json').read_bytes()),unpack(R))
        x=next(x for x in r['cells'] if (x['catalogue'],x['aspect'],x['vow'],x['arm'])==('candidate','ashwarden',0,1))
        self.assertEqual(x['final_producer_consumer_coplay'],31)
    def test_hand_fake_payoff_rejected(self):
        p=json.loads((R/'HAND-PRIMARY.json').read_bytes());p['groups'][0][-1]='f'*16
        with self.assertRaises(ValueError):h.analyze(p,unpack(R))
    def test_hand_missing_context_rejected(self):
        p=json.loads((R/'HAND-PRIMARY.json').read_bytes());p['groups'].pop()
        with self.assertRaises(ValueError):h.analyze(p,unpack(R))
    def test_roadmap_not_a_time_promise(self):
        text=d.markdown(self.data)
        self.assertIn('No wall-time promise',text)
        self.assertIn('0/6',text)
        self.assertIn('Preparation/Surge',text)

if __name__=='__main__':unittest.main()
