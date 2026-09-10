"""Synthetic regressions for source-bound oracle correction, not game samples."""
import copy
import unittest
import repair as r


def fixture(nonlinear=True,on=True,up=False,q=4,context='plain'):
    coefficient=(7 if up else 6) if nonlinear else (4 if up else 3)
    fx={'kind':'special','id':'phantom','n':coefficient if on else 0}
    if nonlinear:fx.update(reserve=4,floor_per=2 if on else 0)
    return {'key':f'0:0:{str(up).lower()}:{q}:{context}:{str(on).lower()}',
        'aspect':0,'vow':0,'up':up,'q':q,'context':context,'active':on,
        'readonly':True,'catalogue_unchanged':True,'flags':[True,True,on],
        'exact_flags':[True,True,on],'public_flags':[True,True,on],
        'return':context!='no-energy','after':{'synthetic':1},'exact_after':{'synthetic':1},'expanded_after':{'synthetic':1},
        'events':[],'exact_events':[],'expanded_events':[],
        'expected_raw':r.raw(q,up,nonlinear,on),'actual_raw':r.raw(q,up,nonlinear,on),
        'data':{'cost':1,'effects':[fx]},'score':1.,'expanded_score':1.,
        'draft':r.raw(3,up,nonlinear,on)-2,'expanded_draft':r.raw(4,up,nonlinear,on)-2}


class Tests(unittest.TestCase):
    def test_piecewise_boundaries(self):
        self.assertEqual([r.raw(q,False,True) for q in (0,4,5,6,9)],[0,8,14,20,38])
        self.assertEqual([r.raw(q,True,True) for q in (0,4,5,6,9)],[0,8,15,22,43])

    def test_off_and_linear_laws(self):
        for up in (False,True):
            for q in range(11):
                self.assertEqual(r.raw(q,up,True,False),0)
                self.assertEqual(r.raw(q,up,False),(4 if up else 3)*q)

    def test_actual_forecast_not_fixed_four(self):
        self.assertEqual(r.draft(fixture(False),False),7)
        self.assertEqual(r.draft(fixture(False,up=True),False),10)
        self.assertEqual(r.draft(fixture(),True),4)
        self.assertEqual(r.draft(fixture(up=True),True),4)

    def test_both_query_conventions_are_retained_not_equalized(self):
        f=fixture();r.basic(f,True)
        self.assertEqual((f['draft'],f['expanded_draft']),(4,6))
        f=fixture(False);r.basic(f,False)
        self.assertEqual((f['draft'],f['expanded_draft']),(7,10))

    def test_bad_double_subtraction_not_accepted(self):
        for up,wrong in ((False,-12),(True,-16)):
            f=fixture(up=up);f['draft']=wrong
            with self.assertRaisesRegex(ValueError,'FULL_INHERITED_DRAFT'):r.basic(f,True)

    def test_force_q4_forecast_not_accepted(self):
        f=fixture();f['draft']=f['expanded_draft']
        with self.assertRaisesRegex(ValueError,'FULL_INHERITED_DRAFT'):r.basic(f,True)

    def test_mutant_floor_not_silently_erased(self):
        f=fixture(on=False);f['data']['effects'][0]['floor_per']=2
        with self.assertRaisesRegex(ValueError,'RESOLVED_EFFECT'):r.basic(f,True)

    def test_catalogue_or_clone_mutation_rejected(self):
        for key in ('readonly','catalogue_unchanged'):
            f=fixture();f[key]=False
            with self.assertRaisesRegex(ValueError,'QUERY_MUTATION'):r.basic(f,True)
        f=fixture();f['exact_after']={'synthetic':2}
        with self.assertRaisesRegex(ValueError,'EXACT_CLONE'):r.basic(f,True)

    def test_native_envelope_mismatch_rejected(self):
        f=fixture();f['expanded_events']=[{'synthetic':1}]
        with self.assertRaisesRegex(ValueError,'NATIVE_ENVELOPE'):r.basic(f,True)

    def test_readonly_flags_preserve_source(self):
        for key in ('flags','public_flags','exact_flags'):
            f=fixture(on=False);f[key]=[False,True,False]
            with self.assertRaisesRegex(ValueError,'FLAGS'):r.basic(f,True)

    def test_illegal_command_not_promoted(self):
        f=fixture(context='no-energy');r.basic(f,True)
        f['return']=True
        with self.assertRaisesRegex(ValueError,'LEGALITY'):r.basic(f,True)

    def test_zero_raw_score_scope_not_extended(self):
        f=fixture(False,q=0);f['score']=0.;f['expanded_score']=2.7
        r.basic(f,False)
        f=fixture(q=4);f['score']=0.
        with self.assertRaisesRegex(ValueError,'POSITIVE_RAW_SCORE'):r.basic(f,True)

    def test_no_rounded_equality(self):
        f=fixture();f['draft']+=1e-12
        with self.assertRaisesRegex(ValueError,'FULL_INHERITED_DRAFT'):r.basic(f,True)

    def test_assignment_and_types(self):
        self.assertEqual(len(r.keys((False,))),280)
        self.assertEqual(len(r.keys((False,True))),560)
        with self.assertRaisesRegex(ValueError,'RAW_TYPES'):r.raw(4.0,False,True)
        f=fixture();f['key']='unrelated'
        with self.assertRaisesRegex(ValueError,'KEY'):r.basic(f,True)

if __name__=='__main__':unittest.main()
