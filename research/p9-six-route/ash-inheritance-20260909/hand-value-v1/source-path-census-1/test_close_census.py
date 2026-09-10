import copy
import unittest
import close_census as c

def data():
 r={'immutable_primary_terminal':'HAND_ADAPTIVE_GROUP_VALUE_NOT_ESTABLISHED','runs_read':2048,
    'observed_source_off_draw_leaks':0,'observed_source_off_provenance_leaks':0,'paired_responses':{},'worlds':{}}
 for w in ('00','01','10','11'):
  r['worlds'][w]={'runs':512,'totals':{'commands':1,'direct_source_draws':0,'either_source_path_plays':0,'phantom_plays':1,'retained_source_plays':0,'source_access_plays':0}}
 r['worlds']['11']['totals'].update(phantom_plays=1973,either_source_path_plays=168,retained_source_plays=158,source_access_plays=60)
 return r

class Tests(unittest.TestCase):
 def test_overlap_and_no_admission(self):
  d=c.decision(data());self.assertEqual(d['all_on_source_path_overlap'],50);self.assertEqual(d['packages_admitted'],0)
 def test_source_leak_rejected(self):
  r=data();r['worlds']['00']['totals']['direct_source_draws']=1
  with self.assertRaisesRegex(ValueError,'OFF_WORLD'):c.decision(r)
 def test_incomplete_data_rejected(self):
  r=data();r['worlds']['11']['runs']=511
  with self.assertRaisesRegex(ValueError,'WORLD_COVERAGE'):c.decision(r)
 def test_overlap_not_added_as_disjoint(self):
  r=data();r['worlds']['11']['totals']['either_source_path_plays']=219
  with self.assertRaisesRegex(ValueError,'UNION'):c.decision(r)
 def test_negative_not_relabelled_supported(self):
  r=data();r['immutable_primary_terminal']='PASS'
  with self.assertRaisesRegex(ValueError,'TERMINAL'):c.decision(r)
 def test_no_new_population_or_selected_candidate(self):
  d=c.decision(data());self.assertEqual(d['new_native_runs'],0);self.assertFalse(d['candidate_selected_or_admitted'])
  self.assertIn('floor_per',d['next_action']);self.assertIn('zero rows',d['next_action'])
if __name__=='__main__':unittest.main()
