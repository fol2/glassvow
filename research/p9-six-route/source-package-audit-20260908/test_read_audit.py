"""Mechanical storage-verifier negatives; no simulator runs or outcome changes."""
import json,shutil,tempfile,unittest
from pathlib import Path
from read_audit import R,read

class PacketChecks(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.root=Path(self.temp.name)/'packet'
        shutil.copytree(R,self.root,ignore=shutil.ignore_patterns('__pycache__'))
    def tearDown(self):self.temp.cleanup()
    def rejects(self):
        with self.assertRaises((AssertionError,FileNotFoundError)):read(self.root)
    def test_valid(self):
        self.assertEqual(read(self.root)['checks'],677)
    def test_corrupt_bytes(self):
        p=self.root/'native.parts/000.part';d=bytearray(p.read_bytes());d[100]^=1;p.write_bytes(d)
        self.rejects()
    def test_truncation(self):
        p=self.root/'native.parts/004.part';p.write_bytes(p.read_bytes()[:-1]);self.rejects()
    def test_missing_part(self):
        (self.root/'native.parts/002.part').unlink();self.rejects()
    def test_wrong_content_binding(self):
        p=self.root/'PROTOCOL.json';d=json.loads(p.read_text());d['content_sha256']='0'*64
        p.write_text(json.dumps(d));self.rejects()
    def test_wrong_legacy_binding(self):
        p=self.root/'PROTOCOL.json';d=json.loads(p.read_text());d['source_sha256']['diagnostic_legacy.gd']='0'*64
        p.write_text(json.dumps(d));self.rejects()
    def test_changed_instrument(self):
        p=self.root/'selective_fervor.gd';p.write_text(p.read_text()+'\n# changed\n');self.rejects()

if __name__=='__main__':unittest.main()
