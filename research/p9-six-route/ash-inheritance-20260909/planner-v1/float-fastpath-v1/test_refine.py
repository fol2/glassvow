import unittest
import refine

class RefinementTests(unittest.TestCase):
    def test_wrong_source_rejected(self):
        with self.assertRaisesRegex(ValueError, 'REFERENCE_SOURCE'):
            refine.transform(b'not the bound source')

    def test_exact_integrality_and_range(self):
        self.assertIn('typeof(v)==TYPE_FLOAT', refine.FLOAT_BRANCH)
        self.assertIn('value>=-1024.0 and value<=1024.0', refine.FLOAT_BRANCH)
        self.assertIn('value==float(whole)', refine.FLOAT_BRANCH)
        self.assertNotIn('epsilon', refine.FLOAT_BRANCH)

    def test_shim_requires_original_fallback(self):
        with self.assertRaisesRegex(ValueError, 'SHIM_FALLBACK'):
            refine.shim(b'func ji(v: Variant) -> int:\n return int(v)\n')


class BenchmarkDecisionTests(unittest.TestCase):
    def data(self, ratio=0.89):
        import experiment
        return {r:{s:{'reference':{'cpu_seconds':100.0},'refined':{'cpu_seconds':100.0*ratio}}
                   for s in experiment.CELLS} for r in ('0','1')}

    def test_two_complete_repetitions_pass(self):
        import experiment
        self.assertTrue(experiment.timing_decision(self.data())['pass'])

    def test_insufficient_gain_is_negative_not_error(self):
        import experiment
        self.assertFalse(experiment.timing_decision(self.data(0.91))['pass'])

    def test_one_slow_cell_cannot_hide_in_aggregate(self):
        import experiment
        rows=self.data(0.80)
        rows['0']['v5-000']['refined']['cpu_seconds']=106.0
        self.assertFalse(experiment.timing_decision(rows)['pass'])

    def test_missing_repetition_rejected(self):
        import experiment
        rows=self.data();del rows['1']
        with self.assertRaisesRegex(ValueError,'REPETITION_COVERAGE'):
            experiment.timing_decision(rows)

    def test_missing_cell_rejected(self):
        import experiment
        rows=self.data();del rows['0']['v5-032']
        with self.assertRaisesRegex(ValueError,'CELL_COVERAGE'):
            experiment.timing_decision(rows)

    def test_invalid_cost_rejected(self):
        import experiment
        for value in (float('nan'),float('inf'),0.0,-1.0):
            rows=self.data();rows['0']['v5-000']['refined']['cpu_seconds']=value
            with self.assertRaisesRegex(ValueError,'FINITE_POSITIVE_COST'):
                experiment.timing_decision(rows)

if __name__ == '__main__':
    unittest.main()
