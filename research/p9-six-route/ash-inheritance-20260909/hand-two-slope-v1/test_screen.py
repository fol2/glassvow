import unittest
import screen as s

class Tests(unittest.TestCase):
 def test_native_default_identity(self):
  for n in (0,3,4,6,7):
   for q in range(1001):self.assertEqual(s.law(q,{'n':n}),n*q)
 def test_legacy_off_is_not_null(self):
  self.assertEqual(s.law(4,{'n':0,'reserve':4,'floor_per':2}),8)
 def test_corrected_off_preserves_other_fields(self):
  fx={'n':6,'reserve':4,'floor_per':2,'future_field':9};off=s.consumer_off(fx)
  self.assertEqual(fx['n'],6);self.assertEqual(off['future_field'],9);self.assertEqual(off['reserve'],4)
  for q in range(10):self.assertEqual(s.law(q,off),0)
 def test_two_slopes_and_exact_boundary(self):
  fx=s.PARAMETERS[False]
  self.assertEqual([s.law(q,fx) for q in (3,4,5,6,9)],[6,8,14,20,38])
 def test_upgrade_crossovers_not_assumed_equal(self):
  rows=s.equations()
  self.assertEqual([r['remaining_hand'] for r in rows if not r['upgraded'] and r['difference']>0],[6,7,8,9])
  self.assertEqual([r['remaining_hand'] for r in rows if r['upgraded'] and r['difference']>0],[7,8,9])
 def test_input_scope_rejected(self):
  for q in (-1,True,2.0):
   with self.assertRaises(ValueError):s.law(q,{'n':3})
  with self.assertRaises(ValueError):s.build(b'{}',b'')
 def test_raw_projection_incompatibility(self):
  self.assertNotEqual(6*4,s.law(4,s.PARAMETERS[False]))
 def test_parameter_source_is_not_search(self):
  self.assertEqual(s.PARAMETERS,{False:{'n':6,'reserve':4,'floor_per':2},True:{'n':7,'reserve':4,'floor_per':2}})

if __name__=='__main__':unittest.main()
