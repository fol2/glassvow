import copy
import unittest
import mechanism_readout as m


def ids(hand):
    values=[x['uid'] for x in hand]
    m.require(len(set(values))==len(values),'DUPLICATE_INSTANCE')
    return values


def record(q,up=False):
    return {'before':{'hand':[{'uid':1,'up':up}]+[{'uid':i+2,'up':False} for i in range(q)]},'command':{'uid':1}}


class Tests(unittest.TestCase):
    def test_raw_law_values(self):
        self.assertEqual([m.payoff(q,False,True) for q in (0,3,4,5,6,9)],[0,6,8,14,20,38])
        self.assertEqual([m.payoff(q,True,True) for q in (0,3,4,5,6,9)],[0,6,8,15,22,43])
    def test_entire_consumer_off_is_zero(self):
        for up in (False,True):
            for q in range(11):self.assertEqual(m.payoff(q,up,False),0)
    def test_below_and_above_threshold_are_distinct(self):
        for q,expected in ((4,2),(5,6),(6,6)):
            fields=m.consumer_fields(record(q),{2:'preparation'},True,ids)
            self.assertEqual(fields['structural_source_slot_deletion'],expected)
            self.assertEqual(fields['above_reserve'],q>4)
    def test_multiple_sources_crossing_threshold(self):
        f=m.consumer_fields(record(6,True),{2:'preparation',3:'surge'},True,ids)
        self.assertEqual(f['retained_direct_source_instances'],{'preparation':1,'surge':1})
        self.assertEqual(f['structural_source_slot_deletion'],14)
    def test_access_only_is_not_retained_other_slot(self):
        f=m.consumer_fields(record(6),{1:'preparation'},True,ids)
        self.assertIs(f['source_drew_consumer'],True)
        self.assertEqual(f['structural_source_slot_deletion'],0)
    def test_overlapping_access_and_other_are_not_same_count(self):
        f=m.consumer_fields(record(6),{1:'surge',2:'preparation'},True,ids)
        self.assertTrue(f['source_drew_consumer'])
        self.assertEqual(sum(f['retained_direct_source_instances'].values()),1)
    def test_background_draw_not_a_direct_source(self):
        f=m.consumer_fields(record(6),{1:'background',2:'background'},True,ids)
        self.assertFalse(f['source_drew_consumer']);self.assertEqual(f['structural_source_slot_deletion'],0)
    def test_payoff_off_with_retained_origin(self):
        f=m.consumer_fields(record(7),{2:'preparation',3:'surge'},False,ids)
        self.assertEqual(f['structural_raw'],0);self.assertEqual(f['structural_source_slot_deletion'],0)
    def test_uid_renaming(self):
        a=record(5);b=copy.deepcopy(a)
        for x in b['before']['hand']:x['uid']+=1000
        b['command']['uid']+=1000
        self.assertEqual(m.consumer_fields(a,{1:'surge',2:'preparation'},True,ids),
                         m.consumer_fields(b,{1001:'surge',1002:'preparation'},True,ids))
    def test_missing_and_duplicate_consumer_fail(self):
        x=record(2);x['command']['uid']=100
        with self.assertRaisesRegex(ValueError,'CONSUMER_INSTANCE'):m.consumer_fields(x,{},True,ids)
        x=record(2);x['before']['hand'][1]['uid']=1
        with self.assertRaisesRegex(ValueError,'DUPLICATE_INSTANCE'):m.consumer_fields(x,{},True,ids)
    def test_no_implicit_upgrade_coercion(self):
        with self.assertRaisesRegex(ValueError,'UPGRADE_TYPE'):m.consumer_fields(record(3,'false'),{},True,ids)
    def test_assignment_is_exact_disjoint_vows(self):
        c={'assignment':{'policies':128,'policies_per_cell':2,'seeds_per_cell':4,'seed_base':73830100,'seed_vow_stride':1000}}
        a=m.assigned(c,5);b=m.assigned(c,0)
        aa=set().union(*a.values());bb=set().union(*b.values())
        self.assertEqual(len(aa),512);self.assertEqual(len(bb),512);self.assertFalse(aa&bb)
    def test_law_type_checks(self):
        for q in (-1,False,3.):
            with self.assertRaisesRegex(ValueError,'LAW_TYPES'):m.payoff(q,False,True)


if __name__=='__main__':unittest.main()
