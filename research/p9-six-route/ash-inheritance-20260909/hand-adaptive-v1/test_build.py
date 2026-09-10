import unittest
import build

class Tests(unittest.TestCase):
    def test_ambiguous_site(self):
        with self.assertRaisesRegex(ValueError,'ANCHOR'): build.once('xx','x','a')
    def test_missing_site(self):
        with self.assertRaisesRegex(ValueError,'ANCHOR'): build.once('y','x','a')
    def test_wrong_input(self):
        with self.assertRaisesRegex(ValueError,'INPUT_IDENTITIES'): build.patch(b'x',b'y',b'z')
    def test_no_uid_specific_suppression(self):
        self.assertNotIn('inst.uid',build.BODY);self.assertIn('inst.id',build.BODY)
    def test_native_hooks_retained(self):
        for kind in ('energy','exhaust','loseHp'):
            self.assertNotIn('== "'+kind+'"',build.BODY)
        self.assertIn('original.duplicate(true)',build.BODY)
        self.assertIn('effect["n"] = 0',build.BODY)
    def test_distinct_draw_sources(self):
        self.assertEqual(len(set(build.FLAGS)),3)
        self.assertIn('id == "preparation"',build.BODY);self.assertIn('id == "surge"',build.BODY)
    def test_duplicate_function(self):
        with self.assertRaisesRegex(ValueError,'DUPLICATE_FUNCTION'):build.functions('func x():\n pass\nfunc x():\n pass')

if __name__=='__main__':unittest.main(verbosity=2)
