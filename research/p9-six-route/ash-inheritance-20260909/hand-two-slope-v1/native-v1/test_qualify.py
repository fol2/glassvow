import copy
import json
from pathlib import Path
import tempfile
import unittest
import qualify as q

P=json.loads((Path(__file__).parent/'PROTOCOL.json').read_bytes())


def fixture(role,a,v,u,h,x,on):
    nonlinear=role not in ('reference','linear')
    n=(7 if u else 6) if nonlinear else (4 if u else 3)
    raw=n*max(0,h-4)+2*min(h,4) if nonlinear else n*h
    if not on:raw=0
    fx={'kind':'special','id':'phantom','n':n if on else 0}
    if nonlinear:fx.update(reserve=4,floor_per=2 if on or role=='legacy-mask' else 0)
    actual=fx['n']*max(0,h-fx.get('reserve',0))+fx.get('floor_per',0)*min(h,fx.get('reserve',0))
    r={'key':f'{a}:{v}:{str(u).lower()}:{h}:{x}:{str(on).lower()}',
       'aspect':a,'vow':v,'q':h,'context':x,'active':on,'up':u,'data':{'effects':[fx]},
       'readonly':True,'catalogue_unchanged':True,'flags':[True,True,on],
       'exact_flags':[True,True,on],'public_flags':[True,True,on],
       'return':x!='no-energy','after':{},'exact_after':{},'events':[], 'exact_events':[],
       'expanded_after':{},'expanded_events':[],'actual_raw':actual,'expected_raw':raw,
       'score':1,'expanded_score':1,'draft':1,'expanded_draft':1}
    if role=='legacy-mask' and actual!=raw:
        r['expanded_after']={'different':True}
    if role=='legacy-query':r.update(score=99,draft=99)
    return r


def write(root,mutate=None):
    for role in q.ROLES:
        data=[]
        for a in (0,1):
            for v in (0,5):
                for u in (False,True):
                    for h in (0,4,5,6,9):
                        for x in P['cases']['contexts']:
                            for on in P['cases']['active'][role]:data.append(fixture(role,a,v,u,h,x,on))
        if mutate:mutate(role,data)
        data.append({'kind':'terminal','cases':P['expected_cases'][role]})
        (root/(role+'.jsonl')).write_text(''.join(json.dumps(r)+'\n' for r in data))


class Tests(unittest.TestCase):
 def run_fixture(self,mutate=None):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);write(root,mutate);return q.check(root,P)
 def test_complete_assignment_and_negative_controls(self):
  result=self.run_fixture();self.assertEqual(sum(result['cases'].values()),1960)
  self.assertEqual(result['mask_mutants_detected'],8);self.assertEqual(result['query_mutants_detected'],8)
  self.assertFalse(result['p9_certified'])
 def test_missing_case_rejected(self):
  def f(role,rows):
   if role=='candidate':rows.pop()
  with self.assertRaisesRegex(ValueError,'ASSIGNED_CASES'):self.run_fixture(f)
 def test_shared_wrong_oracle_rejected(self):
  def f(role,rows):
   if role=='candidate':rows[0]['actual_raw']=rows[0]['expected_raw']=100
  with self.assertRaisesRegex(ValueError,'SOURCE_LAW_ORACLE'):self.run_fixture(f)
 def test_wrong_resolved_mask_rejected(self):
  def f(role,rows):
   if role=='candidate':rows[0]['data']['effects'][0]['floor_per']=2
  with self.assertRaisesRegex(ValueError,'RESOLVED_EFFECT_VIEW'):self.run_fixture(f)
 def test_clone_loses_mask_rejected(self):
  def f(role,rows):
   if role=='candidate':rows[0]['public_flags']=[True,True,True]
  with self.assertRaisesRegex(ValueError,'CLONE_FLAGS'):self.run_fixture(f)
 def test_native_expansion_mismatch_rejected(self):
  def f(role,rows):
   if role=='candidate':rows[0]['expanded_after']={'lost':1}
  with self.assertRaisesRegex(ValueError,'NATIVE_ENVELOPE'):self.run_fixture(f)
 def test_default_control_drift_rejected(self):
  def f(role,rows):
   if role=='reference':rows[0]['extra']='forbidden drift'
  with self.assertRaisesRegex(ValueError,'DEFAULT_ON_FULL_ROW_PARITY'):self.run_fixture(f)
 def test_query_mutant_must_be_detected(self):
  def f(role,rows):
   if role=='legacy-query':
    for r in rows:r['score']=r['expanded_score'];r['draft']=r['expanded_draft']
  with self.assertRaisesRegex(ValueError,'QUERY_MUTANT_NOT_DETECTED'):self.run_fixture(f)
 def test_query_patch_only_two_exact_expressions(self):
  x='elif sid=="phantom":raw*=maxi(0,g.cb.hand.size()-1)\n"phantom":n*4.0'
  y=q.repair_query(x);self.assertIn('_hand_two_slope_raw',y)
  with self.assertRaises(ValueError):q.repair_query(y)
 def test_mask_patch_and_anchor_rejection(self):
  x='\t\t\teffect["n"] = 0\n';self.assertIn('effect["floor_per"] = 0',q.repair_mask(x))
  with self.assertRaises(ValueError):q.repair_mask(x+x)

if __name__=='__main__':unittest.main()
