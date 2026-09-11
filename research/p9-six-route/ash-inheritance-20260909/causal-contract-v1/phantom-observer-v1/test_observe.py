"""Adversarial observation-contract checks, not synthetic scientific evidence."""
import copy
from pathlib import Path
import unittest
import observe as O


def sample():
    cb = {'hand':[{'uid':1,'id':'phantomBlades','up':False}],
          'player':{'hp':8,'energy':2},'turn':1,'over':False,'enemies':[]}
    full = {'run':{'rng':123},'combat':cb,'return':True}
    compact = {'hand':copy.deepcopy(cb['hand']),'hp':8,'energy':2,'turn':1,'over':False}
    old = dict(card='phantomBlades',command={'t':'playCard','uid':1},
               before=compact,after=copy.deepcopy(compact),ret=True,clones={},events=[],
               factual_before={},factual_after={})
    new = dict(copy.deepcopy(old),phantom_factual_before=copy.deepcopy(full),
               phantom_factual_after=copy.deepcopy(full))
    truth = {'before':copy.deepcopy(full),'after':copy.deepcopy(full)}
    return old,new,truth


class Tests(unittest.TestCase):
    def test_exact_patch(self):
        root=Path(__file__).parent
        path=root/'observer_old.gd'
        if not path.exists():path=root.parent.parent/'pair-v1/observed_game.gd'
        b=path.read_bytes()
        new=O.patch(b)
        self.assertEqual(new.count(b'super.apply(cmd)'), b.count(b'super.apply(cmd)'))
        self.assertEqual(new.count(b'clone_game()'), b.count(b'clone_game()'))
        self.assertEqual(new.count(b'stream.store_line('),1)
        self.assertEqual(new.count(b'for arm: String'),1)
    def test_wrong_source(self):
        with self.assertRaisesRegex(ValueError,'EXACT_LEGACY'):O.patch(b'anything')
    def test_projection(self):
        old,new,truth=sample();self.assertTrue(O.validate_extension(old,new,truth))
    def test_missing_field(self):
        old,new,truth=sample();del new[O.EXTRA[0]]
        with self.assertRaisesRegex(ValueError,'ADDITIONS'):O.validate_extension(old,new,truth)
    def test_changed_legacy_events(self):
        old,new,truth=sample();new['events'].append({'t':'changed'})
        with self.assertRaisesRegex(ValueError,'LEGACY'):O.validate_extension(old,new,truth)
    def test_changed_snapshot_rng(self):
        old,new,truth=sample();new[O.EXTRA[1]]['run']['rng']=456
        with self.assertRaisesRegex(ValueError,'ORACLE'):O.validate_extension(old,new,truth)
    def test_changed_snapshot_enemy(self):
        old,new,truth=sample();new[O.EXTRA[0]]['combat']['enemies']=[{'idx':0,'hp':999}]
        with self.assertRaisesRegex(ValueError,'ORACLE'):O.validate_extension(old,new,truth)
    def test_no_phantom_clones(self):
        old,new,truth=sample();old['clones']={'AB':{}};new['clones']={'AB':{}}
        with self.assertRaisesRegex(ValueError,'NO_BLOODFIRE'):O.validate_extension(old,new,truth)
    def test_extra_undeclared_field(self):
        old,new,truth=sample();new['unknown']=1
        with self.assertRaisesRegex(ValueError,'ADDITIONS'):O.validate_extension(old,new,truth)
    def test_unrelated_absent_capture(self):
        old,new,_=sample();old['card']=new['card']='leechBlade';new.update({k:{} for k in O.EXTRA})
        self.assertFalse(O.validate_extension(old,new))
    def test_unrelated_injected_capture(self):
        old,new,_=sample();old['card']=new['card']='leechBlade'
        with self.assertRaisesRegex(ValueError,'NON_PHANTOM'):O.validate_extension(old,new)
    def test_rejected_not_imputed(self):
        old,new,truth=sample();old['ret']=new['ret']=False;truth['after']['return']=False
        new[O.EXTRA[1]]['return']=False
        self.assertTrue(O.validate_extension(old,new,truth))
    def test_missing_state(self):
        old,new,truth=sample();new[O.EXTRA[0]]={}
        with self.assertRaisesRegex(ValueError,'FULL_STATE'):O.validate_extension(old,new,truth)
    def test_compact_mismatch(self):
        old,new,_=sample();new[O.EXTRA[1]]['combat']['player']['energy']=99
        with self.assertRaisesRegex(ValueError,'ENERGY'):O.validate_extension(old,new)
    def test_timing_only_outcome_difference(self):
        O.equivalent_outcome({'row':{'win':1},'run_usec':1,'query_usec':1},
                             {'row':{'win':1},'run_usec':2,'query_usec':2})
    def test_decision_difference_not_timer(self):
        with self.assertRaisesRegex(ValueError,'DECISION'):
            O.equivalent_outcome({'decisions':[1],'run_usec':1},{'decisions':[2],'run_usec':2})

if __name__=='__main__':unittest.main(verbosity=2)
