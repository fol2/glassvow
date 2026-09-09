import copy,unittest
from close_native import decision,ROLE,EXPANSION,SURVIVE,INSUFFICIENT

def inputs():
    role={'status':ROLE,'failures':[],'counts':{'rows':1040}}
    expansion={'status':EXPANSION,'comparisons':[{'full_trace_equal':True} for _ in range(208)]}
    grids={}
    for name in ('duskblade-v5','ashwarden-v5','ashwarden-v0'):
        grids[name]={'status':INSUFFICIENT if name.startswith('dusk') else SURVIVE,
          'rows':512,'policies':128,'faults':[],'packages_admitted':0,'p9_certified':False,
          'potential_active_upper_bound':[],'reachable_upper_bound':[],'potential_viable_upper_bound':[],'outcomes':{}}
    return role,expansion,{'status':'FIXED_NATIVE_POLICY_CAPACITY_COMPLETE_NOT_ADMISSION','grids':grids}

class CloseTests(unittest.TestCase):
    def test_no_promotion(self):
        r=decision(*inputs());self.assertEqual(r['packages_admitted'],0);self.assertFalse(r['p9_certified']);self.assertFalse(r['full_closed_family_quotient_established'])
    def test_no_ignored_native_failure(self):
        a,b,c=inputs();a['failures']=['x']
        with self.assertRaises(ValueError):decision(a,b,c)
    def test_no_missing_expansion(self):
        a,b,c=inputs();b['comparisons'].pop()
        with self.assertRaises(ValueError):decision(a,b,c)
    def test_no_ignored_trace_difference(self):
        a,b,c=inputs();b['comparisons'][0]['full_trace_equal']=False
        with self.assertRaises(ValueError):decision(a,b,c)
    def test_no_conditional_dusk_v0(self):
        a,b,c=inputs();c['grids']['duskblade-v0']=copy.deepcopy(c['grids']['duskblade-v5'])
        with self.assertRaises(ValueError):decision(a,b,c)
    def test_no_forged_package(self):
        a,b,c=inputs();c['grids']['ashwarden-v0']['packages_admitted']=1
        with self.assertRaises(ValueError):decision(a,b,c)
    def test_fault_is_not_success(self):
        a,b,c=inputs();c['grids']['ashwarden-v0']['faults']=['bad']
        with self.assertRaises(ValueError):decision(a,b,c)
    def test_changed_terminal_not_silently_reclassified(self):
        a,b,c=inputs();c['grids']['ashwarden-v0']['status']=INSUFFICIENT
        with self.assertRaises(ValueError):decision(a,b,c)

if __name__=='__main__':unittest.main()
