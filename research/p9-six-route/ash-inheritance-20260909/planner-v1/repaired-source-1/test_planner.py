import copy
import tempfile
import unittest
from pathlib import Path
import bind
import read

class Tests(unittest.TestCase):
 def test_frame_keeps_mediator_and_energy(self):
  a={'run':{'seed':1,'run_id':'a','rng':{'state':1}},'combat':{'draw':[],'queue':[], 'player':{'energy':2,'statuses':{'bloodfire':1}}}}
  b=copy.deepcopy(a);b['run']['seed']=99;b['run']['rng']['state']=50
  self.assertEqual(read.frame(a),read.frame(b))
  b['combat']['player']['statuses']['bloodfire']=0
  self.assertNotEqual(read.frame(a),read.frame(b))
 def test_unknown_public_field_not_erased(self):
  a={'run':{},'combat':{'draw':[],'queue':[],'future_mediator':1}}
  b=copy.deepcopy(a);b['combat']['future_mediator']=2
  self.assertNotEqual(read.frame(a),read.frame(b))
 def test_patch_anchor_fails_closed(self):
  with self.assertRaises(ValueError):bind.once('x x','x','y')
 def test_incomplete_capture_is_not_pass(self):
  with tempfile.TemporaryDirectory() as path:
   with self.assertRaises(ValueError):read.analyze(Path(path),{})
 def test_independent_checks_retain_fatal_choice_and_flag_loss(self):
  state={'run':{},'combat':{'draw':[],'queue':[]},'return':True}
  action={'t':'playCard','uid':100}
  row={'pattern':2,'decision':{'action':action,'legal_candidates':[action],'root_rollouts':1},
   'permuted_decision':{},'before':state,'after_query':state,'permuted_before':state,'permuted_after':state,
   'clone_before':state,'clone_after':state,'clone_hidden':state,'flags':{'bloodfire_enabled':False},'clone_flags':{'bloodfire_enabled':True},
   'content_before':'a','content_after':'a','flags_before':{},'flags_after':{}}
  r=read.independently_check(row)
  self.assertFalse(r['does_not_choose_known_fatal_source']);self.assertFalse(r['intervention_flags_retained'])
  self.assertFalse(r['fixed_two_samples'])

if __name__=='__main__':unittest.main()
