import json,unittest
import profile as p
class Tests(unittest.TestCase):
 def data(self,x=1,cost=3):
  return ('\n'.join(json.dumps(r) for r in [{'kind':'header','probe_sha256':'a'},{'kind':'outcome','run_usec':cost,'query_usec':cost,'value':x},{'kind':'terminal'}])+'\n').encode()
 def test_only_timing_removed(self):
  self.assertEqual(p.canonical_records(self.data(cost=3),'a'),p.canonical_records(self.data(cost=8),'a'))
  self.assertNotEqual(p.canonical_records(self.data(x=1),'a'),p.canonical_records(self.data(x=2),'a'))
 def test_wrong_driver_fails(self):
  with self.assertRaisesRegex(ValueError,'BOUND'):p.canonical_records(self.data(),'b')
 def test_anchor_is_exact(self):
  with self.assertRaises(ValueError):p.once('x x','x','y')
if __name__=='__main__':unittest.main(verbosity=2)
