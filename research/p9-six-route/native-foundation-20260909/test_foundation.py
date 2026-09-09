"""No game outcomes are created by these source/contract tests."""
from copy import deepcopy
import unittest
import foundation as f

class FoundationTests(unittest.TestCase):
    def old(self):
        return {'seed0':60909000,'content_sha256':{'candidate':'old','baseline':'baseline'},
                'gates':{'movement':.1,'ceiling':.5}, 'tool_sha256':{'pilot':'frozen'}}
    def contract(self):
        return {'seed0':62090000,'seeds_per_grid':128,'candidate_sha256':f.RESTORED}
    def test_old_protocol_unchanged(self):
        old=self.old();before=deepcopy(old);f.specification(old,self.contract());self.assertEqual(old,before)
    def test_only_seed_and_exact_content_binding_change(self):
        old=self.old();new=f.specification(old,self.contract())
        new['seed0']=old['seed0'];new['content_sha256']['candidate']='old';self.assertEqual(new,old)
    def test_no_old_seed_reuse(self):
        c=self.contract();c['seed0']=60909000
        with self.assertRaises(ValueError):f.specification(self.old(),c)
    def test_no_post_peek_extension(self):
        c=self.contract();c['seeds_per_grid']=256
        with self.assertRaises(ValueError):f.specification(self.old(),c)
    def test_no_second_candidate(self):
        c=self.contract();c['candidate_sha256']='another'
        with self.assertRaises(ValueError):f.specification(self.old(),c)
    def test_guardrails_not_loosened(self):
        old=self.old();new=f.specification(old,self.contract());self.assertEqual(new['gates'],old['gates'])

if __name__=='__main__':unittest.main()
