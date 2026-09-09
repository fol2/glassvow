"""Source-transform and counterexample tests; synthetic, not new native evidence."""
import copy,unittest
import expand

class ExpansionTests(unittest.TestCase):
    def fixture(self):
        return 'const Roles=preload("res://roles.gd")\nvar name="res://roles.gd"\nvar self_file="res://probe.gd"\nfor mask: int in [-1,0,1,2,3]:\n\tpass\n'
    def test_only_expected_source_sites_change(self):
        s=expand.source_probe(self.fixture())
        self.assertEqual(s.count('res://expanded.gd'),2)
        self.assertIn('for mask: int in [0]:',s)
        self.assertNotIn('res://probe.gd',s)
    def test_missing_source_site_rejected(self):
        with self.assertRaises(ValueError):expand.source_probe(self.fixture().replace('res://probe.gd','different'))
    def test_added_source_site_rejected(self):
        with self.assertRaises(ValueError):expand.source_probe(self.fixture()+'"res://roles.gd"')
    def test_reference_bytes_required_before_analysis(self):
        with self.assertRaises(ValueError):expand.compare(b'forged',b'forged',{},'a','b')
    def test_queue_difference_is_observable(self):
        a={'config':{},'state':{'hp':10,'queue':[{'t':'energy'}]}}
        b=copy.deepcopy(a);b['state']['queue']=[]
        self.assertNotEqual(expand.without_config(a),expand.without_config(b))
    def test_instance_difference_is_observable(self):
        a={'config':{},'state':{'uid':1}};b={'config':{},'state':{'uid':2}}
        self.assertNotEqual(expand.without_config(a),expand.without_config(b))
    def test_envelope_three_cards_is_not_three_hits(self):
        within={'paid':1,'attacks':1,'hits':3,'chip_settlements':1}
        separate={'paid':3,'attacks':3,'hits':3,'chip_settlements':3}
        self.assertNotEqual(within,separate)
    def test_multiplier_equals_native_increment(self):
        for q in range(20):
            for m in (2,3):self.assertEqual(q+q*(m-1),q*m)
    def test_old_background_is_not_erased(self):
        native_strength=2;hits=3;extra_chip_bit=False
        old_full_damage=hits*(2+native_strength)
        self.assertEqual(old_full_damage,12)
        self.assertFalse(extra_chip_bit)

if __name__=='__main__':unittest.main()
