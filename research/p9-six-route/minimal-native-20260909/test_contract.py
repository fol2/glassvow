"""Synthetic/adversarial checker tests; never native outcome samples."""
import copy
import unittest
import prove_contract as p
import verify as v

class ContractTests(unittest.TestCase):
    def before(self,hp=100,block=0):
        return {'statuses':{},'targets':[{'idx':i,'hp':hp,'block':block,'statuses':{}} for i in (0,1)]}
    def hits(self,values,idx=0,hp=100,blocked=None):
        out=[]
        for i,n in enumerate(values):
            hp=max(0,hp-n)
            out.append({'t':'hitEnemy','idx':idx,'amount':n,'hpAfter':hp,'blocked':0 if blocked is None else blocked[i]})
        return out
    def test_native_three_hit_arithmetic(self):
        p.attack_hits(self.before(),self.hits([4,4,4]),2,2,False,0)
    def test_selective_amplification_keeps_three_hits(self):
        p.attack_hits(self.before(),self.hits([4,2,2]),2,2,True,0)
    def test_dormant_selective_is_exact_arithmetic_null(self):
        for off in (False,True):p.attack_hits(self.before(),self.hits([2,2,2]),2,0,off,0)
    def test_target_death_stops_remaining_hits(self):
        p.attack_hits(self.before(hp=3),self.hits([4],hp=3),2,2,False,0)
    def test_illegal_postdeath_hit_rejected(self):
        with self.assertRaises(ValueError):p.attack_hits(self.before(hp=3),self.hits([4,4],hp=3),2,2,False,0)
    def test_collapse_to_one_hit_rejected(self):
        with self.assertRaises(ValueError):p.attack_hits(self.before(),self.hits([12]),2,2,False,0)
    def test_empty_hit_capture_is_not_vacuously_true(self):
        with self.assertRaises(ValueError):p.attack_hits(self.before(),[],2,2,False,0)
    def test_wrong_target_with_same_hp_is_rejected(self):
        with self.assertRaises(ValueError):p.attack_hits(self.before(),self.hits([4,4,4],idx=1),2,2,False,0)
    def test_block_absorbed_sequentially(self):
        p.attack_hits(self.before(block=9),self.hits([0,0,3],blocked=[4,4,1]),2,2,False,0)
    def test_rounding_applied_per_hit_in_native_order(self):
        b=self.before();b['statuses']['weak']=1;b['targets'][0]['statuses']['vulnerable']=1
        p.attack_hits(b,self.hits([6,6,6]),3,3,False,0)
    def test_rounding_cannot_be_applied_once_to_sum(self):
        b=self.before();b['statuses']['weak']=1;b['targets'][0]['statuses']['vulnerable']=1
        with self.assertRaises(ValueError):p.attack_hits(b,self.hits([7,7,6]),3,3,False,0)
    def cfg(self):return {'family':'fervor','aspect':0,'vow':5,'up':False,'context':'plain','mask':0}
    def test_typed_config(self):p.strict_config(self.cfg())
    def test_integer_upgrade_not_boolean(self):
        c=self.cfg();c['up']=0
        with self.assertRaises(ValueError):p.strict_config(c)
    def test_boolean_mask_not_integer(self):
        c=self.cfg();c['mask']=False
        with self.assertRaises(ValueError):p.strict_config(c)
    def test_unknown_config_field_rejected(self):
        c=self.cfg();c['extra']=True
        with self.assertRaises(ValueError):p.strict_config(c)
    def test_overkill_not_extra_removed_health(self):
        step={'before':{'view':self.before(hp=3)},'after':{'view':self.before(hp=3)},'events':self.hits([10],hp=3)}
        step['after']['view']['targets'][0]['hp']=0
        self.assertEqual(v.hit_removed(step),{'removed':3,'nominal':10,'poison':0})
    def test_poison_unit_separate(self):
        step={'before':{'view':self.before()},'after':{'view':self.before()},'events':self.hits([8])}
        step['events'][0]['poison']=True;step['after']['view']['targets'][0]['hp']=92
        self.assertEqual(v.hit_removed(step),{'removed':8,'nominal':8,'poison':8})
    def test_missing_damage_event_rejected(self):
        step={'before':{'view':self.before()},'after':{'view':self.before()},'events':[]}
        step['after']['view']['targets'][0]['hp']=92
        with self.assertRaises(ValueError):v.hit_removed(step)
    def test_header_wrong_engine_rejected_before_rows(self):
        with self.assertRaises(ValueError):v.check_rows(iter([{'kind':'header','engine':'synthetic'}]),{})
    def test_distinguishing_one_bit_does_not_prove_novelty(self):
        # The complete old-system background can contain this same native law.
        native=lambda s,base,hits: hits*(base+s)
        self.assertEqual(native(2,2,3),12)
        old_background_plus_disabled_extra_bit=native
        self.assertEqual(old_background_plus_disabled_extra_bit(2,2,3),native(2,2,3))
    def test_two_role_bilinearity_not_an_hp_global_theorem(self):
        for base in range(4):
            for supply in range(4):
                for mult in (2,3):
                    self.assertEqual((base+supply)*mult-base*mult-(base+supply)+base,supply*(mult-1))
        self.assertNotEqual(min(3,12)-min(3,6)-min(3,8)+min(3,6),4)

if __name__=='__main__':unittest.main()
