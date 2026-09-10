import copy,unittest
import close_planner as c

def fixtures(total=3500,status='FIXED_OPTIMIZED_PLANNER_PAIR_SUPPORT_NOT_ESTABLISHED'):
    a={'configurations':32,'rows_per_method':128,'stock_wins':12,'planner_wins':86,'point_difference':74/128,
       'configuration_bootstrap_interval':[.48,.67],'gates':{'gain':True,'interval':True},'pass':True,
       'costs':{'stock':{'process_cpu_seconds':19.45},'planner':{'process_cpu_seconds':900}},'resource_ceiling_met':True}
    b={'configurations':96,'rows_per_method':384,'stock_wins':34,'planner_wins':258,'point_difference':224/384,
       'configuration_bootstrap_interval':[.52,.64],'gates':{'gain':True,'interval':True},'pass':True,
       'costs':{'stock':{'process_cpu_seconds':56.56},'planner':{'process_cpu_seconds':total-900}},'resource_ceiling_met':total<=3600}
    s={'value-screen':a,'reserved-configuration-check':b}
    if total<=3600:s.update(support={'stock':{'pass':False},'planner':{'pass':False}},support_pass=False)
    t={'status':status,'stages':{'5':s},'old_terminal_unchanged':True,'packages_admitted':0,'p9_certified':False}
    rb={'scientific_status':status,'reproduced_stages':['5'],'all_bytes_equal':True,'old_terminal_unchanged':True,
        'old_v5_replays_counted_as_independent':False,'files':1075,'original_v5_cells_reconciled':128}
    old={'status':'INCONCLUSIVE','failure':"ValueError('MATCHED_RESOURCE_CEILING')"}
    p={'unchanged_inputs':{'cpu_seconds_per_method_per_vow':3600}}
    return t,rb,old,p

class ClosureTests(unittest.TestCase):
    def test_full_cost_true_support_false_are_separate(self):
        d=c.summarize(*fixtures());self.assertTrue(d['stages']['5']['complete_resource_qualified'])
        self.assertFalse(d['stages']['5']['support_pass']);self.assertEqual(d['packages_admitted'],0)
        self.assertEqual(d['same_assignment_v5_replay_rows'],1024)
    def test_full_resource_negative_retained(self):
        d=c.summarize(*fixtures(4015.74,'IMPLEMENTATION_RESOURCE_REQUALIFICATION_FAIL'))
        self.assertFalse(d['stages']['5']['complete_resource_qualified'])
        self.assertFalse(d['stages']['5']['support_observed'])
    def test_exact3600_not_rounded(self):
        self.assertTrue(c.summarize(*fixtures(3600))['stages']['5']['complete_resource_qualified'])
        self.assertFalse(c.summarize(*fixtures(3600.01,'IMPLEMENTATION_RESOURCE_REQUALIFICATION_FAIL'))['stages']['5']['complete_resource_qualified'])
    def test_no_support_if_resources_failed(self):
        t,rb,old,p=fixtures(4000,'IMPLEMENTATION_RESOURCE_REQUALIFICATION_FAIL')
        t['stages']['5'].update(support={'planner':{'pass':True},'stock':{'pass':False}},support_pass=True)
        with self.assertRaises(ValueError):c.summarize(t,rb,old,p)
    def test_v0_cannot_open_after_support_failure(self):
        t,rb,old,p=fixtures();t['stages']['0']=copy.deepcopy(t['stages']['5']);rb['reproduced_stages']=['5','0']
        with self.assertRaises(ValueError):c.summarize(t,rb,old,p)
    def test_v5_only_not_complete_pass(self):
        t,rb,old,p=fixtures(status='OPTIMIZED_PLANNER_VALUE_AND_PAIR_SUPPORT_PASS_NOT_CERTIFICATE')
        t['stages']['5']['support']['planner']['pass']=True;t['stages']['5']['support_pass']=True
        with self.assertRaises(ValueError):c.summarize(t,rb,old,p)
    def test_write_request_not_readback(self):
        t,rb,old,p=fixtures();rb['all_bytes_equal']=False
        with self.assertRaises(ValueError):c.summarize(t,rb,old,p)
    def test_unchanged_old_terminal_required(self):
        t,rb,old,p=fixtures();old['status']='PASS'
        with self.assertRaises(ValueError):c.summarize(t,rb,old,p)
    def test_cost_must_include_both_blocks(self):
        t,rb,old,p=fixtures(4000,'IMPLEMENTATION_RESOURCE_REQUALIFICATION_FAIL');t['stages']['5']['reserved-configuration-check']['resource_ceiling_met']=True
        with self.assertRaises(ValueError):c.summarize(t,rb,old,p)
    def test_no_independent_samples_from_replay(self):
        t,rb,old,p=fixtures();rb['old_v5_replays_counted_as_independent']=True
        with self.assertRaises(ValueError):c.summarize(t,rb,old,p)
    def test_nonfinite_cost_rejected(self):
        t,rb,old,p=fixtures();t['stages']['5']['value-screen']['costs']['planner']['process_cpu_seconds']=float('nan')
        with self.assertRaises(ValueError):c.summarize(t,rb,old,p)
    def test_stale_fields_history_preserved(self):
        old={'status':'old','packages_admitted':0,'p9_certified':False,'raw_gap':{'remote':False},'closed':{'verdict':'FAIL'},'exact_next_action':'old'}
        d=c.summarize(*fixtures());new=c.updated_state(old,d)
        self.assertEqual(new['raw_gap'],old['raw_gap']);self.assertEqual(new['closed'],old['closed'])
        self.assertEqual(old['status'],'old');self.assertNotEqual(new['exact_next_action'],'old')

if __name__=='__main__':unittest.main()
