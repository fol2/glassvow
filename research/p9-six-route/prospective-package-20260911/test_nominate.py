import copy
import unittest
import nominate as N


def rows():
    return [dict(index=i,seed=s,row_key=f'5:{i}:{s}',outcome='win' if i < 4 else 'loss',
                 hand=i%2==0,bloodfire=i%2==1) for i in range(128) for s in N.SEEDS]


class NominationTests(unittest.TestCase):
    def test_deterministic_ranking(self):
        selected, all_rows=N.rank_rows(rows(),'hand')
        self.assertEqual([r['index'] for r in selected],[0,2]);self.assertEqual(len(all_rows),128)
    def test_bloodfire_distinct_selection(self):
        self.assertEqual([r['index'] for r in N.rank_rows(rows(),'bloodfire')[0]],[1,3])
    def test_row_order_not_selection(self):
        self.assertEqual(N.rank_rows(rows(),'hand'),N.rank_rows(list(reversed(rows())),'hand'))
    def test_missing_fails(self):
        with self.assertRaisesRegex(ValueError,'COMPLETE'):N.rank_rows(rows()[:-1],'hand')
    def test_duplicate_fails(self):
        r=rows();r[-1]=r[0]
        with self.assertRaisesRegex(ValueError,'DUPLICATE'):N.rank_rows(r,'hand')
    def test_unknown_seed_fails(self):
        r=rows();r[0]['seed']=3000
        with self.assertRaisesRegex(ValueError,'ASSIGNMENT'):N.rank_rows(r,'hand')
    def test_bool_index_fails(self):
        r=rows();r[0]['index']=False
        with self.assertRaisesRegex(ValueError,'INTEGER'):N.rank_rows(r,'hand')
    def test_float_seed_fails(self):
        r=rows();r[0]['seed']=float(N.SEEDS[0])
        with self.assertRaisesRegex(ValueError,'INTEGER'):N.rank_rows(r,'hand')
    def test_integer_flag_fails(self):
        r=rows();r[0]['hand']=1
        with self.assertRaisesRegex(ValueError,'TYPED'):N.rank_rows(r,'hand')
    def test_no_imputation_of_errors(self):
        r=rows();r[0]['outcome']='error'
        with self.assertRaisesRegex(ValueError,'OUTCOME'):N.rank_rows(r,'hand')
    def test_no_replacement_after_empty_selection(self):
        r=rows()
        for x in r:x['hand']=False
        with self.assertRaisesRegex(ValueError,'INSUFFICIENT'):N.rank_rows(r,'hand')
    def test_joint_success_precedes_win_only(self):
        r=rows()
        for x in r:
            x['hand']=x['index'] in (0,2,4)
            x['outcome']='win' if x['index'] in (2,4) else 'loss'
        self.assertEqual([x['index'] for x in N.rank_rows(r,'hand')[0]],[2,4])
    def test_input_is_not_mutated(self):
        r=rows();old=copy.deepcopy(r);N.rank_rows(r,'hand');self.assertEqual(r,old)
    def test_unknown_package_fails(self):
        with self.assertRaisesRegex(ValueError,'PACKAGE'):N.rank_rows(rows(),'renamed-hand')

if __name__=='__main__':unittest.main(verbosity=2)
