import copy,unittest
from read_value import compare,validate_extra
class Tests(unittest.TestCase):
 def rows(self,wins):
  return [{'index':i,'seed':s,'policy':{'i':i},'row':{'outcome':'win' if wins else 'loss'}} for i in range(32) for s in [1,2,3,4]]
 def test_positive_and_null_are_distinct(self):
  a=self.rows(False);b=self.rows(True)
  self.assertTrue(compare(a,b,0,32,[1,2,3,4])['pass'])
  self.assertFalse(compare(a,a,0,32,[1,2,3,4])['pass'])
 def test_incomplete_not_negative(self):
  with self.assertRaisesRegex(ValueError,'RECTANGLE'):compare(self.rows(False)[:-1],self.rows(True),0,32,[1,2,3,4])
 def test_changed_configuration_rejected(self):
  a=self.rows(False);b=self.rows(True);b[0]['policy']={}
  with self.assertRaisesRegex(ValueError,'CONFIGURATION'):compare(a,b,0,32,[1,2,3,4])
 def test_fault_not_loss(self):
  a=self.rows(False);b=self.rows(True);b[0]['row']['outcome']='stall'
  with self.assertRaisesRegex(ValueError,'FAULT'):compare(a,b,0,32,[1,2,3,4])
 def test_stock_never_gets_planner(self):
  x={'method':'stock','faults':[],'run_usec':1,'query_usec':0,'query_count':1,'root_rollouts':2,'decisions':[]}
  with self.assertRaisesRegex(ValueError,'DISPATCH'):validate_extra([x],'stock')
 def test_mutating_query_rejected(self):
  x={'method':'planner','faults':[],'run_usec':1,'query_usec':0,'query_count':1,'root_rollouts':2,'decisions':[{'readonly':False,'root_rollouts':2}]}
  with self.assertRaisesRegex(ValueError,'ISOLATION'):validate_extra([x],'planner')
if __name__=='__main__':unittest.main(verbosity=2)
