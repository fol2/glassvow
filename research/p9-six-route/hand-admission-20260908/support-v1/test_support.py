import copy,unittest
from cohort import policies,configurations,identity
from read_support import complete_chain,require,summarize

class SupportTests(unittest.TestCase):
    def test_actual_policy_vectors(self):
        p=policies();self.assertEqual(len(p),128);self.assertEqual(len({x['policy_id'] for x in p}),128)
        self.assertEqual(p,policies())
    def test_policy_ids_include_parameters(self):
        p=policies()[0];changed=copy.deepcopy(p['params']);changed['fit']+=.01
        self.assertNotEqual(identity({'route':p['route'],'params':changed}),p['policy_id'])
    def test_no_forced_acquisition(self):
        for c in configurations(5):
            self.assertFalse(any(k in c for k in ('fixed_deck','fixed_relics','ban','encounter','all_deeds')))
            self.assertFalse(c['causal_probe'])
    def test_complete_assignment(self):
        self.assertEqual(sum(c['runs'] for c in configurations(5)),512)
    def test_smoke_outside_population(self):
        a={c['seed0'] for c in configurations(5)};b={c['seed0'] for c in configurations(5,True)}
        self.assertFalse(a&b)
    @staticmethod
    def record():
        arms=[{'mask':m,'complete':True,'steps':[{'health':{'removed':14 if m==0 else 6 if m==3 else 8 if m==4 else 6}}]} for m in range(8)]
        return {'direct':[{'health':{'removed':14}},{'health':{'removed':8}}],
                'high_health_contribution':6,'prefix_arms':arms}
    def test_positive_health_interaction(self):
        self.assertEqual(complete_chain(self.record()),'POSITIVE_SOURCE_BY_HIGH_PAYOFF_HEALTH_INTERACTION')
    def test_no_producer_not_complete_chain(self):
        x=self.record();x['prefix_arms']=[]
        self.assertEqual(complete_chain(x),'NO_POSITIVE_COMPLETE_HISTORICAL_CHAIN')
    def test_blocked_is_opportunity_not_zero_damage(self):
        x=self.record();x['prefix_arms'][3]={'mask':3,'complete':False,'steps':[]}
        self.assertEqual(complete_chain(x),'SOURCE_REQUIRED_FOR_RECORDED_COMMAND_OPPORTUNITY')
    def test_missing_other_damage_remains_unknown(self):
        x=self.record();x['prefix_arms'][4]={'mask':4,'complete':False,'steps':[]}
        self.assertEqual(complete_chain(x),'UNRESOLVED_PREFIX_DAMAGE_CONTRAST')
    def test_lethal_saturation_retained(self):
        x=self.record();x['direct'][0]['health']['removed']=8;x['high_health_contribution']=0
        self.assertEqual(complete_chain(x),'NO_POSITIVE_COMPLETE_HISTORICAL_CHAIN')
    def test_missing_grid_rejected(self):
        with self.assertRaises(ValueError):summarize([])
    def test_missing_branch_rejected(self):
        x=self.record();x['prefix_arms'].pop()
        with self.assertRaises(ValueError):complete_chain(x)
    def test_forged_delta_rejected(self):
        x=self.record();x['high_health_contribution']=7
        with self.assertRaises(ValueError):complete_chain(x)
    def test_inactive_does_not_equal_marginal_nonpositive_once(self):
        # Classification at policy level must inspect all four assigned rows.
        x=self.record();x['prefix_arms'][0]['steps'][-1]['health']['removed']=6
        self.assertEqual(complete_chain(x),'NO_POSITIVE_COMPLETE_HISTORICAL_CHAIN')
if __name__=='__main__':unittest.main()
