import unittest
from frame_counterexample import check_preview, function

N = '''func preview_play():
\tvar hits: Array[Dictionary] = []
\tvar block: int = 0
\tvar fx_chips: int = 0
\tif hits.is_empty() and block == 0 and fx_chips == 0:
\t\treturn null
'''
H = N + '''\t\t\tif sid == "leech":
\t\t\t\tvar bonus: int = 3 if bloodfire else 0
\t\t\t\thits.append({"dmg": _ji(fx["n"]) + bonus, "times": 1})
\t\t\telif sid == "execute":
\t\t\t\tpass
\treturn {"hits": hits, "total": total}
'''

class FrameTest(unittest.TestCase):
    def test_shape_counterexample(self):
        self.assertIn('false',check_preview(N,H)['conclusion'])
    def test_new_native_branch_blocks_counterexample(self):
        with self.assertRaisesRegex(ValueError,'NATIVE_LEECH'):
            check_preview(N+'if sid == "leech":\n pass',H)
    def test_missing_historical_branch_rejected(self):
        with self.assertRaisesRegex(ValueError,'HISTORICAL_LEECH_BRANCH'):
            check_preview(N,H.replace('sid == "leech"','sid == "other"'))
    def test_changed_historical_hit_rejected(self):
        with self.assertRaisesRegex(ValueError,'WITNESS_CHANGED'):
            check_preview(N,H.replace('hits.append(', 'other.append('))
    def test_changed_zero_initialisation_rejected(self):
        with self.assertRaisesRegex(ValueError,'ACCUMULATORS'):
            check_preview(N.replace('fx_chips: int = 0','fx_chips: int = 1'),H)
    def test_changed_guard_rejected(self):
        with self.assertRaisesRegex(ValueError,'GUARD_CHANGED'):
            check_preview(N.replace('return null','return {}'),H)
    def test_missing_return_rejected(self):
        with self.assertRaisesRegex(ValueError,'RETURN_CHANGED'):
            check_preview(N,H.replace('"hits": hits','"other": hits'))
    def test_function_boundaries(self):
        self.assertEqual(function('func a():\n pass\nfunc b():\n pass\n','a'),'func a():\n pass\n')
    def test_duplicate_function_rejected(self):
        with self.assertRaisesRegex(ValueError,'FUNCTION_BINDING'):
            function('func a():\n pass\nfunc a():\n pass\n','a')

if __name__=='__main__':unittest.main()
