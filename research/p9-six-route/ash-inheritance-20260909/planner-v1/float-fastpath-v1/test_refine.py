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

if __name__ == '__main__':
    unittest.main()
