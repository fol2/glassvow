from copy import deepcopy
import unittest
from close_decision import screen, FAIL

class Tests(unittest.TestCase):
    def result(self):
        grids=[]
        for aspect,vow in [('duskblade',0),('duskblade',5),('ashwarden',0),('ashwarden',5)]:
            b,c=(15,28) if (aspect,vow)==('ashwarden',0) else (20,20)
            grids.append({'aspect':aspect,'vow':vow,'n':128,'baseline_wins':b,'candidate_wins':c,
                'difference':(c-b)/128,'baseline_faults':0,'gates':{
                'candidate_random_build_at_most_half':True,
                'absolute_random_build_movement_at_most_tenth':10*abs(c-b)<=128,
                'candidate_fault_free':True}})
        return {'status':FAIL,'rows':1024,'p9_certified':False,'packages_admitted':0,'grids':grids}
    def test_thirteen_is_failure_not_rounded_twelve(self):
        r=screen(self.result());self.assertEqual(r[0]['difference'],13/128)
    def test_no_posthoc_interval_override(self):
        r=self.result();r['grids'][2]['nominal_paired_interval_report_only']=[-.1,.1]
        self.assertEqual(len(screen(r)),1)
    def test_forged_gate_rejected(self):
        r=self.result();r['grids'][2]['gates']['absolute_random_build_movement_at_most_tenth']=True
        with self.assertRaises(ValueError):screen(r)
    def test_no_package_from_counter_screen(self):
        r=self.result();r['packages_admitted']=1
        with self.assertRaises(ValueError):screen(r)
    def test_no_p9_pass_from_counter_screen(self):
        r=self.result();r['p9_certified']=True
        with self.assertRaises(ValueError):screen(r)
    def test_missing_grid_rejected(self):
        r=self.result();r['grids'].pop()
        with self.assertRaises(ValueError):screen(r)
    def test_wrong_denominator_rejected(self):
        r=self.result();r['grids'][2]['n']=256
        with self.assertRaises(ValueError):screen(r)
    def test_float_counts_rejected(self):
        r=self.result();r['grids'][2]['candidate_wins']=28.0
        with self.assertRaises(ValueError):screen(r)
    def test_no_source_mutation(self):
        r=self.result();copy=deepcopy(r);screen(r);self.assertEqual(r,copy)

if __name__=='__main__':unittest.main()
