import copy,json,lzma,tempfile,unittest
from pathlib import Path
import requalify as r

class ResourceProofTests(unittest.TestCase):
 def test_both_methods_both_phases_counted(self):
  old={'value-screen':{'costs':{'stock':{'process_cpu_seconds':20},'planner':{'process_cpu_seconds':963.05}}}}
  costs={'stock':{'process_cpu_seconds':56.56},'planner':{'process_cpu_seconds':3052.69}}
  self.assertFalse(r.resource_ok(costs,old))
  self.assertTrue(r.resource_ok(costs,{}))
 def test_boundary_not_rounded(self):
  costs={'stock':{'process_cpu_seconds':0},'planner':{'process_cpu_seconds':3600}}
  self.assertTrue(r.resource_ok(costs,{}))
  costs['planner']['process_cpu_seconds']=3600.0001
  self.assertFalse(r.resource_ok(costs,{}))
 def test_nonfinite_cost_rejected(self):
  for v in (float('nan'),float('inf'),-1):
   self.assertFalse(r.resource_ok({'stock':{'process_cpu_seconds':0},'planner':{'process_cpu_seconds':v}},{}))
 def test_stock_cost_not_silently_ignored(self):
  self.assertFalse(r.resource_ok({'stock':{'process_cpu_seconds':3601},'planner':{'process_cpu_seconds':2}},{}))
 def test_timing_not_native_data_is_ignored(self):
  class B:
   @staticmethod
   def canonical(data):
    rows=json.loads(data)
    rows.pop('run_usec');rows.pop('query_usec')
    return json.dumps(rows,sort_keys=True).encode()
  with tempfile.TemporaryDirectory() as t:
   old,new=Path(t)/'old',Path(t)/'new';old.mkdir();new.mkdir()
   x={'run_usec':1,'query_usec':2,'decision':7,'score':0.123,'unknown_future_observable':9}
   for folder in (old,new):
    (folder/'v5-000.outcomes.jsonl.xz').write_bytes(lzma.compress(json.dumps(x).encode()))
    (folder/'v5-000.traces.jsonl.xz').write_bytes(lzma.compress(b'COMPLETE_RAW'))
   y=dict(x,run_usec=999)
   (new/'v5-000.outcomes.jsonl.xz').write_bytes(lzma.compress(json.dumps(y).encode()))
   r.cell_equivalence(old,new,'v5-000',B)
   for key in ('decision','score','unknown_future_observable'):
    y=dict(x);y[key]=84
    (new/'v5-000.outcomes.jsonl.xz').write_bytes(lzma.compress(json.dumps(y).encode()))
    with self.assertRaises(ValueError):r.cell_equivalence(old,new,'v5-000',B)
   (new/'v5-000.outcomes.jsonl.xz').write_bytes(lzma.compress(json.dumps(x).encode()))
   (new/'v5-000.traces.jsonl.xz').write_bytes(lzma.compress(b'changed'))
   with self.assertRaises(ValueError):r.cell_equivalence(old,new,'v5-000',B)
 def test_no_old_terminal_write(self):
  s=Path(r.__file__).read_text()
  self.assertIn("(old/'TERMINAL.json').read_bytes()==old_terminal",s)
  self.assertNotIn("save(old/",s)
  self.assertIn("if method=='planner':bench.patch",s)
 def test_entry_requires_successful_exact_refinement(self):
  s=Path(r.__file__).read_text()
  self.assertIn("continuation-integer-v1/execution-1",s)
  self.assertIn("EXACT_CONTINUATION_CACHE_SPEEDUP_ESTABLISHED",s)
  self.assertIn("'CACHE_READBACK'",s)
 def test_v0_requires_v5_support_and_both_value_phases(self):
  s=Path(r.__file__).read_text()
  self.assertIn("require(prior.get('support_pass') is True,'V0_OPENED_WITHOUT_PASS')",s)
  self.assertIn("len(previous)==2,'SUPPORT_PRECONDITIONS'",s)

if __name__=='__main__':unittest.main()
