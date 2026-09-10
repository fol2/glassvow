"""Narrow tests for the new transport and fresh-seed binding, not new science."""
import io
import json
from pathlib import Path
import tarfile
import tempfile
import unittest
from unittest.mock import patch
import control as c


class Tests(unittest.TestCase):
    def metadata(self, value, seed=73760100):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);p=root/'research/p9-six-route/old.config.json';p.parent.mkdir(parents=True)
            p.write_text(json.dumps(value))
            with patch.object(c,'git',return_value='research/p9-six-route/old.config.json'):
                return c.seed_check(root,seed,128)

    def test_fresh_metadata_pass(self):
        self.assertEqual(self.metadata({'seed0':123,'runs':128})['collisions'],[])

    def test_collision_inside_old_range(self):
        with self.assertRaisesRegex(ValueError,'PREVIOUS_SEED_METADATA'):
            self.metadata({'seed0':73760090,'runs':30})

    def test_nested_array_collision(self):
        with self.assertRaisesRegex(ValueError,'PREVIOUS_SEED_METADATA'):
            self.metadata({'nested':{'seeds':[73760101]}})

    def test_range_end_is_exclusive(self):
        self.assertEqual(self.metadata({'seed0':73760000,'runs':100})['collisions'],[])

    def test_protected_evidence_never_opened(self):
        with self.assertRaisesRegex(ValueError,'PROTECTED_SEEDS'):
            self.metadata({},seed=5000)

    def test_missing_metadata_checkout_fails(self):
        with tempfile.TemporaryDirectory() as d,patch.object(c,'git',return_value='absent.config.json'):
            with self.assertRaisesRegex(ValueError,'METADATA_CHECKOUT'):c.seed_check(Path(d),73760100,128)

    def test_archive_bytes_and_roles(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'source.tar';b=b'exact-source'
            with tarfile.open(p,'w') as tf:
                m=tarfile.TarInfo('legacy-query/domain/rules/combat.gd');m.size=len(b);tf.addfile(m,io.BytesIO(b))
            manifest={'legacy-query':{'domain/rules/combat.gd':{'bytes':len(b),'sha256':c.sha(b)}}}
            with tarfile.open(p) as tf:
                self.assertEqual(c.copy_archive_file(tf,'legacy-query','domain/rules/combat.gd',manifest),b)
                manifest['legacy-query']['domain/rules/combat.gd']['sha256']='wrong'
                with self.assertRaisesRegex(ValueError,'ARCHIVE_BYTES'):
                    c.copy_archive_file(tf,'legacy-query','domain/rules/combat.gd',manifest)

    def test_archive_traversal_rejected_before_read(self):
        for p in ('../outside','/etc/passwd'):
            with self.assertRaisesRegex(ValueError,'ARCHIVE_PATH'):c.copy_archive_file(None,'legacy-query',p,{})

if __name__=='__main__':unittest.main()
