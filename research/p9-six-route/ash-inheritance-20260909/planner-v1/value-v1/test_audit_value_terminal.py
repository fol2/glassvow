import json,tempfile,unittest
from pathlib import Path
import audit_value_terminal as a
class Tests(unittest.TestCase):
 def test_cumulative_ceiling_does_not_reset_at_validation(self):
  totals={'stock':20.0,'planner':960.0}
  self.assertFalse(a.accumulate(totals,{'stock':{'process_cpu_seconds':60.0},'planner':{'process_cpu_seconds':2640.01}},3600))
  self.assertGreater(totals['planner'],3600)
 def test_exact_boundary_is_not_rounded(self):
  costs={'stock':{'process_cpu_seconds':3600.0},'planner':{'process_cpu_seconds':3600.0}}
  self.assertTrue(a.accumulate({'stock':0.0,'planner':0.0},costs,3600))
  costs['planner']['process_cpu_seconds']+=.001
  self.assertFalse(a.accumulate({'stock':0.0,'planner':0.0},costs,3600))
 def test_changed_budget_rejected(self):
  with self.assertRaisesRegex(ValueError,'FROZEN'):a.accumulate({}, {}, 4000)
 def test_negative_cost_rejected(self):
  with self.assertRaisesRegex(ValueError,'NONNEGATIVE'):a.accumulate({'stock':0,'planner':0},{'stock':{'process_cpu_seconds':-1}},3600)
 def test_missing_or_failed_cells_are_not_zero_outcomes(self):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)/'a.json';q=Path(d)/'b.json';p.write_text(json.dumps({'status':'COMPLETE'}))
   self.assertFalse(a.coverage([p,q])['complete'])
   q.write_text(json.dumps({'status':'INCONCLUSIVE','failure':'WATCHDOG'}))
   self.assertFalse(a.coverage([p,q])['complete'])
   self.assertEqual(len(a.coverage([p,q])['failed_receipts']),1)
 def test_paths_rejected(self):
  for s in ('','/raw','../raw','raw/../../x'):
   with self.assertRaises(ValueError):a.safe_relative(s)
if __name__=='__main__':unittest.main(verbosity=2)
