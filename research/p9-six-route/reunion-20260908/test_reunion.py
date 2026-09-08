import unittest
import audit_reunion as a

class ReunionTests(unittest.TestCase):
    def test_current(self):
        self.assertEqual(a.classify_blob('x','x',set()),'EXACT_CURRENT')
    def test_older_reachable_is_not_lost(self):
        self.assertEqual(a.classify_blob('x','y',{'x'}),'PRESERVED_IN_REACHABLE_HISTORY')
    def test_divergent_source_must_be_preserved(self):
        self.assertEqual(a.classify_blob('x','y',set()),'PRESERVE_DIVERGENT_BYTES')
    def test_unknown_missing_path_is_not_safe(self):
        self.assertEqual(a.classify_blob('x',None,set()),'PRESERVE_DIVERGENT_BYTES')
    def test_path_escape_rejected(self):
        for path in ['/tmp/x','../x','research/p9-six-route/../../x','domain/rules/combat.gd']:
            with self.assertRaises(ValueError): a.safe_path(path)
    def test_owned_paths(self):
        self.assertTrue(str(a.safe_path('research/p9-six-route/SESSION-HANDOFF.md')).endswith('.md'))
        a.safe_path('.github/workflows/p9-research-runtime-bundle.yml')
    def test_byte_identity(self):
        self.assertEqual(a.identity(b'')['git_blob'],'e69de29bb2d1d6434b8b29ae775ad8c2e48c5391')
        self.assertNotEqual(a.identity(b'x')['git_blob'],a.identity(b'x\n')['git_blob'])

if __name__ == '__main__': unittest.main()
