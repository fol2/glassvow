import copy
import json
from pathlib import Path
import tempfile
import unittest
import read_pair as m


def arm(hp=100,after=90,stock=1):
    return {'initial_equal':True,'before':{'run':{},'combat':{'player':{'statuses':{'bloodfire':stock} if stock else {}},'enemies':[{'idx':0,'hp':hp}]},'return':True},
            'after':{'run':{},'combat':{'player':{'statuses':{}},'enemies':[{'idx':0,'hp':after}]},'return':True},
            'events':[{'t':'hitEnemy','idx':0,'amount':hp-after}], 'ret':True}


def record():
    ab=arm(after=80);a=arm(after=90);a['after']['combat']['player']['statuses']={'bloodfire':1}
    n=arm(after=90,stock=0)
    return {'clones':{'none':copy.deepcopy(n),'B':copy.deepcopy(n),'A':a,'AB':ab},
            'original_untouched_by_clones':True,'factual_clone_match':True,
            'factual_before':copy.deepcopy(ab['before']),'factual_after':copy.deepcopy(ab['after']),
            'events':copy.deepcopy(ab['events']),'ret':True,'command':{'target':0},'before':{'bloodfire':1}}


class PairTests(unittest.TestCase):
    def test_saturated_hp_is_not_overkill(self):
        self.assertEqual(m.hp_removed(arm(hp=5,after=-20),0),5)
    def test_negative_hp_not_negative_healing(self):
        self.assertEqual(m.hp_removed(arm(hp=-5,after=-20),0),0)
    def test_valid_factorial(self):
        r=m.clones(record());self.assertEqual(r['hp_interaction'],10)
    def test_factual_mismatch_rejected(self):
        r=record();r['clones']['AB']['after']['combat']['enemies'][0]['hp']=2
        with self.assertRaisesRegex(ValueError,'FACTUAL_PARITY'):m.clones(r)
    def test_hidden_other_state_change_rejected(self):
        r=record();r['clones']['A']['before']['combat']['enemies'][0]['hp']=999
        with self.assertRaisesRegex(ValueError,'INTERVENTION'):m.clones(r)
    def test_null_change_rejected(self):
        r=record();r['clones']['B']['events'][0]['amount']=20
        with self.assertRaisesRegex(ValueError,'EXACT_NULL'):m.clones(r)
    def test_incomplete_clone_rejected(self):
        r=record();del r['clones']['A']
        with self.assertRaisesRegex(ValueError,'RECTANGLE'):m.clones(r)
    def test_clone_mutating_factual_rejected(self):
        r=record();r['original_untouched_by_clones']=False
        with self.assertRaisesRegex(ValueError,'MUTATION'):m.clones(r)
    def test_unmatched_clone_initial_rejected(self):
        r=record();r['clones']['A']['initial_equal']=False
        with self.assertRaisesRegex(ValueError,'INITIAL'):m.clones(r)
    def test_same_seeds_are_not_extra_policies(self):
        policies={i:{'bloodfire':i<32,'hand':i>=32,'reachable_bloodfire':True,'reachable_hand':True} for i in range(64)}
        r=m.support_decision(policies,{'active':32,'inactive':32,'reachable':16,'exclusive':8})
        self.assertTrue(r['pass']);self.assertEqual(r['packages']['bloodfire']['active'],32)
    def test_high_ubiquity_fails_inactivity(self):
        policies={i:{'bloodfire':True,'hand':True,'reachable_bloodfire':True,'reachable_hand':True} for i in range(128)}
        self.assertFalse(m.support_decision(policies,{'active':32,'inactive':32,'reachable':16,'exclusive':8})['pass'])
    def test_joint_activation_not_exclusive(self):
        policies={i:{'bloodfire':i<64,'hand':i<64,'reachable_bloodfire':True,'reachable_hand':True} for i in range(128)}
        r=m.support_decision(policies,{'active':32,'inactive':32,'reachable':16,'exclusive':8})
        self.assertFalse(r['gates']['hand']['exclusive'])
    def test_consumption_not_incremental_hp(self):
        s={'played':{'preparation':0,'surge':0,'phantomBlades':0,'leechBlade':1},'bloodfire_applied':1,'bloodfire_consumed':1,
           'phantom_damage':0,'coowned_bloodfire':True,'coowned_hand':False,
           'clones':[{'legal':True,'positive_stock':True,'hp_interaction':0}]}
        r=m.run_flags({'row':{'deckIds':['bloodRite','leechBlade']}},s)
        self.assertTrue(r['bloodfire']);self.assertFalse(r['bloodfire_incremental_hp'])
    def test_hand_requires_actual_present_producer(self):
        s={'played':{'preparation':0,'surge':0,'phantomBlades':1,'leechBlade':0},'bloodfire_applied':0,'bloodfire_consumed':0,
           'phantom_damage':20,'coowned_bloodfire':False,'coowned_hand':True,'clones':[]}
        self.assertFalse(m.run_flags({'row':{'deckIds':['preparation','phantomBlades']}},s)['hand'])
    def test_illegal_counterfactual_cannot_be_counted(self):
        r=record();r['clones']['A']['ret']=False
        with self.assertRaisesRegex(ValueError,'ELIGIBILITY'):m.clones(r)
    def test_heal_is_actual_event_not_hp_net(self):
        a=arm();a['events']=[{'t':'heal','who':'player','n':4},{'t':'heal','who':0,'n':30}]
        self.assertEqual(m.heal(a),4)

if __name__=='__main__':unittest.main()
