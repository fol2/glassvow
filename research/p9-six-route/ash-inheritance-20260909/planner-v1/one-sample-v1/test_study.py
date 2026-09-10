import pathlib,tempfile,unittest,json
import study

class SourceTests(unittest.TestCase):
 def test_only_sample_parameter_changes(self):
  old='planner.params={"rollout_samples":2,"rollout_steps":12,"leaf_terminal":false}\n'
  new=study.convert('combat_bridge.gd',old)
  self.assertEqual(new.replace('"rollout_samples":1','"rollout_samples":2'),old)
 def test_missing_or_duplicate_parameter_rejected(self):
  for old in ('no sample','"rollout_samples":2,"rollout_samples":2'):
   with self.assertRaisesRegex(ValueError,'ANCHOR'):study.convert('combat_bridge.gd',old)
 def test_statistics_not_rewritten(self):
  old="def compare(a,b):\n return 20*(b-a)>=128\ndef validate_extra(rows,method):\n return d['root_rollouts']>=2 and d['root_rollouts']%2==0\n"
  new=study.convert('read_value.py',old)
  self.assertEqual(study.comparison_body(old),study.comparison_body(new))
  self.assertIn("d['root_rollouts']==len(d['alternatives'])",new)
 def test_actual_count_not_merely_positive(self):
  old="d['root_rollouts']>=2 and d['root_rollouts']%2==0"
  condition=study.convert('read_value.py',old)
  self.assertFalse(eval(condition,{'d':{'root_rollouts':2,'alternatives':[{}]}}))
  self.assertFalse(eval(condition,{'d':{'root_rollouts':0,'alternatives':[]}}))
  self.assertTrue(eval(condition,{'d':{'root_rollouts':1,'alternatives':[{}]}}))
 def test_gate_and_parser_define_same_budget(self):
  gate='"rollout_samples":2 "fixed_two_samples" normal.legal_candidates.size()*2'
  parsed=study.convert('decision_gate.gd',gate)
  self.assertNotIn('fixed_two_samples',parsed)
  self.assertNotIn('*2',parsed)
 def test_seed_collision_checks_nested_metadata(self):
  with tempfile.TemporaryDirectory() as d:
   root=pathlib.Path(d);p=root/'research/p9-six-route/old';p.mkdir(parents=True)
   (p/'used.config.json').write_text(json.dumps({'nested':{'seeds':[73412100]}}))
   with self.assertRaisesRegex(ValueError,'SEED_COLLISION'):
    study.seed_check(root,root/'own',[73412100])
 def test_seed_check_excludes_only_own_study(self):
  with tempfile.TemporaryDirectory() as d:
   root=pathlib.Path(d);own=root/'research/p9-six-route/own';own.mkdir(parents=True)
   (own/'future.config.json').write_text(json.dumps({'seeds':[73412100]}))
   r=study.seed_check(root,own,[73412100]);self.assertEqual(r['retained_config_files_checked'],0)
 def test_passthrough_source_identity(self):
  self.assertEqual(study.convert('experiment.py','keep all logic\n'),'keep all logic\n')

if __name__=='__main__':unittest.main(verbosity=2)
