import hashlib,tempfile,unittest
from pathlib import Path
import benchmark as b
class Tests(unittest.TestCase):
 def test_patch_rejects_unknown_evaluator(self):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d);(p/'greedy_policy.gd').write_text('unknown')
   with self.assertRaisesRegex(ValueError,'EXACT_EVALUATOR'):b.patch(p,b'wrapper')
 def test_no_unbound_cache_lifetime(self):
  source=(Path(__file__).parent/'greedy_policy.gd').read_text()
  self.assertIn('if _memo_game != g:',source)
  self.assertEqual(source.count('_memo_features = {}'),2)
  self.assertEqual(source.count('_memo_copies = {}'),2)
  self.assertIn('_memo_game = null',source)
  self.assertNotIn('.apply(',source)
  self.assertNotIn('random',source)
 def test_incomplete_capture_is_not_cost_pass(self):
  with tempfile.TemporaryDirectory() as d:
   with self.assertRaises(FileNotFoundError):b.readout(Path(d))
if __name__=='__main__':unittest.main(verbosity=2)
