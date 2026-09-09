"""Synthetic boundary and source-transform tests, not simulator observations."""
import copy,unittest
import read,run

def cells(potential=32,reachable=16,viable=16):
    rows=[]
    for i in range(128):
        for seed in range(73209100,73209104):
            rows.append({'policy_index':i,'policy_sha256':str(i),'seed':seed,
                         'outcome':'win' if i<viable else 'loss','error':'',
                         'potential_chain':i<potential,'pair_seen':i<reachable,
                         'consumer_played':True})
    return [{'config':read.config('duskblade',5,0,128),'rows':rows,'policy_manifest_sha256':'synthetic'}]

class CapacityTests(unittest.TestCase):
    def test_bounds_do_not_admit(self):
        x=read.aggregate(cells());self.assertEqual(x['status'],'NATIVE_POLICY_CAPACITY_NOT_FALSIFIED_NOT_ADMISSION')
        self.assertEqual(x['packages_admitted'],0);self.assertFalse(x['p9_certified'])
    def test_insufficient_potential(self):
        self.assertEqual(read.aggregate(cells(potential=31))['status'],'FIXED_NATIVE_POLICY_FAMILY_INSUFFICIENT_UPPER_BOUND')
    def test_insufficient_viable_upper_bound(self):
        self.assertFalse(read.aggregate(cells(viable=15))['gates']['potential_viable_upper_bound_at_least16'])
    def test_insufficient_reachability(self):
        self.assertFalse(read.aggregate(cells(reachable=15))['gates']['reachable_upper_bound_at_least16'])
    def test_high_wins_do_not_override_capacity(self):
        self.assertEqual(read.aggregate(cells(potential=0,viable=128))['outcomes']['win'],512)
        self.assertFalse(read.aggregate(cells(potential=0,viable=128))['gates']['potential_active_upper_bound_at_least32'])
    def test_extra_seed_forbidden(self):
        c=cells();c[0]['rows'][0]['seed']+=100
        with self.assertRaises(ValueError):read.aggregate(c)
    def test_missing_row(self):
        c=cells();c[0]['rows'].pop()
        with self.assertRaises(ValueError):read.aggregate(c)
    def test_duplicate_row(self):
        c=cells();c[0]['rows'][-1]=copy.deepcopy(c[0]['rows'][0])
        with self.assertRaises(ValueError):read.aggregate(c)
    def test_fault_is_inconclusive_not_pass(self):
        c=cells();c[0]['rows'][0]['outcome']='stall'
        self.assertEqual(read.aggregate(c)['status'],'NATIVE_POLICY_CAPACITY_INCONCLUSIVE_FAULTS')
    def test_configurations_not_seed_pseudoreplication(self):
        x=read.aggregate(cells());self.assertEqual(len(x['potential_active_upper_bound']),32)
    def test_smoke_is_outside_assignment(self):
        a=read.config('duskblade',5,0,1,True,True);self.assertNotIn(a['seed0'],range(73209100,73209104))
    def test_only_two_source_replacements(self):
        s='class_name BalanceSim\nvar game: GlassvowGame = GlassvowGame.new(content, run)\n# unchanged\n'
        r=run.transform(s);self.assertIn('# unchanged',r);self.assertNotIn('class_name BalanceSim',r)
    def test_changed_constructor_rejected(self):
        with self.assertRaises(ValueError):run.transform('class_name BalanceSim\nvar game = different()')

if __name__=='__main__':unittest.main()
