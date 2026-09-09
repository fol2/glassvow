import copy, unittest
from close_scope import evidence_decision

class CloseTest(unittest.TestCase):
    def setUp(self):
        self.source={'status':'EXACT_MISTBOUND_EXTENSION_AND_SHARED_NATIVE_KERNEL_SEPARATED',
                     'disposition':{'complete_formal_package_admission':'NOT_ESTABLISHED'}}
        self.frame={'status':'UNQUALIFIED_COMMON_BACKGROUND_EQUIVALENCE_REFUTED'}
        self.trace={'kind':'RETAINED_TRACE_SOURCE_ATTRIBUTION_NOT_CERTIFICATION','grids':[]}
        for vow in [5,0]:
            self.trace['grids'].append({'vow':vow,'rows':512,'policies':128,
                'packages_admitted':0,'p9_certified':False,'new_native_runs':0,'new_independent_samples':0,
                'old_potential_policies':list(range(80)),'source_attributed_possible_policies':list(range(70)),
                'winning_possible_policies':list(range(20)),'clean_direct_stock_witness_policies':[],
                'direct_witnesses':0,'status':'SOURCE_ATTRIBUTED_CAPACITY_NOT_FALSIFIED_NOT_ADMISSION'})
    def test_no_promotion_from_capacity(self):
        d=evidence_decision(self.source,self.trace,self.frame)
        self.assertFalse(d['open_new_population_confirmation']); self.assertFalse(d['p9_certified'])
        self.assertEqual(d['packages_admitted'],0)
    def test_even_clean_witnesses_are_not_admission(self):
        self.trace['grids'][0]['clean_direct_stock_witness_policies']=list(range(40))
        self.trace['grids'][0]['direct_witnesses']=40
        self.assertFalse(evidence_decision(self.source,self.trace,self.frame)['open_new_population_confirmation'])
    def test_formal_label_promotion_is_rejected(self):
        self.source['disposition']['complete_formal_package_admission']='PASS'
        with self.assertRaisesRegex(ValueError,'FORMAL_ADMISSION'):
            evidence_decision(self.source,self.trace,self.frame)
    def test_incomplete_rectangle_rejected(self):
        self.trace['grids'][0]['rows']=511
        with self.assertRaisesRegex(ValueError,'RECTANGLE'):
            evidence_decision(self.source,self.trace,self.frame)
    def test_missing_vow_rejected(self):
        self.trace['grids'].pop()
        with self.assertRaisesRegex(ValueError,'VOW_RECTANGLE'):
            evidence_decision(self.source,self.trace,self.frame)
    def test_new_sample_claim_rejected(self):
        self.trace['grids'][0]['new_independent_samples']=1
        with self.assertRaisesRegex(ValueError,'REUSE_ONLY'):
            evidence_decision(self.source,self.trace,self.frame)
    def test_bad_frame_rejected(self):
        with self.assertRaisesRegex(ValueError,'FRAME_TERMINAL'):
            evidence_decision(self.source,self.trace,{'status':'UNKNOWN'})
    def test_inputs_unmodified(self):
        before=copy.deepcopy((self.source,self.trace,self.frame))
        evidence_decision(self.source,self.trace,self.frame)
        self.assertEqual(before,(self.source,self.trace,self.frame))

if __name__=='__main__':unittest.main()
