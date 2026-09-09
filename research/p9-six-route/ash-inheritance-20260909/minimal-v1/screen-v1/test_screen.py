import copy
from pathlib import Path
import tempfile
import unittest
import screen

class ScreenTests(unittest.TestCase):
    def test_cohort_is_preselected_not_new_search(self):
        p = {'next_screen_if_pass': {'seed0': 73309200, 'seeds_per_grid': 128}}
        screen.prerequisite({'status': 'BLOODFIRE_MINIMAL_PREFLIGHT_PASS'},
                            {'all_archive_bytes_verified': True, 'readout_reproduced': True}, p)
        p['next_screen_if_pass']['seed0'] += 1
        with self.assertRaisesRegex(ValueError, 'COHORT'):
            screen.prerequisite({'status': 'BLOODFIRE_MINIMAL_PREFLIGHT_PASS'},
                                {'all_archive_bytes_verified': True, 'readout_reproduced': True}, p)
    def test_failed_preflight_cannot_enter(self):
        with self.assertRaisesRegex(ValueError, 'PREFLIGHT_NOT_PASS'):
            screen.prerequisite({'status': 'FAIL'}, {}, {})
    def test_unverified_preflight_cannot_enter(self):
        with self.assertRaisesRegex(ValueError, 'READBACK'):
            screen.prerequisite({'status': 'BLOODFIRE_MINIMAL_PREFLIGHT_PASS'},
                                {'all_archive_bytes_verified': False, 'readout_reproduced': True}, {})
    def test_old_failed_candidate_inputs_not_reused(self):
        old = {'containment': {}, 'content_sha256': {'candidate': 'old-failure'}}
        frozen = copy.deepcopy(old)
        assembly = {c: {'content/full-content.json': {'sha256': c+'-content'},
                        'domain/rules/combat.gd': {'sha256': c+'-combat'}} for c in ('baseline','candidate')}
        c = {'seed0':73309200, 'seeds_per_grid':128, 'engine_sha256':'engine'}
        new = screen.build_protocol(old,c,assembly)
        self.assertEqual(old, frozen)
        self.assertEqual(new['content_sha256']['candidate'],'candidate-content')
        self.assertEqual(new['arm'],2)
        self.assertEqual(new['seed0'],73309200)
    def test_extra_runtime_file_rejected(self):
        with self.assertRaisesRegex(ValueError,'ASSEMBLED_SOURCE'):
            screen.check_old_assembly({'new':{}},{})
    def test_changed_card_bytes_rejected(self):
        with self.assertRaisesRegex(ValueError,'ASSEMBLED_SOURCE'):
            screen.check_old_assembly({'content':{'sha256':'x'}},{'content':{'sha256':'y'}})
    def test_same_runtime_allowed(self):
        screen.check_old_assembly({'same':{'sha256':'x'}},{'same':{'sha256':'x'}})
    def test_source_identity_is_git_object(self):
        self.assertEqual(screen.blob(b''),'e69de29bb2d1d6434b8b29ae775ad8c2e48c5391')
    def test_cold_mutation_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            r=Path(tmp); a=r/'a';b=r/'b';a.mkdir();b.mkdir()
            (a/'x').write_bytes(b'one');(b/'x').write_bytes(b'two')
            screen.save(a/'FILES.json',[{'path':'x','bytes':3,'sha256':screen.sha(b'one')}])
            (b/'FILES.json').write_bytes((a/'FILES.json').read_bytes())
            with self.assertRaisesRegex(ValueError,'REMOTE_BYTE'):
                screen.cold_verify(r,a,b,r/'receipt.json')

if __name__=='__main__': unittest.main()
