import tempfile,unittest
from pathlib import Path
import refinement as r

class IntegerRefinementTests(unittest.TestCase):
 def test_fastpath_is_bounded_integer_only(self):
  self.assertIn('typeof(v)==TYPE_INT',r.FAST)
  self.assertIn('integer>=-9007199254740991 and integer<=9007199254740991',r.FAST)
  self.assertIn('return super.ji(v)',r.FAST)
  self.assertNotIn('TYPE_FLOAT',r.FAST)
 def test_range_is_float64_integer_identity(self):
  for v in r.INPUTS:
   if type(v) is int and abs(v)<=2**53-1:self.assertEqual(int(float(str(v))),v)
 def test_unsafe_extension_has_counterexample(self):
  self.assertNotEqual(int(float(str(2**53+1))),2**53+1)
  self.assertIn(2**53+1,r.INPUTS)
  self.assertIn(-(2**53+1),r.INPUTS)
 def test_all_other_types_retain_reference_path(self):
  self.assertTrue(any(type(v) is float for v in r.INPUTS))
  self.assertTrue(any(type(v) is str for v in r.INPUTS))
  self.assertTrue(any(type(v) is int and abs(v)>2**53 for v in r.INPUTS))

if __name__=='__main__':unittest.main()
