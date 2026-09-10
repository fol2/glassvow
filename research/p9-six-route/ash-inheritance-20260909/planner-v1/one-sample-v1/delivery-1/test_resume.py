import unittest
import resume

class RepairTests(unittest.TestCase):
 def test_actual_record_without_unemitted_alternatives(self):
  d={'readonly':True,'root_rollouts':1,'best':{'action':{'t':'endTurn'},'value':0},'action':{},'turn':1}
  self.assertFalse(eval(resume.BAD,{'d':d}))
  self.assertTrue(eval(resume.GOOD,{'d':d}))
 def test_reject_noninteger_boolean_or_empty_rollout(self):
  for n in (0,-1,True,1.5,'1'):
   self.assertFalse(eval(resume.GOOD,{'d':{'root_rollouts':n}}))
 def test_multiple_legal_candidates_do_not_require_missing_list(self):
  self.assertTrue(eval(resume.GOOD,{'d':{'root_rollouts':7,'best':{}}}))
 def test_only_known_consumer_expression_changes(self):
  source='before\n'+resume.BAD+'\nafter\n'
  self.assertEqual(resume.fixed_reader(source).replace(resume.GOOD,resume.BAD),source)
 def test_missing_or_duplicate_mistake_fails_closed(self):
  for s in ('correct already',resume.BAD+resume.BAD):
   with self.assertRaises(ValueError):resume.fixed_reader(s)

if __name__=='__main__':unittest.main(verbosity=2)
